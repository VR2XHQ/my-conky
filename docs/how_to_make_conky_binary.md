### Uninstall script with robust prefix detection and newline safety

你選擇用「自動推算前綴」的方法是對的。下面是整合了前綴偵測、最後一行無換行保護、深度目錄清理的最終版腳本。

```bash
#!/usr/bin/env bash
# uninstall_from_manifest.sh
# 用法:
#   ./uninstall_from_manifest.sh /path/to/install_manifest.txt
#   ./uninstall_from_manifest.sh /path/to/install_manifest.txt --prefix /custom/prefix
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
  echo "Manifest file not found: $MANIFEST" >&2
  exit 1
fi

# 讀入所有非空行
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
    for p in "${PATHS[@]}"; do
      IFS='/' read -r -a parts <<< "$p"
      if [[ "${parts[i]:-}" != "$part" ]]; then
        printf '/%s' "${prefix_parts[@]}"
        echo
        return
      fi
    done
    prefix_parts+=("$part")
  done
  printf '/%s' "${prefix_parts[@]}"
  echo
}

PREFIX="$([[ -n "$OVERRIDE_PREFIX" ]] && echo "$OVERRIDE_PREFIX" || common_prefix)"

# 修正到存在的目錄層級
while [[ -n "$PREFIX" && ! -d "$PREFIX" ]]; do
  PREFIX="$(dirname "$PREFIX")"
done
if [[ -z "$PREFIX" || "$PREFIX" == "/" ]]; then
  echo "Failed to determine a safe install prefix." >&2
  exit 1
fi

echo "Detected install prefix: $PREFIX"
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

echo "Pruning empty directories under: $PREFIX"
find "$PREFIX" -depth -type d -empty -print -delete

echo "Uninstall completed."
```

---

### Usage

- **基本用法:**
  - `./uninstall_from_manifest.sh /path/to/install_manifest.txt`
- **覆蓋前綴（少見，但可用於路徑漂移）:**
  - `./uninstall_from_manifest.sh /path/to/install_manifest.txt --prefix /home/beny/local/conky`

---

### Key behaviors

- **檔案刪除:** 逐行處理，包含最後一行沒有換行的情況，不會漏刪。  
- **前綴偵測:** 從所有路徑動態計算最長共同前綴並修正到存在的目錄。  
- **深度清理:** 只刪空目錄，從最深層向上清乾淨，不會誤刪非空目錄。  

---

### Quick-reference updates for your flow

#### Build

- **Configure:** `cmake .. -DCMAKE_INSTALL_PREFIX=$HOME/local/conky -DBUILD_PULSEAUDIO=ON -DBUILD_TESTS=OFF`
- **Compile:** `make -j$(nproc)`
- **Verify features:** `./conky -v`

#### Install

- **Install to prefix:** `make install`
- **Check manifest:** `cat install_manifest.txt`（若末行無換行，執行 `sed -i -e '$a\' install_manifest.txt`）

#### Uninstall

- **Reliable script:**  
  - `./uninstall_from_manifest.sh install_manifest.txt`
  - Optional: `--prefix /path/to/prefix` 覆蓋前綴（僅在需要時使用）

---

### Notes and best practices

- **Lead-in:** 保留 build tree 與 manifest，卸載更可控。  
- **Safety:** 不使用 `sudo` 於 home 前綴；系統路徑才需要 `sudo make install`。  
- **Fallback:** 若目標是徹底清除且前綴專用，可直接 `rm -rf "$PREFIX"`。  
- **Consistency:** 測試不同前綴時使用不同 build 目錄，讓每個 manifest 對應唯一安裝樹。

---


#### 這份清單可以幫你快速判斷 **Conky 的 Lua Cairo 綁定**目前是「分離模式」還是「合包模式」，並確保你的 `miracle.lua` 腳本能在各種版本下正常執行。

## 🔍 Conky Lua Cairo/Xlib 兼容性檢查清單

### 1. 檢查編譯選項

- 在 build 目錄執行：
  
  ```bash
  cmake .. -L | grep LUA
  ```

- 如果看到：
  
  - `BUILD_LUA_CAIRO=ON` 且 `BUILD_LUA_CAIRO_XLIB=ON` → **分離模式**（會生成 `cairo.so` + `cairo_xlib.so`）。
  - `BUILD_LUA_CAIRO=ON` 且 `BUILD_LUA_CAIRO_XLIB=OFF` → **合包模式**（理論上只有 `cairo.so`，需確認是否包含 Xlib）。

---

### 2. 檢查輸出檔案

- 查看安裝目錄：
  
  ```bash
  ls ~/.local/lib/conky/
  ```

- 如果有 `libcairo.so` 和 `libcairo_xlib.so` → **分離模式**。

- 如果只有 `libcairo.so` → **合包模式**（需進一步確認符號）。

---

### 3. 檢查符號是否存在

- 用 `nm` 或 `objdump` 檢查：
  
  ```bash
  nm -D ~/.local/lib/conky/libcairo.so | grep cairo_xlib_surface_create
  ```

- 如果能找到 `cairo_xlib_surface_create` → **合包成功**。

- 如果找不到 → 即使是合包編譯，Xlib 支援沒有進入 `cairo.so`，需要回到分離模式。

---

### 4. Lua 腳本寫法

- 建議保留兼容寫法：
  
  ```lua
  local ok, cairo = pcall(require, "cairo_xlib")
  if not ok then
      cairo = require("cairo")
  end
  ```

- **分離模式**：`require "cairo_xlib"` 成功 → 使用獨立模組。

- **合包模式**：`require "cairo_xlib"` 失敗 → fallback 到 `cairo`，仍能呼叫 `cairo_xlib_surface_create`。

---

### 5. 測試運行

- 啟動 Conky：
  
  ```bash
  conky -c miracle-config.lua
  ```

- 如果不再報「nil value」，代表綁定正確。

- 如果仍然報錯，回到步驟 3 檢查符號是否真的存在。

---

✅ **總結**：  
這份清單能讓你快速判斷 Conky 的 Lua Cairo 綁定是分離還是合包，並確保 `miracle.lua` 在不同版本下都能正常執行。

要不要我幫你再補一個 **快速診斷腳本**（Bash 版），自動跑這些檢查並輸出結果？
