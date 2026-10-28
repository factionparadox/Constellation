#!/usr/bin/env bash
# Build Constellation's package repository: the reviewed AUR packages (pkgs/aur.lock) and
# Constellation's own packages (pkgs/*). Anything that compiles is built in a clean chroot
# (devtools), so this machine's own system, including its systemd, is never touched.
#
#   build/build-repo.sh [--out DIR] [--only NAME...] [--unsigned]
#
# Packages and the repository database are signed with $CONSTELLATION_GPGKEY (see
# docs/BUILDING.md). --unsigned is for local testing only: pacman will be told to accept
# the packages unchecked. Already-built package versions are skipped, so re-runs are quick.
set -Eeuo pipefail
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO=$(cd -- "$HERE/.." && pwd)
OUT=$REPO/out/repo WORK=${CONSTELLATION_WORK:-$REPO/work} UNSIGNED=0 ONLY=()
AUR=${CONSTELLATION_AUR_URL:-https://aur.archlinux.org}
GPGKEY=${CONSTELLATION_GPGKEY:-}
DB=constellation
# Built before the AUR packages, because some of those depend on them.
FIRST=(python-materialyoucolor)
# Constellation's own packages, in build order. Data-only ones need no chroot.
OWN=(ani-cli zfsbootmenu-efi constellation-base ttf-material-symbols-rounded niri-caelestia-shell constellation-desktop constellation-russian constellation-installer)
COMPILED=(python-materialyoucolor niri-caelestia-shell)

while [ $# -gt 0 ]; do
  case "$1" in
    --out) OUT=$(realpath -m "$2"); shift 2 ;;
    --only) shift; while [ $# -gt 0 ] && [ "${1#--}" = "$1" ]; do ONLY+=("$1"); shift; done ;;
    --unsigned) UNSIGNED=1; shift ;;
    -h|--help) sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

die() { printf '\nbuild-repo: %s\n' "$*" >&2; exit 1; }
say() { printf '\n==> %s\n' "$*"; }
for t in makepkg repo-add git; do command -v "$t" >/dev/null || die "missing $t: sudo pacman -S base-devel git"; done
for t in mkarchroot makechrootpkg; do command -v "$t" >/dev/null || die "missing $t: sudo pacman -S devtools"; done
[ "$(id -u)" -ne 0 ] || die 'run as yourself, not root (makepkg refuses root); it asks for sudo when it needs it'
if [ "$UNSIGNED" -eq 0 ]; then
  [ -n "$GPGKEY" ] || die 'set CONSTELLATION_GPGKEY to your signing key (docs/BUILDING.md), or use --unsigned for a local test'
  gpg --list-secret-keys "$GPGKEY" >/dev/null 2>&1 || die "no secret key $GPGKEY in your GnuPG keyring"
fi
wanted() { [ ${#ONLY[@]} -eq 0 ] && return 0; local n; for n in "${ONLY[@]}"; do [ "$n" = "$1" ] && return 0; done; return 1; }
compiled() { local n; for n in "${COMPILED[@]}"; do [ "$n" = "$1" ] && return 0; done; return 1; }

mkdir -p "$OUT" "$WORK"
CHROOT=$WORK/chroot
[ -f "$OUT/$DB.db.tar.gz" ] || repo-add -q "$OUT/$DB.db.tar.gz"

chroot_ready() {
  if [ ! -d "$CHROOT/root" ]; then
    say 'Creating the clean build chroot (once)'
    mkdir -p "$CHROOT"
    mkarchroot "$CHROOT/root" base-devel
  fi
  # Packages built earlier in this run are dependencies of later ones: the chroot sees OUT as a
  # repository. arch-nspawn bind-mounts every file:// server at the same path it has on this
  # machine, so the server is OUT's real path. (pacman looks for <section>.db, so the section
  # has the database's name.) Rewritten every run, in case OUT moved.
  sudo sed -i "/^# constellation-build-repo$/,/^# end constellation-build-repo$/d" "$CHROOT/root/etc/pacman.conf"
  sudo sed -i "/^\[$DB\]$/,/^Server = file:\/\/\/constellation-repo$/d" "$CHROOT/root/etc/pacman.conf"
  printf '\n# constellation-build-repo\n[%s]\nSigLevel = Never\nServer = file://%s\n# end constellation-build-repo\n' "$DB" "$OUT" |
    sudo tee -a "$CHROOT/root/etc/pacman.conf" >/dev/null
}

publish() {    # publish DIR: sign the packages makepkg left in DIR, move them to OUT, index them
  local dir=$1 f
  for f in "$dir"/*.pkg.tar.zst; do
    [ -f "$f" ] || continue
    [ "$UNSIGNED" -eq 1 ] || gpg --batch --yes --detach-sign --local-user "$GPGKEY" --output "$f.sig" "$f"
    mv -f "$f" "$OUT/"; [ ! -f "$f.sig" ] || mv -f "$f.sig" "$OUT/"
    if [ "$UNSIGNED" -eq 1 ]; then repo-add -q -R "$OUT/$DB.db.tar.gz" "$OUT/${f##*/}"
    else repo-add -q -R -s -k "$GPGKEY" "$OUT/$DB.db.tar.gz" "$OUT/${f##*/}"; fi
    echo "    $(basename "$f")"
  done
}

already_built() {   # all of this PKGBUILD's packages are in OUT already
  local dir=$1 f
  while read -r f; do [ -f "$OUT/${f##*/}" ] || return 1; done < <(cd "$dir" && makepkg --packagelist)
}

build() {      # build NAME DIR CHROOT(0|1)
  local name=$1 dir=$2 use_chroot=$3
  if already_built "$dir"; then echo "    $name: up to date"; return; fi
  say "Building $name"
  if [ "$use_chroot" -eq 1 ]; then
    chroot_ready
    (cd "$dir" && makechrootpkg -c -u -r "$CHROOT")
  else
    # No compilation: files and dependency lists only, so no chroot is needed.
    (cd "$dir" && makepkg -f --nodeps --noconfirm)
  fi
  publish "$dir"
}

# ------------------------------------------------------------------ dependencies of AUR packages
for name in "${FIRST[@]}"; do
  wanted "$name" || continue
  compiled "$name" && c=1 || c=0
  build "$name" "$REPO/pkgs/$name" "$c"
done

# ------------------------------------------------------------------ AUR packages (reviewed, pinned)
while read -r name commit src; do
  case "$name" in ''|'#'*) continue ;; esac
  wanted "$name" || continue
  [ "$commit" != UNPINNED ] || die "$name is not pinned yet: build/aur-pin.sh $name"
  [ "$src" != src=UNPINNED ] || die "$name builds from a git branch; pin its source commit in pkgs/aur.lock (src=COMMIT)"
  d=$WORK/aur/$name
  if [ ! -d "$d/.git" ]; then mkdir -p "$WORK/aur"; git clone -q "$AUR/$name.git" "$d"; fi
  git -C "$d" cat-file -e "$commit^{commit}" 2>/dev/null || git -C "$d" fetch -q origin
  git -C "$d" checkout -q --force "$commit" || die "$name: pinned commit $commit not found"
  git -C "$d" clean -q -fdx -e '*.pkg.tar.zst'
  # Files the AUR package lacks (its PKGBUILD's checksums still have to match them).
  if [ -d "$REPO/pkgs/aur-overlays/$name" ]; then cp -a "$REPO/pkgs/aur-overlays/$name/." "$d/"; fi
  # A -git package follows a branch; src=COMMIT fixes its first git source to one reviewed commit.
  if [ -n "$src" ]; then
    grep -q '#commit=' "$d/PKGBUILD" || sed -i '0,/git+[^"#)]*/s||&#commit='"${src#src=}"'|' "$d/PKGBUILD"
  fi
  build "$name" "$d" 1
done < "$REPO/pkgs/aur.lock"

# ------------------------------------------------------------------ Constellation's own packages
for name in "${OWN[@]}"; do
  wanted "$name" || continue
  compiled "$name" && c=1 || c=0
  build "$name" "$REPO/pkgs/$name" "$c"
done

# The birthDate-free systemd family the installer and the ISO use in place of Arch's systemd.
sd=$WORK/aur/systemd-remove-birthdate
if [ -d "$sd" ]; then
  (cd "$sd" && makepkg --printsrcinfo) | sed -n 's/^pkgname = //p' |
    grep -v -E -- '-(tests|ukify)$' > "$OUT/systemd-packages.txt"
fi

say "Repository ready: $OUT ($(ls "$OUT"/*.pkg.tar.zst 2>/dev/null | wc -l) packages)"
[ "$UNSIGNED" -eq 0 ] || echo 'UNSIGNED: for local testing only. pacman will install these packages without checking them.'
