#!/usr/bin/env bash
# Publish the built package repository (out/repo) as the assets of the "repo" release on
# GitHub, which is where installed systems' pacman looks for Constellation's packages:
#   Server = https://github.com/factionparadox/Constellation/releases/download/repo
#
#   build/publish-repo.sh [--repo OWNER/NAME] [--dir DIR]
#
# Needs the GitHub CLI logged in (gh auth login). Only signed repositories are published.
set -Eeuo pipefail
HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
DIR=$HERE/../out/repo GH_REPO=factionparadox/Constellation TAG=repo
while [ $# -gt 0 ]; do
  case "$1" in
    --repo) GH_REPO=$2; shift 2 ;;
    --dir) DIR=$2; shift 2 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done
die() { printf 'publish-repo: %s\n' "$*" >&2; exit 1; }
command -v gh >/dev/null || die 'install the GitHub CLI: sudo pacman -S github-cli'
[ -f "$DIR/constellation.db.tar.gz" ] || die "no repository in $DIR (build/build-repo.sh)"
[ -f "$DIR/constellation.db.tar.gz.sig" ] || die 'the repository is not signed; refusing to publish it'
stage=$(mktemp -d); trap 'rm -rf "$stage"' EXIT
# Release assets cannot be symlinks, and ':' is not allowed in their names.
for f in "$DIR"/*.pkg.tar.zst "$DIR"/*.pkg.tar.zst.sig; do
  case "$f" in *:*) die "$(basename "$f") has ':' in its name (an epoch), which GitHub release assets cannot hold" ;; esac
  cp "$f" "$stage/"
done
for db in constellation.db constellation.files; do
  cp -L "$DIR/$db.tar.gz" "$stage/$db"; cp -L "$DIR/$db.tar.gz.sig" "$stage/$db.sig"
done
gh release view "$TAG" --repo "$GH_REPO" >/dev/null 2>&1 ||
  gh release create "$TAG" --repo "$GH_REPO" --title 'Constellation package repository' \
    --notes 'pacman repository: Server = https://github.com/'"$GH_REPO"'/releases/download/repo'
gh release upload "$TAG" --repo "$GH_REPO" --clobber "$stage"/*
echo "Published $(ls "$stage" | wc -l) files to $GH_REPO release $TAG."
