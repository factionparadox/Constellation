#!/usr/bin/env bash
# Report what needs attention in Constellation's pinned packages (run daily by GitHub Actions,
# or by hand). Exit status 1 means the birthDate-free systemd is behind Arch's systemd:
# Arch's security fixes are not reaching Constellation until it is reviewed and rebuilt.
set -Eeuo pipefail
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
LOCK=$HERE/../pkgs/aur.lock
AUR=${CONSTELLATION_AUR_URL:-https://aur.archlinux.org}
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
status=0

srcinfo_ver() {   # srcinfo_ver DIR: pkgver-pkgrel (with epoch) from .SRCINFO
  awk -F' = ' '$1 ~ /^\tepoch$/ {e=$2":"} $1 ~ /^\tpkgver$/ {v=$2} $1 ~ /^\tpkgrel$/ {r=$2} END {print e v "-" r}' "$1/.SRCINFO"
}
upstream() {      # pkgver without pkgrel or epoch, for comparing with Arch
  local v=${1#*:}; echo "${v%-*}"
}

while read -r name pin; do
  case "$name" in ''|'#'*) continue ;; esac
  git clone -q "$AUR/$name.git" "$TMP/$name" 2>/dev/null || { echo "?? $name: cannot reach the AUR"; continue; }
  head=$(git -C "$TMP/$name" rev-parse HEAD)
  if [ "$pin" = UNPINNED ]; then echo "!! $name: not pinned yet (build/aur-pin.sh $name)"
  elif [ "$pin" != "$head" ]; then
    git -C "$TMP/$name" cat-file -e "$pin^{commit}" 2>/dev/null &&
      echo "-- $name: $(git -C "$TMP/$name" rev-list --count "$pin..$head") new AUR commits to review (build/aur-pin.sh $name)" ||
      echo "!! $name: the pinned commit is no longer in the AUR repository"
  else echo "ok $name"; fi
done < "$LOCK"

# The one that matters for security: is the birthDate-free systemd as new as Arch's systemd?
sd=$TMP/systemd-remove-birthdate
if [ -d "$sd" ] && command -v pacman >/dev/null; then
  pin=$(awk '$1 == "systemd-remove-birthdate" {print $2}' "$LOCK")
  [ "$pin" = UNPINNED ] || git -C "$sd" checkout -q "$pin"
  ours=$(upstream "$(srcinfo_ver "$sd")")
  arch=$(upstream "$(pacman -Si systemd | awk -F': ' '/^Version/ {print $2; exit}')")
  if [ "$(vercmp "$ours" "$arch")" -lt 0 ]; then
    echo "!! systemd: Arch has $arch, Constellation's birthDate-free systemd is $ours."
    echo "   Review and rebuild: build/aur-pin.sh systemd-remove-birthdate && build/build-repo.sh --only systemd-remove-birthdate"
    status=1
  else
    echo "ok systemd: $ours (Arch: $arch)"
  fi
fi
exit "$status"
