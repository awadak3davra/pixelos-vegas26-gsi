#!/usr/bin/env bash
# Reset every project touched by the patch sets to its manifest revision (drops local commits),
# and remove the "patched" stamp.  Run from the tree top.
# repo keeps the manifest revision of each project as refs/remotes/m/<manifest branch>.
set -uo pipefail
TOP="$(pwd)"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
MBR="${MBR:-sixteen-qpr2}"
source "$HERE/scripts/tree-of.sh"
for dir in "$TOP/treble_patches/patches/trebledroid" "$TOP/treble_patches/patches/trebledroid-staging" "$HERE/patches/vegas"; do
  [ -d "$dir" ] && ls "$dir"
done | sort -u | while read -r name; do
  tree="$(tree_of "$name")"
  [ -d "$TOP/$tree" ] || continue
  ( cd "$TOP/$tree"
    git am --abort >/dev/null 2>&1
    git reset -q --hard "m/$MBR" && git clean -qfd
    echo "reset $tree -> $(git rev-parse --short HEAD)" )
done
rm -f "$TOP/out/.vegas-patched"
