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

if [ "$SIGLEVEL" != 'Optional TrustAll' ]; then
  say 'Checking every signature'
  gpg --homedir "$WORK/gpg" --batch -q --import "$REPO/keys/constellation.asc" 2>/dev/null || { mkdir -m 700 "$WORK/gpg"; gpg --homedir "$WORK/gpg" --batch -q --import "$REPO/keys/constellation.asc"; }
  own=$(cd "$PKGREPO" && ls *.pkg.tar.zst)
  for f in "${keep[@]}"; do
    if grep -qxF "$f" <<< "$own"; then
      gpg --homedir "$WORK/gpg" --batch -q --verify "$OFF/$f.sig" "$OFF/$f" 2>/dev/null || die "bad Constellation signature: $f"
    else
      pacman-key --verify "$OFF/$f.sig" "$OFF/$f" >/dev/null 2>&1 || die "bad Arch signature: $f"
    fi
  done
fi

say 'Writing the offline repository database'
rm -f "$OFF"/constellation-offline.{db,files}*
(cd "$OFF" && repo-add -q constellation-offline.db.tar.gz "${keep[@]}")
cp "$PKGREPO/systemd-packages.txt" "$OFF/"
say "Offline repository: ${#keep[@]} packages, $(du -sh "$OFF" | cut -f1)"
