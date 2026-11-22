#!/usr/bin/env bash
# Apply TrebleDroid (+ staging) platform patches, then the vegas set, onto a clean PixelOS tree.
# Usage (from the tree top):  bash device/pixelos/vegas_gsi/scripts/apply-patches.sh
# One pass only: run scripts/reset-patched.sh first to start over. Patches listed in
# patches/skip.txt are not applied (each line: <set>/<dir>/<file>  # reason); a file at
# patches/override/<set>/<dir>/<file> is applied instead of the upstream one (rebased onto PixelOS).
# Writes out/vegas-patches.log and, when done, out/.vegas-patched (the build skips patching then).
set -uo pipefail

TOP="$(pwd)"
HERE="$(cd "$(dirname "$0")/.." && pwd)"
source "$HERE/scripts/tree-of.sh"
LOG="$TOP/out/vegas-patches.log"; mkdir -p "$TOP/out"; : > "$LOG"
SKIP="$HERE/patches/skip.txt"
FAILED=()

if [ -f "$TOP/out/.vegas-patched" ]; then echo "already patched (out/.vegas-patched); run reset-patched.sh to redo"; exit 0; fi

skipped() { [ -f "$SKIP" ] && grep -qE "^$1([[:space:]]|$)" "$SKIP"; }

apply_dir() {
  local dir="$1" label="$2"
  [ -d "$dir" ] || { echo "skip $label: $dir missing" | tee -a "$LOG"; return; }
  for sub in "$dir"/*/; do
    local name tree; name="$(basename "$sub")"; tree="$(tree_of "$name")"
    if [ ! -e "$TOP/$tree/.git" ]; then
      echo "NOTREE $label/$name ($tree)" >> "$LOG"; continue
    fi
    for p in "$sub"*.patch; do
      [ -e "$p" ] || continue
      local short="$label/$name/$(basename "$p")"
      if skipped "$short"; then echo "SKIP $short" >> "$LOG"; continue; fi
      # a version rebased onto PixelOS replaces the upstream file
      if [ -f "$HERE/patches/override/$short" ]; then p="$HERE/patches/override/$short"; short="$short (rebased)"; fi
      if (cd "$TOP/$tree" && git am -q --no-gpg-sign "$p" >>"$LOG" 2>&1); then
        echo "OK   $short" >> "$LOG"
      elif (cd "$TOP/$tree" && git am --abort >/dev/null 2>&1; git am -q -3 "$p" >>"$LOG" 2>&1); then
        echo "3WAY $short" >> "$LOG"
      else
        (cd "$TOP/$tree" && git am --abort >/dev/null 2>&1)
        FAILED+=("$short"); echo "FAIL $short" >> "$LOG"
      fi
    done
  done
}

TP="$TOP/treble_patches/patches"
apply_dir "$TP/trebledroid"         "trebledroid"
apply_dir "$TP/trebledroid-staging" "trebledroid-staging"
apply_dir "$HERE/patches/vegas"     "vegas"

echo "ok: $(grep -c '^OK' "$LOG")  3way: $(grep -c '^3WAY' "$LOG")  skipped: $(grep -c '^SKIP' "$LOG")  notree: $(grep -c '^NOTREE' "$LOG")  failed: ${#FAILED[@]}"
if [ ${#FAILED[@]} -gt 0 ]; then printf '  FAIL %s\n' "${FAILED[@]}"; exit 1; fi
touch "$TOP/out/.vegas-patched"
echo "all patches applied"
