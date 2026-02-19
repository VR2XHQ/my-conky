#!/usr/bin/env bash
# uninstall_from_manifest.sh
# 清除Cmake install後的安裝檔案，因為它不會自動uninstall。
# 用法:
#   ./uninstall_from_manifest.sh /path/to/install_manifest.txt
#   ./uninstall_from_manifest.sh /path/to/install_manifest.txt --prefix /custom/prefix
# 作用: 依 manifest 刪檔，並自動計算共同前綴目錄來清理空目錄。
#
# 說明:
# - 依 manifest 逐行刪檔（含最後一行無換行保護）
# - 自動計算共同前綴並做深度清理；或使用 --prefix 覆蓋前綴
# - 僅刪空目錄，避免誤刪非空目錄

set -euo pipefail

MANIFEST="${1:-}"
OVERRIDE_PREFIX=""
if [[ $# -ge 3 && "$2" == "--prefix" ]]; then
  OVERRIDE_PREFIX="$3"
fi

if [[ -z "$MANIFEST" || ! -f "$MANIFEST" ]]; then
  echo "Manifest file not found or not provided: $MANIFEST" >&2
  exit 1
fi

# 讀入所有路徑，過濾掉空行
mapfile -t PATHS < <(grep -vE '^\s*$' "$MANIFEST")

if [[ "${#PATHS[@]}" -eq 0 ]]; then
  echo "Manifest is empty." >&2
  exit 1
fi

# 計算最長共同前綴（基於 / 切分）
common_prefix() {
  IFS='/' read -r -a first <<< "${PATHS[0]}"
  local prefix_parts=()
  for (( i=0; i<${#first[@]}; i++ )); do
    local part="${first[i]}"
    [[ -z "$part" ]] && continue
    # 檢查每條路徑在同一位置是否相同
    for p in "${PATHS[@]}"; do
      IFS='/' read -r -a parts <<< "$p"
      if [[ "${parts[i]:-}" != "$part" ]]; then
        # 組合目前的共同前綴
        printf '/%s' "${prefix_parts[@]}"
        echo
        return
      fi
    done
    prefix_parts+=("$part")
  done
  # 如果所有元件都相同（例如全部同一路徑），返回完整
  printf '/%s' "${prefix_parts[@]}"
  echo
}

PREFIX="$([[ -n "$OVERRIDE_PREFIX" ]] && echo "$OVERRIDE_PREFIX" || common_prefix)"

# 修正到存在的目錄層級
while [[ -n "$PREFIX" && ! -d "$PREFIX" ]]; do
  PREFIX="$(dirname "$PREFIX")"
done

if [[ -z "$PREFIX" || "$PREFIX" == "/" ]]; then
  echo "Failed to determine a safe install prefix from manifest." >&2
  exit 1
fi

echo "Detected install prefix: $PREFIX"

# 刪除檔案（逐行，保留 -v 顯示）
echo "Removing files listed in manifest..."

# 逐行刪檔；最後一行無換行也會處理
while IFS= read -r f || [[ -n "$f" ]]; do
  [[ -z "$f" ]] && continue
  if [[ -e "$f" ]]; then
    rm -v -- "$f"
  else
    echo "Skipping missing file: $f"
  fi
done < "$MANIFEST"

# 清理空目錄（從最深層往上）
echo "Pruning empty directories under: $PREFIX"
find "$PREFIX" -depth -type d -empty -print -delete

echo "Uninstall completed."

