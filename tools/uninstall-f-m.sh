#!/usr/bin/env bash
# Generic uninstall from CMake install_manifest.txt
# - Robust install prefix detection (common directory prefix of all entries)
# - Precise empty-dir pruning (only ascend from touched dirs, stop at prefix)
# - Optional dry-run and prefix override
# - Optional purge of dangling symlinks under prefix

set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 [--dry-run] [--prefix PREFIX] [--purge-symlinks] <install_manifest.txt>
  --dry-run          Print actions, do not modify filesystem
  --prefix PREFIX    Override detected install prefix
  --purge-symlinks   After file removal, delete dangling symlinks under prefix
EOF
}

DRY=0
PURGE_SYMS=0
OVERRIDE_PREFIX=""

# Parse args
args=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--dry-run) DRY=1; shift ;;
    -p|--prefix) OVERRIDE_PREFIX="${2:-}"; shift 2 ;;
    -s|--purge-symlinks) PURGE_SYMS=1; shift ;;
    -h|--help) usage; exit 0 ;;
    --) shift; break ;;
    -* ) echo "Unknown option: $1"; usage; exit 1 ;;
    * ) args+=("$1"); shift ;;
  esac
done
set -- "${args[@]}"

manifest="${1:-}"
[[ -n "$manifest" && -f "$manifest" ]] || { echo "Manifest not found."; usage; exit 1; }

# Read manifest into array (skip empty lines)
mapfile -t FILES < <(grep -vE '^[[:space:]]*$' "$manifest")

[[ ${#FILES[@]} -gt 0 ]] || { echo "Manifest is empty."; exit 1; }

# Compute common directory prefix of all manifest entries
dirname_of() { dirname -- "$1"; }
common_prefix() {
  local pref; pref="$(dirname_of "${FILES[0]}")"
  for f in "${FILES[@]}"; do
    local d; d="$(dirname_of "$f")"
    # Shrink pref until d is inside pref
    while [[ "$d" != "$pref" && "$d" != "$pref"/* ]]; do
      local newpref; newpref="$(dirname -- "$pref")"
      # Stop at root to avoid infinite loop
      [[ "$newpref" == "$pref" ]] && break
      pref="$newpref"
    done
  done
  printf '%s\n' "$pref"
}

PREFIX="$(
  if [[ -n "$OVERRIDE_PREFIX" ]]; then printf '%s' "$OVERRIDE_PREFIX"
  else common_prefix
  fi
)"

echo "Detected install prefix: $PREFIX"

# Remove files listed in manifest
echo "Removing files listed in manifest..."
for file in "${FILES[@]}"; do
  if [[ -e "$file" || -L "$file" ]]; then
    if [[ $DRY -eq 1 ]]; then
      echo "would remove: $file"
    else
      rm -v -- "$file"
    fi
  else
    echo "Skipping missing file: $file"
  fi
done

# Prune empty directories: ascend only from dirs we touched, stop at PREFIX
echo "Pruning empty directories (up to prefix)..."
# Unique set of start dirs
declare -A DIRSET=()
for file in "${FILES[@]}"; do
  DIRSET["$(dirname -- "$file")"]=1
done

prune_up() {
  local dir="$1"
  while [[ "$dir" != "$PREFIX" && -d "$dir" ]]; do
    if [[ -z "$(ls -A -- "$dir")" ]]; then
      if [[ $DRY -eq 1 ]]; then
        echo "would rmdir: $dir"
      else
        rmdir -v -- "$dir" || break
      fi
      dir="$(dirname -- "$dir")"
    else
      break
    fi
  done
}

for d in "${!DIRSET[@]}"; do
  prune_up "$d"
done

# Optional: purge dangling symlinks under prefix
if [[ $PURGE_SYMS -eq 1 ]]; then
  echo "Purging dangling symlinks under: $PREFIX"
  if [[ $DRY -eq 1 ]]; then
    find -L "$PREFIX" -type l -print
  else
    find -L "$PREFIX" -type l -print -delete
  fi
fi

echo "Uninstall completed."

