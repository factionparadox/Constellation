#!/usr/bin/env bash
# Review and pin AUR packages for Constellation's repository (pkgs/aur.lock).
#
#   build/aur-pin.sh                 check every package: pinned, behind, or unpinned
#   build/aur-pin.sh NAME [NAME...]  review each one's PKGBUILD (new) or diff (update) and pin it
#   build/aur-pin.sh --deps NAME     list NAME's dependencies that are not in Arch's repositories
#
# Nothing is pinned without you reading it and answering yes: an AUR package is someone
# else's shell script that Constellation will run as root.
set -Eeuo pipefail
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
REPO=$(cd -- "$HERE/.." && pwd)
LOCK=$REPO/pkgs/aur.lock
CACHE=${CONSTELLATION_AUR_CACHE:-$REPO/work/aur}
AUR=${CONSTELLATION_AUR_URL:-https://aur.archlinux.org}
die() { printf 'aur-pin: %s\n' "$*" >&2; exit 1; }

pinned() { awk -v n="$1" '$1 == n {print $2}' "$LOCK"; }
names() { grep -v -E '^\s*(#|$)' "$LOCK" | awk '{print $1}'; }

fetch() {      # fetch NAME: an up-to-date clone of NAME's AUR git repository
  local d="$CACHE/$1"
  if [ -d "$d/.git" ]; then git -C "$d" fetch -q origin && git -C "$d" reset -q --hard origin/HEAD
  else mkdir -p "$CACHE"; git clone -q "$AUR/$1.git" "$d"; fi
  [ -s "$d/PKGBUILD" ] || die "$1 is not an AUR package (no PKGBUILD)"
  echo "$d"
}

not_in_repos() {   # dependencies of a package that pacman's repositories do not provide
  local d=$1 dep
  sed -n -E 's/^\s*(depends|makedepends|checkdepends)( = |=)//p' "$d/.SRCINFO" | sed -E 's/[<>=].*//' | sort -u |
    while read -r dep; do pacman -Si "$dep" >/dev/null 2>&1 || pacman -Sp "$dep" >/dev/null 2>&1 || echo "$dep"; done
}

case "${1:-}" in
  '')
    printf '%-38s %-10s %s\n' PACKAGE STATE 'PINNED COMMIT'
    for n in $(names); do
      d=$(fetch "$n"); head=$(git -C "$d" rev-parse HEAD); pin=$(pinned "$n")
      if [ "$pin" = UNPINNED ]; then state=unpinned
      elif [ "$pin" = "$head" ]; then state=current
      else state="behind ($(git -C "$d" rev-list --count "$pin..$head") commits)"; fi
      printf '%-38s %-10s %s\n' "$n" "$state" "$pin"
    done
    ;;
  --deps)
    [ $# -eq 2 ] || die 'usage: aur-pin.sh --deps NAME'
    d=$(fetch "$2"); not_in_repos "$d"
    ;;
  *)
    for n in "$@"; do
      grep -q -E "^$n\s" "$LOCK" || die "$n is not in pkgs/aur.lock; add a line for it first"
      d=$(fetch "$n"); head=$(git -C "$d" rev-parse HEAD); pin=$(pinned "$n")
      if [ "$pin" = "$head" ]; then echo "$n: already pinned to the latest commit"; continue; fi
      echo "=================================================================== $n"
      if [ "$pin" = UNPINNED ]; then
        for f in $(git -C "$d" ls-files); do echo "----- $f"; cat "$d/$f"; done | ${PAGER:-less}
      else
        git -C "$d" diff "$pin" "$head" | ${PAGER:-less}
      fi
      extra=$(not_in_repos "$d" | tr '\n' ' ')
      [ -z "$extra" ] || echo "NOTE: $n needs these from the AUR too (add them above it in aur.lock): $extra"
      read -rp "Pin $n to ${head:0:12}? Only if you have read it. [y/N] " a
      case "$a" in [yY]*) sed -i -E "s|^($n\s+)\S+|\1$head|" "$LOCK"; echo "pinned $n";; *) echo "not pinned";; esac
    done
    ;;
esac
