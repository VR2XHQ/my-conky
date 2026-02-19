#!/bin/bash
# 查詢套件來源（預設只顯示 APT sources 與來源判斷）
# 選項:
#   --short   只顯示來源判斷一行
#   --files   顯示 dpkg -L 檔案清單
#   --logs    顯示 dpkg 安裝/升級紀錄（含壓縮）
#   --verbose 顯示完整 Version table
#   --all     顯示 sources、來源判斷、Version table、檔案清單、安裝紀錄

PKG="$1"
OPT="$2"

# 顏色
RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
RESET="\e[0m"

usage() {
  echo -e "${YELLOW}用法: ./pkginfo.sh <package_name> [--short|--files|--logs|--verbose|--all]${RESET}"
}

if [ -z "$PKG" ]; then
  usage
  exit 1
fi

# 取得 apt-cache policy
POLICY=$(apt-cache policy "$PKG" 2>/dev/null)
INSTALLED=$(echo "$POLICY" | awk '/Installed:/ {print $2}')
VERSION_BLOCK=$(echo "$POLICY" | awk '/Version table:/,0')
REPO_LINES=$(echo "$VERSION_BLOCK" | grep -E 'https?://|file:|cdrom:')

# 判斷來源
if [ "$INSTALLED" = "(none)" ]; then
  verdict="${RED}未安裝${RESET}"
elif [ -z "$REPO_LINES" ]; then
  verdict="${RED}LOCAL 安裝（手動 .deb 或非來源庫）${RESET}"
else
  verdict="${GREEN}Repository 安裝${RESET}"
fi

# --short 模式
if [ "$OPT" = "--short" ]; then
  echo -e "套件 ${PKG}: ${verdict}"
  exit 0
fi

echo -e "${YELLOW}=== APT sources 設定檔 ===${RESET}"
find /etc/apt -type f -name "*.list"

echo
echo -e "${YELLOW}=== 套件來源辨別 ===${RESET}"
if echo -e "$verdict" | grep -q "LOCAL"; then
  echo -e "套件 ${PKG}: ${verdict}"
else
  SRC_SUMMARY=$(echo "$REPO_LINES" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' | head -n1)
  echo -e "套件 ${PKG}: ${verdict} → ${SRC_SUMMARY}"
fi

if [ "$OPT" = "--verbose" ] || [ "$OPT" = "--all" ]; then
  echo
  echo -e "${YELLOW}=== apt-cache policy Version table ===${RESET}"
  echo "$VERSION_BLOCK"
fi

# 額外選項
if [ "$OPT" = "--files" ] || [ "$OPT" = "--all" ]; then
  echo
  echo -e "${YELLOW}=== 套件檔案清單 (dpkg -L) ===${RESET}"
  dpkg -L "$PKG" 2>/dev/null || echo -e "${RED}找不到套件 $PKG${RESET}"
fi

if [ "$OPT" = "--logs" ] || [ "$OPT" = "--all" ]; then
  echo
  echo -e "${YELLOW}=== dpkg 安裝/升級紀錄 ===${RESET}"
  for f in /var/log/dpkg.log*; do
    if [[ "$f" == *.gz ]]; then
      zgrep "$PKG" "$f"
    else
      grep "$PKG" "$f"
    fi
  done
fi
