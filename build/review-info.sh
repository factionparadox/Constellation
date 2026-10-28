#!/usr/bin/env bash
# Gather what the AUR review still needs, into one text file to hand back. Runs on any Linux
# with git, curl and python3 (it does not need Arch). Changes nothing; only reads the web.
#   bash build/review-info.sh > review-info.txt
set -uo pipefail
REPO=$(cd "$(dirname "$0")/.." && pwd)
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

echo "######## systemd-hook (Arch's systemd packaging)"
if git clone -q --depth 50 https://gitlab.archlinux.org/archlinux/packaging/packages/systemd.git "$TMP/systemd"; then
  sha512sum "$TMP/systemd/systemd-hook"
  echo "===== systemd-hook"; cat "$TMP/systemd/systemd-hook"
  echo "===== log"; git -C "$TMP/systemd" log -3 --format='%H %ad %s' -- systemd-hook
else
  echo "clone failed"
fi

echo; echo "######## quickshell upstream"
git ls-remote https://git.outfoxxed.me/quickshell/quickshell.git 'HEAD' 'refs/heads/*' 'refs/tags/v0.3*' 2>&1

echo; echo "######## dependencies: official repositories, AUR, or neither"
{
  while read -r name commit _; do
    case "$name" in ''|'#'*) continue ;; esac
    curl -fsS "https://aur.archlinux.org/cgit/aur.git/plain/.SRCINFO?h=$name&id=$commit" \
      | awk '$1 ~ /^(depends|makedepends)$/ {print $3}'
  done < "$REPO/pkgs/aur.lock"
  for p in "$REPO"/pkgs/*/PKGBUILD; do
    bash -c 'source "$1" >/dev/null 2>&1; printf "%s\n" "${depends[@]}" "${makedepends[@]}"' _ "$p"
  done
  grep -v '^#' "$REPO/pkgs/constellation-installer/packages.txt"
} | sed 's/[<>=:].*//' | grep -v '^$' | sort -u > "$TMP/names"

python3 -I - "$TMP/names" "$REPO" <<'EOF'
import json, sys, urllib.parse, urllib.request
from pathlib import Path
names = Path(sys.argv[1]).read_text().split()
own = {p.parent.name for p in Path(sys.argv[2], 'pkgs').glob('*/PKGBUILD')}
own |= {l.split()[0] for l in Path(sys.argv[2], 'pkgs/aur.lock').read_text().splitlines() if l.strip() and l[0] != '#'}
def get(url):
    with urllib.request.urlopen(url, timeout=60) as r:
        return json.load(r)
aur = {}
for i in range(0, len(names), 100):
    q = '&'.join('arg[]=' + urllib.parse.quote(n) for n in names[i:i + 100])
    for r in get('https://aur.archlinux.org/rpc/v5/info?' + q)['results']:
        aur[r['Name']] = r
for n in names:
    if n in own:
        where = 'constellation'
    else:
        hits = get('https://archlinux.org/packages/search/json/?name=' + urllib.parse.quote(n))['results']
        if hits:
            where = 'official ' + hits[0]['repo']
        elif n in aur:
            a = aur[n]
            where = f"AUR {a['Version']} maintainer={a.get('Maintainer')} votes={a['NumVotes']}"
        else:
            prov = get('https://archlinux.org/packages/search/json/?q=' + urllib.parse.quote(n))['results']
            prov = [h['pkgname'] for h in prov if n in h.get('provides', []) or any(x.startswith(n + '=') for x in h.get('provides', []))]
            where = 'provided by ' + ', '.join(prov) if prov else 'NOT FOUND'
    print(f'{n:40} {where}')
EOF
