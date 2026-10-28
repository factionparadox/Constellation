#!/usr/bin/env bash
# Gather what the AUR review still needs, into one text file to hand back. Run it on the Arch
# build machine (it asks pacman which packages are in Arch's repositories). Changes nothing.
#   bash build/review-info.sh
# Writes C:\Users\Public\review-info.txt under WSL, otherwise ./review-info.txt.
set -uo pipefail
REPO=$(cd "$(dirname "$0")/.." && pwd)
OUT=${1:-}
if [ -z "$OUT" ]; then
  if [ -d /mnt/c/Users/Public ]; then OUT=/mnt/c/Users/Public/review-info.txt; else OUT=$PWD/review-info.txt; fi
fi
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
step() { echo ":: $*" >&2; }
fetch() { curl -fsSL --retry 5 --retry-delay 3 --retry-all-errors "$@"; }

{
step "Arch's systemd-hook"
echo "######## systemd-hook (Arch's systemd packaging)"
if git clone -q --depth 50 https://gitlab.archlinux.org/archlinux/packaging/packages/systemd.git "$TMP/systemd"; then
  sha512sum "$TMP/systemd/systemd-hook"
  echo "===== systemd-hook"; cat "$TMP/systemd/systemd-hook"
  echo "===== log"; git -C "$TMP/systemd" log -3 --format='%H %ad %s' -- systemd-hook
else
  echo "clone failed"
fi

step "Quickshell versions"
echo; echo "######## quickshell upstream"
git ls-remote https://git.outfoxxed.me/quickshell/quickshell.git 'HEAD' 'refs/heads/*' 'refs/tags/v0.3*' 2>&1

step "Dependencies of the AUR packages"
while read -r name commit _; do
  case "$name" in ''|'#'*) continue ;; esac
  fetch "https://aur.archlinux.org/cgit/aur.git/plain/.SRCINFO?h=$name&id=$commit" \
    | awk '$1 ~ /^(depends|makedepends)$/ {print $3}' >> "$TMP/raw" || echo "could not read $name's .SRCINFO"
done < "$REPO/pkgs/aur.lock"
for p in "$REPO"/pkgs/*/PKGBUILD; do
  bash -c 'source "$1" >/dev/null 2>&1; printf "%s\n" "${depends[@]}" "${makedepends[@]}"' _ "$p" >> "$TMP/raw"
done
grep -v '^#' "$REPO/pkgs/constellation-installer/packages.txt" >> "$TMP/raw"
sed 's/[<>=:].*//' "$TMP/raw" | grep -v '^$' | sort -u > "$TMP/names"

step "Checking $(wc -l < "$TMP/names") names against pacman and the AUR"
echo; echo "######## dependencies: Constellation, official repositories, AUR, or neither"
own=$( { for p in "$REPO"/pkgs/*/PKGBUILD; do basename "$(dirname "$p")"; done
         awk 'NF && $1 !~ /^#/ {print $1}' "$REPO/pkgs/aur.lock"; } | sort -u)
: > "$TMP/aur-names"
while read -r n; do
  if grep -qx -- "$n" <<<"$own"; then
    printf '%-40s constellation\n' "$n"
  elif repo=$(pacman -Si -- "$n" 2>/dev/null | awk -F': ' '/^Repository/ {print $2; exit}') && [ -n "$repo" ]; then
    printf '%-40s official %s\n' "$n" "$repo"
  elif prov=$(pacman -Sp --print-format '%r/%n' -- "$n" 2>/dev/null | tail -1) && [ -n "$prov" ]; then
    printf '%-40s provided by %s\n' "$n" "$prov"
  else
    echo "$n" >> "$TMP/aur-names"
  fi
done < "$TMP/names"

if [ -s "$TMP/aur-names" ]; then
  q=$(sed 's/^/arg[]=/' "$TMP/aur-names" | paste -sd'&')
  fetch "https://aur.archlinux.org/rpc/v5/info?$q" > "$TMP/aur.json" || echo '{"results": []}' > "$TMP/aur.json"
  python3 -I - "$TMP/aur-names" "$TMP/aur.json" <<'EOF'
import json, sys
names = open(sys.argv[1]).read().split()
found = {r['Name']: r for r in json.load(open(sys.argv[2])).get('results', [])}
for n in names:
    r = found.get(n)
    print(f"{n:40} " + (f"AUR {r['Version']} maintainer={r.get('Maintainer')} votes={r['NumVotes']} "
                         f"git={r.get('PackageBase')}" if r else 'NOT FOUND'))
EOF
fi
} > "$OUT"
step "Done: $OUT"
