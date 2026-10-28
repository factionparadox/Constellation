#!/usr/bin/env bash
# Collect every package an installed Constellation needs (the whole dependency closure of
# packages.txt plus the birthDate-free systemd) into one repository for the ISO, so the
# installer needs no network. Called by build/build-iso.sh (as root).
#
#   build/build-offline-repo.sh PKGREPO OUTDIR SIGLEVEL
#
# Arch's packages come from your mirrors with their signatures and are checked against
# Arch's keyring here; Constellation's are copied from PKGREPO and checked against
# keys/constellation.asc. The installer checks every signature again when it installs.
set -Eeuo pipefail
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO=$(cd -- "$HERE/.." && pwd)
PKGREPO=${1:?package repository}; OFF=${2:?output directory}; SIGLEVEL=${3:?SigLevel}
LIST=${CONSTELLATION_PACKAGES:-$REPO/pkgs/constellation-installer/packages.txt}
die() { printf '\nbuild-offline-repo: %s\n' "$*" >&2; exit 1; }
say() { printf '\n==> %s\n' "$*"; }

WORK=$(mktemp -d); trap 'rm -rf "$WORK"' EXIT
mkdir -p "$OFF" "$WORK/db"
cat > "$WORK/pacman.conf" <<EOF
[options]
Architecture = auto
SigLevel = Required DatabaseOptional
ParallelDownloads = 5

[constellation]
SigLevel = $SIGLEVEL
Server = file://$PKGREPO

[core]
Include = /etc/pacman.d/mirrorlist

[extra]
Include = /etc/pacman.d/mirrorlist
EOF
pm() { pacman --config "$WORK/pacman.conf" --dbpath "$WORK/db" --logfile "$WORK/pacman.log" --noconfirm "$@"; }

say 'Reading the package databases'
pm -Sy >/dev/null
mapfile -t want < <(grep -v -E '^\s*(#|$)' "$LIST"; grep -v -E '^\s*(#|$)' "$PKGREPO/systemd-packages.txt")
# -Sp against an empty database resolves the full closure, exactly what pacstrap will install.
mapfile -t urls < <(pm -Sp --print-format '%l' "${want[@]}") || die 'could not resolve the package list'
[ ${#urls[@]} -gt 50 ] || die "only ${#urls[@]} packages resolved; something is wrong"

say "Collecting ${#urls[@]} packages"
keep=()
for url in "${urls[@]}"; do
  f=${url##*/}; keep+=("$f")
  if [ -f "$OFF/$f" ] && { [ "$SIGLEVEL" = 'Optional TrustAll' ] || [ -f "$OFF/$f.sig" ]; }; then continue; fi
  case "$url" in
    file://*) cp "${url#file://}" "$OFF/$f"; [ ! -f "${url#file://}.sig" ] || cp "${url#file://}.sig" "$OFF/$f.sig" ;;
    *) curl -fsSL --retry 5 --retry-all-errors -o "$OFF/$f.part" "$url" && mv "$OFF/$f.part" "$OFF/$f"
       curl -fsSL --retry 5 --retry-all-errors -o "$OFF/$f.sig" "$url.sig" || die "no signature for $f" ;;
  esac
done
# Drop packages from earlier builds that are no longer part of the closure.
for f in "$OFF"/*.pkg.tar.zst; do
  printf '%s\n' "${keep[@]}" | grep -qxF "${f##*/}" || rm -f "$f" "$f.sig"
done

# A throwaway copy of Arch's keyring, made the way pacman-key makes one: import the packager
# keys, then a local key certifies Arch's master keys, so keys the masters signed are valid.
arch_keyring() {   # arch_keyring GNUPGHOME KEYRINGS-DIR
  local home=$1 dir=$2 fpr
  install -d -m 700 "$home"
  gpg --homedir "$home" --batch -q --pinentry-mode loopback --passphrase '' \
    --quick-generate-key 'Constellation build check' ed25519 cert never 2>/dev/null
  gpg --homedir "$home" --batch -K 2>/dev/null | grep -q '^sec' ||
    die "could not create a local key in $home (gpg-agent did not start?)"
  gpg --homedir "$home" --batch -q --import "$dir/archlinux.gpg" 2>/dev/null
  while IFS=: read -r fpr _; do
    [ -n "$fpr" ] && gpg --homedir "$home" --batch -q --yes --pinentry-mode loopback --passphrase '' \
      --quick-lsign-key "$fpr" 2>/dev/null
  done < "$dir/archlinux-trusted"
  # The master keys' owner trust, so the packager keys they certify are valid (as pacman-key does).
  gpg --homedir "$home" --batch -q --import-ownertrust < "$dir/archlinux-trusted" 2>/dev/null
  gpg --homedir "$home" --batch -q --check-trustdb 2>/dev/null || true
}

good_signature() {   # good_signature GNUPGHOME FILE: a valid signature from a fully trusted key
  local status
  status=$(gpg --homedir "$1" --batch --status-fd 1 --verify "$2.sig" "$2" 2>"$WORK/gpg-error") || return 1
  grep -q '^\[GNUPG:\] VALIDSIG ' <<< "$status" && grep -qE '^\[GNUPG:\] TRUST_(FULLY|ULTIMATE)' <<< "$status"
}

if [ "$SIGLEVEL" != 'Optional TrustAll' ]; then
  say 'Checking every signature'
  install -d -m 700 "$WORK/gpg"
  gpg --homedir "$WORK/gpg" --batch -q --import "$REPO/keys/constellation.asc"
  own=$(cd "$PKGREPO" && ls *.pkg.tar.zst)

  # Arch's packages are checked against the archlinux-keyring package in this same download
  # (it may be newer than this machine's), which is itself checked against this machine's keyring.
  kr=$(printf '%s\n' "${keep[@]}" | grep -m1 '^archlinux-keyring-') || die 'archlinux-keyring is not in the package list'
  arch_keyring "$WORK/host-keyring" /usr/share/pacman/keyrings
  good_signature "$WORK/host-keyring" "$OFF/$kr" ||
    die "$kr does not verify against this machine's Arch keyring: $(cat "$WORK/gpg-error")
Update this machine first (sudo pacman -Syu) and run the build again."
  mkdir -p "$WORK/keyrings"
  bsdtar -xf "$OFF/$kr" -C "$WORK/keyrings" usr/share/pacman/keyrings
  arch_keyring "$WORK/arch-keyring" "$WORK/keyrings/usr/share/pacman/keyrings"

  for f in "${keep[@]}"; do
    if grep -qxF "$f" <<< "$own"; then
      gpg --homedir "$WORK/gpg" --batch -q --verify "$OFF/$f.sig" "$OFF/$f" 2>"$WORK/gpg-error" ||
        die "bad Constellation signature on $f: $(cat "$WORK/gpg-error")"
    elif ! good_signature "$WORK/arch-keyring" "$OFF/$f"; then
      # A damaged download is the usual cause: fetch it once more before giving up.
      rm -f "$OFF/$f" "$OFF/$f.sig"
      echo "    $f did not verify; downloading it again"
      url=$(printf '%s\n' "${urls[@]}" | grep -m1 -F "/$f") || die "no download address for $f"
      curl -fsSL --retry 5 --retry-all-errors -o "$OFF/$f" "$url" && curl -fsSL --retry 5 -o "$OFF/$f.sig" "$url.sig" ||
        die "could not download $f again"
      good_signature "$WORK/arch-keyring" "$OFF/$f" || die "bad Arch signature on $f: $(cat "$WORK/gpg-error")"
    fi
  done
fi

say 'Writing the offline repository database'
rm -f "$OFF"/constellation-offline.{db,files}*
(cd "$OFF" && repo-add -q constellation-offline.db.tar.gz "${keep[@]}")
cp "$PKGREPO/systemd-packages.txt" "$OFF/"
say "Offline repository: ${#keep[@]} packages, $(du -sh "$OFF" | cut -f1)"
