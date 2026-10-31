#!/usr/bin/env bash
# Build the Constellation live/installer ISO with mkarchiso.
#
#   sudo build/build-iso.sh [--repo DIR] [--out DIR] [--content "PACKS" | --content none]
#                           [--music DIR | --no-music]
#
# Personal files: if local/music exists (git ignores local/), it goes on the ISO and the
# installer copies it into your Music folder. Such an ISO is named constellation-personal-*
# and is for you only: never share or publish it. --no-music leaves it out.
#
# The ISO installs with no network: every package an installed system needs is on it
# (build/build-offline-repo.sh), and so are the Russian content packs named by --content
# (default: ru-voices ru-course ru-audiobooks, about 5 GB), from the content mirror.
#
# Starts from Arch's own releng profile (so it follows archiso as Arch updates it) and adds:
# the LTS kernel with OpenZFS, the birthDate-free systemd in place of Arch's, Constellation's
# package repository (copied onto the ISO, so installing uses exactly what was built), the
# installer, Constellation's signing key, and the themed GRUB menu.
# Build the repository first: build/build-repo.sh
set -Eeuo pipefail
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO=$(cd -- "$HERE/.." && pwd)
PKGREPO=$REPO/out/repo OUT=$REPO/out WORK=${CONSTELLATION_WORK:-$REPO/work}
CONTENT='ru-voices ru-course ru-audiobooks'
MUSIC=$REPO/local/music
RELENG=${CONSTELLATION_RELENG:-/usr/share/archiso/configs/releng}
REMOTE=${CONSTELLATION_REMOTE:-https://github.com/factionparadox/Constellation/releases/download/repo}

while [ $# -gt 0 ]; do
  case "$1" in
    --repo) PKGREPO=$(realpath -m "$2"); shift 2 ;;
    --out) OUT=$(realpath -m "$2"); shift 2 ;;
    --music) MUSIC=$(realpath -m "$2"); shift 2 ;;
    --no-music) MUSIC=''; shift ;;
    --content) CONTENT=$2; [ "$CONTENT" != none ] || CONTENT=''; shift 2 ;;
    -h|--help) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done
die() { printf '\nbuild-iso: %s\n' "$*" >&2; exit 1; }
say() { printf '\n==> %s\n' "$*"; }

[ "$(id -u)" -eq 0 ] || die 'mkarchiso needs root: sudo build/build-iso.sh'
command -v mkarchiso >/dev/null || die 'install archiso: sudo pacman -S archiso grub'
command -v grub-mkfont >/dev/null || die 'install grub (for the boot menu fonts): sudo pacman -S grub'
[ -d "$RELENG" ] || die "archiso's releng profile is missing: $RELENG"
[ -f "$PKGREPO/constellation.db.tar.gz" ] || die "no package repository in $PKGREPO: run build/build-repo.sh first"
[ -s "$PKGREPO/systemd-packages.txt" ] || die 'the birthDate-free systemd is not in the repository yet (build/build-repo.sh)'

# Signed repository (normal) or a local unsigned test build.
if ls "$PKGREPO"/*.pkg.tar.zst.sig >/dev/null 2>&1; then
  SIGLEVEL='Required DatabaseOptional'
  [ -f "$REPO/keys/constellation.asc" ] || die 'signed packages but no public key: export it to keys/constellation.asc (docs/BUILDING.md)'
  # mkarchiso installs with this machine's pacman, which must trust Constellation's key.
  fpr=$(gpg --with-colons --import-options show-only --import "$REPO/keys/constellation.asc" | awk -F: '$1 == "fpr" {print $10; exit}')
  if ! pacman-key --list-keys "$fpr" >/dev/null 2>&1; then
    say "Adding Constellation's signing key ($fpr) to this machine's pacman keyring"
    pacman-key --add "$REPO/keys/constellation.asc"
    pacman-key --lsign-key "$fpr"
  fi
else
  SIGLEVEL='Optional TrustAll'
  echo 'WARNING: unsigned repository. This ISO is for local testing only.'
fi

PROFILE=$WORK/iso-profile
say "Preparing the profile from $RELENG"
rm -rf "$PROFILE"; cp -a "$RELENG" "$PROFILE"

# --- identity and boot modes (UEFI boots GRUB, so the menu can be themed)
sed -i -E \
  -e 's|^iso_name=.*|iso_name="constellation"|' \
  -e 's|^iso_label=.*|iso_label="CONSTELLATION_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"|' \
  -e 's|^iso_publisher=.*|iso_publisher="Constellation <https://github.com/factionparadox/Constellation>"|' \
  -e 's|^iso_application=.*|iso_application="Constellation live and installer"|' \
  -e 's|^install_dir=.*|install_dir="constellation"|' \
  "$PROFILE/profiledef.sh"
python3 - "$PROFILE/profiledef.sh" <<'PY'
import re, sys
p = sys.argv[1]; s = open(p).read()
s = re.sub(r"bootmodes=\([^)]*\)", "bootmodes=('bios.syslinux' 'uefi.grub')", s, flags=re.S)
s = s.replace('file_permissions=(', 'file_permissions=(\n  ["/usr/local/bin/constellation-welcome"]="0:0:755"', 1)
open(p, 'w').write(s)
PY

# --- Arch's own kernel (linux, 7.x: the Framework 13 Pro needs it), plus OpenZFS and the installer.
# OpenZFS is pinned to a release that supports it (zfs-dkms 2.4.4 supports Linux up to 7.2).
grep -qx 'linux' "$PROFILE/packages.x86_64" || die "releng no longer lists the linux kernel; archiso has changed"
# Arch's own systemd packages (releng lists systemd-resolvconf) would conflict with the
# birthDate-free family, which provides them all.
sed -i -E '/^systemd(-[a-z]+)?$/d' "$PROFILE/packages.x86_64"
{
  echo; echo '# Constellation'
  printf '%s\n' linux-headers zfs-dkms zfs-utils zfsbootmenu-efi constellation-installer arch-install-scripts
  grep -v -E '^\s*(#|$)' "$PKGREPO/systemd-packages.txt"
} >> "$PROFILE/packages.x86_64"

# --- run the live system from the stick, never copied to RAM: the installer reads the packages,
# content and music straight off the stick, which archiso unmounts after copytoram.
grep -rlE 'archisobasedir=' "$PROFILE"/{grub,syslinux,efiboot} 2>/dev/null |
  xargs -r sed -i -E '/archisobasedir=/{/copytoram=/!s/(archisobasedir=[^ ]*)/\1 copytoram=n/}'
grep -rqE 'archisobasedir=[^ ]* copytoram=n' "$PROFILE/grub" || die 'could not add copytoram=n to the boot menu; archiso has changed'

# --- Constellation's repository, before Arch's (it is the only source of the systemd family)
add_repo() {   # add_repo PACMAN.CONF SERVER [SERVER...]  (pacman tries them in order)
  python3 - "$SIGLEVEL" "$@" <<'PY'
import sys
sig, path, *servers = sys.argv[1:]
s = open(path).read()
block = f'[constellation]\nSigLevel = {sig}\n' + ''.join(f'Server = {x}\n' for x in servers) + '\n'
i = s.index('[core]')
open(path, 'w').write(s[:i] + block + s[i:])
PY
}
add_repo "$PROFILE/pacman.conf" "file://$PKGREPO"

AIR=$PROFILE/airootfs
SHARE=$AIR/usr/share/constellation/install
install -d "$SHARE"
# The packages and content packs go on the ISO itself, beside the live system's squashfs
# rather than inside it (added after mkarchiso, below): they are already compressed, and
# the live image stays small enough to boot quickly. The live system sees them under
# /run/archiso/bootmnt.
BOOTMNT=/run/archiso/bootmnt

# --- every package the installed system needs, so installing works with no network
command -v xorriso >/dev/null || die 'install libisoburn (xorriso): sudo pacman -S libisoburn'
"$HERE/build-offline-repo.sh" "$PKGREPO" "$OUT/offline" "$SIGLEVEL"
cp "$PKGREPO/systemd-packages.txt" "$SHARE/"
# pacman-live.conf: how the installer installs (only from the USB stick, never the network);
# pacman.conf: the installed system's (Arch's mirrors and Constellation's repository online).
cat > "$SHARE/pacman-live.conf" <<EOF
[options]
Architecture = auto
SigLevel = Required DatabaseOptional
LocalFileSigLevel = Optional

[constellation-offline]
SigLevel = $SIGLEVEL
Server = file://$BOOTMNT/constellation-offline
EOF
# Constellation's repository online first; if it cannot be reached or is not published yet,
# the copy the installer puts on the disk (/var/lib/constellation/repo), so updating never fails.
cp "$RELENG/pacman.conf" "$SHARE/pacman.conf"
add_repo "$SHARE/pacman.conf" "$REMOTE" "file:///var/lib/constellation/repo"

# --- that copy: Constellation's repository as built (database and current packages only)
say "Copying Constellation's repository for the installed system"
rm -rf "$OUT/localrepo"; install -d "$OUT/localrepo"
cp -L "$PKGREPO/constellation.db.tar.gz" "$OUT/localrepo/constellation.db"
cp -L "$PKGREPO/constellation.files.tar.gz" "$OUT/localrepo/constellation.files"
for f in constellation.db constellation.files; do
  [ ! -f "$PKGREPO/$f.tar.gz.sig" ] || cp -L "$PKGREPO/$f.tar.gz.sig" "$OUT/localrepo/$f.sig"
done
tar -xOzf "$PKGREPO/constellation.db.tar.gz" --wildcards '*/desc' |
  awk '/^%FILENAME%$/ {getline; print}' | while read -r pkg; do
    [ -f "$PKGREPO/$pkg" ] || die "the repository lists $pkg but it is not in $PKGREPO"
    cp "$PKGREPO/$pkg" "$OUT/localrepo/"
    [ ! -f "$PKGREPO/$pkg.sig" ] || cp "$PKGREPO/$pkg.sig" "$OUT/localrepo/"
  done
echo "    $(ls "$OUT/localrepo"/*.pkg.tar.zst | wc -l) packages, $(du -sh "$OUT/localrepo" | cut -f1)"

# --- the Russian content packs, from the content mirror (each part checked by its SHA-256)
for pack in $CONTENT; do
  say "Content pack $pack"
  python3 -I "$REPO/pkgs/constellation-russian/fetch-mirror.py" --mirror "$REPO/pkgs/constellation-russian/mirror.json" \
    --pack "$pack" --dest "$OUT/content/$pack" || die "could not fetch $pack from the content mirror"
done
# The installed system should not keep the live ISO's pacman defaults: use a stock Arch pacman.conf.
sed -i -E 's/^#?(ParallelDownloads).*/\1 = 5/; s/^#(Color)$/\1/' "$SHARE/pacman.conf"

# --- the signing key: trusted by the live system's keyring at boot (pacman-init)
if [ "$SIGLEVEL" != 'Optional TrustAll' ]; then
  install -Dm0644 "$REPO/keys/constellation.asc" "$AIR/usr/share/constellation/constellation.asc"
  fpr=$(gpg --with-colons --import-options show-only --import "$REPO/keys/constellation.asc" | awk -F: '$1 == "fpr" {print $10; exit}')
  install -d "$AIR/etc/systemd/system/pacman-init.service.d"
  # The empty After= drops releng's ordering after time-sync.target: with no network (this ISO
  # installs offline) the clock never syncs, and the keyring would never be set up.
  cat > "$AIR/etc/systemd/system/pacman-init.service.d/constellation.conf" <<EOF
[Unit]
After=
After=etc-pacman.d-gnupg.mount

[Service]
ExecStart=/usr/bin/pacman-key --add /usr/share/constellation/constellation.asc
ExecStart=/usr/bin/pacman-key --lsign-key $fpr
EOF
fi

# --- a welcome on the live console, which offers to start the installer
install -Dm0755 "$REPO/iso/constellation-welcome" "$AIR/usr/local/bin/constellation-welcome"
cp "$REPO/iso/motd" "$AIR/etc/motd"
printf '\n# Constellation: offer the installer on the first console\n[ "$(tty)" = /dev/tty1 ] && /usr/local/bin/constellation-welcome --offer\n' >> "$AIR/root/.zlogin"

# --- the themed GRUB menu
say 'Preparing the boot menu theme'
theme=$PROFILE/grub/themes/constellation
install -d "$theme"
cp "$REPO"/branding/grub/theme.txt "$REPO"/branding/grub/*.png "$theme/"
cp "$REPO/branding/fonts/OFL.txt" "$theme/OFL-Inter.txt"
for spec in Regular:20 Regular:28; do
  weight=${spec%:*} size=${spec#*:}
  grub-mkfont -s "$size" -o "$theme/inter-${weight,,}-$size.pf2" "$REPO/branding/fonts/Inter-$weight.otf"
done
python3 - "$PROFILE/grub/grub.cfg" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
theme = '''
# Constellation theme (falls back to the plain menu if the graphics cannot start)
if [ "${grub_platform}" == 'efi' ] && loadfont "${prefix}/themes/constellation/inter-regular-20.pf2" ; then
    loadfont "${prefix}/themes/constellation/inter-regular-28.pf2"
    insmod gfxmenu
    insmod png
    set gfxmode=auto
    terminal_output gfxterm
    set theme="${prefix}/themes/constellation/theme.txt"
fi
'''
s = s.replace('# Enable serial console', theme + '\n# Enable serial console', 1)
s = s.replace('menuentry "Arch Linux install medium', 'menuentry "Constellation: live system and installer', 1)
s = s.replace('menuentry "Arch Linux install medium with speakup screen reader', 'menuentry "Constellation with the speakup screen reader', 1)
s = s.replace('--class arch --class gnu-linux', '--class constellation --class gnu-linux')
s = s.replace('timeout=15', 'timeout=10')
open(p, 'w').write(s)
PY

say 'Building the ISO (this takes a while)'
mkdir -p "$OUT"
mkarchiso -v -w "$WORK/archiso" -o "$OUT" "$PROFILE"
rm -rf "$WORK/archiso"
iso=$(ls -t "$OUT"/constellation-*.iso | sed -n 1p)   # sed reads to the end (head would break pipefail)

say 'Adding the packages and content packs to the ISO'
maps=(-map "$OUT/offline" /constellation-offline -map "$OUT/localrepo" /constellation-repo)
for pack in $CONTENT; do maps+=(-map "$OUT/content/$pack" "/constellation-content/$pack"); done
if [ -n "$MUSIC" ] && [ -d "$MUSIC" ] && [ -n "$(ls -A "$MUSIC")" ]; then
  say "Adding your music from $MUSIC ($(du -sh "$MUSIC" | cut -f1)): a PERSONAL ISO, not for sharing"
  maps+=(-map "$MUSIC" /constellation-music)
  personal=$OUT/$(basename "$iso" | sed 's/^constellation-/constellation-personal-/')
else
  personal=''
fi
# replay keeps archiso's boot setup (BIOS, UEFI and the hybrid USB layout) exactly as it was.
xorriso -indev "$iso" -outdev "$iso.new" -boot_image any replay "${maps[@]}"
mv -f "$iso.new" "$iso"
if [ -n "$personal" ]; then mv -f "$iso" "$personal"; iso=$personal; fi
(cd "$OUT" && sha256sum "$(basename "$iso")" > "$(basename "$iso").sha256")
[ -z "${SUDO_UID:-}" ] || chown "$SUDO_UID:${SUDO_GID:-$SUDO_UID}" "$iso" "$iso.sha256"
say "Built $iso ($(du -h "$iso" | cut -f1))"
# Installed systems update from the online repository when it is published, and from the copy
# on their own disk until then: say which it will be.
if curl -fsIL --max-time 20 "$REMOTE/constellation.db" >/dev/null 2>&1; then
  echo "Online repository: published ($REMOTE)."
else
  echo "Online repository: NOT published yet. Installed systems update from the copy on their disk"
  echo "until you run build/publish-repo.sh."
fi
