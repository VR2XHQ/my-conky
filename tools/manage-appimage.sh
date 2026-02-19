#!/bin/bash
# AppImage 管理工具：安裝、清理、列出、卸載、更新

ACTION="$1"
APP="$2"

install_appimage() {
  local APP="$1"
  local NAME
  local DIR

  NAME=$(basename "$APP" .AppImage)
  DIR="${NAME}-root"

  echo "📦 解壓 $APP 到 $DIR/"
  "$APP" --appimage-extract >/dev/null 2>&1
  mv squashfs-root "$DIR"

  # 詢問是否繼續進行
  read -p "要進行新增 launcher 項目嗎？(y/N): " ans
  if [[ ! "$ans" =~ ^[Yy]$ ]]; then
    echo "⏩ 已跳過安裝。"
    return
  fi

  # 詢問是否更改名稱
  echo "預設名稱：$NAME"
  read -p "要改成別的名字嗎？(直接輸入新名字或按 Enter 保留): " newname
  # [ -n "$newname" ] && NAME="$newname"
  if [ -n "$newname" ]; then
    NAME="$newname"
  fi
  echo "📂 安裝中，名稱：$NAME ..."

  # DESKTOP_FILE=$(find "$DIR" -name "*.desktop" | head -n 1)
  DESKTOP_FILE=$(find "$DIR" -maxdepth 1 -type f -name "*.desktop" | head -n 1)
  if [ -z "$DESKTOP_FILE" ]; then
    echo "⚠️ 沒找到 .desktop 檔，可能需要手動建立。"
    return
  fi

  cp "$DESKTOP_FILE" ~/.local/share/applications/"$NAME".desktop
  sed -i "s|Exec=.*|Exec=$APP|" ~/.local/share/applications/"$NAME".desktop
  echo "X-AppImage-Installed-By=manage-appimage" >> ~/.local/share/applications/"$NAME".desktop

  # 改良版 icon 搜尋邏輯
  ICON_FILE=$(find "$DIR" -maxdepth 1 -type f \( -name "*.png" -o -name "*.svg" \) | head -n 1)
  # if [ -z "$ICON_FILE" ]; then
  #   ICON_FILE=$(find "$DIR" -type f \( -name "*.png" -o -name "*.svg" \) \
  #     | grep -i "$(basename "$APP" .AppImage)" | head -n 1)
  # fi
  # if [ -z "$ICON_FILE" ]; then
  #   ICON_FILE=$(find "$DIR" -type f \( -name "*.png" -o -name "*.svg" \) | sort | head -n 1)
  # fi

  if [ -n "$ICON_FILE" ]; then
    echo "找到 icon：$ICON_FILE"
    echo "預設名稱：$NAME"
    read -p "要改存檔名稱嗎？(直接輸入新名字或按 Enter 保留): " iconname
    if [ -z "$iconname" ]; then
      iconname="$NAME"
    fi
    mkdir -p ~/.local/share/icons/
    cp "$ICON_FILE" ~/.local/share/icons/"$iconname".png
    sed -i "s|Icon=.*|Icon=$iconname|" ~/.local/share/applications/"$NAME".desktop
    echo "✅ 使用 icon: $ICON_FILE → $iconname.png"
  else
    echo "⚠️ 沒找到 icon，launcher 可能顯示預設齒輪。"
  fi

  update-desktop-database ~/.local/share/applications/
  echo "✅ $NAME 已安裝到 launcher，icon 已處理。"

  # 詢問是否刪掉當前安裝的 root 目錄
  read -p "🧹 要刪掉臨時目錄 $DIR 嗎？(y/N): " ans
  if [[ "$ans" =~ ^[Yy]$ ]]; then
    rm -rf "$DIR"
    echo "✅ 已刪除 $DIR/"
  else
    echo "⏩ 保留 $DIR/ 以便後續檢查。"
  fi
}


# 其他功能 (clean, list, uninstall, update) 保持不變

clean_roots() {
  echo "🧹 清理殘留的 *-root/ 目錄..."
  for DIR in *-root squashfs-root; do
    if [ -d "$DIR" ]; then
      rm -rf "$DIR"
      echo "刪除 $DIR/"
    fi
  done
  echo "✅ 清理完成。"
}

list_installed() {
  echo "📋 已安裝的 AppImage launcher："
  grep -l "X-AppImage-Installed-By=manage-appimage" ~/.local/share/applications/*.desktop 2>/dev/null \
    | while read FILE; do
      NAME=$(basename "$FILE" .desktop)
      echo " - $NAME"
    done
}

uninstall_appimage() {
  NAME="$APP"
  echo "🗑️ 卸載 $NAME..."

  if [ -f ~/.local/share/applications/"$NAME".desktop ]; then
    rm ~/.local/share/applications/"$NAME".desktop
    echo "刪除 ~/.local/share/applications/$NAME.desktop"
  else
    echo "$NAME 沒有安裝"
  fi

  if [ -f ~/.local/share/icons/"$NAME".png ]; then
    rm ~/.local/share/icons/"$NAME".png
    echo "刪除 ~/.local/share/icons/$NAME.png"
    else
    echo "$NAME 沒有安裝"
  fi

  update-desktop-database ~/.local/share/applications/
  echo "✅ $NAME 已卸載完成。"
}

update_appimage() {
  NAME=$(basename "$APP" .AppImage)
  echo "🔄 嘗試更新 $APP..."

  if command -v AppImageUpdate >/dev/null 2>&1; then
    AppImageUpdate "$APP"
    echo "✅ $NAME 已透過 AppImageUpdate 更新。"
  else
    echo "⚠️ 系統未安裝 AppImageUpdate，請手動下載新版 AppImage 替換舊檔。"
    echo "👉 建議：到官方網站或 GitHub release 頁面下載最新版本。"
  fi
}

case "$ACTION" in
  install)
    if [ -z "$APP" ]; then
      echo "用法: $0 install /path/to/MyApp.AppImage"
      exit 1
    fi
    install_appimage "$2"
    ;;
  clean)
    clean_roots
    ;;
  list)
    list_installed
    ;;
  uninstall)
    if [ -z "$APP" ]; then
      echo "用法: $0 uninstall <AppName>"
      exit 1
    fi
    uninstall_appimage
    ;;
  update)
    if [ -z "$APP" ]; then
      echo "用法: $0 update /path/to/MyApp.AppImage"
      exit 1
    fi
    update_appimage
    ;;
  *)
    echo "用法:"
    echo "  install /path/to/MyApp.AppImage   # 安裝 AppImage 到 launcher"
    echo "  clean                             # 清理殘留目錄"
    echo "  list                              # 列出已安裝的 AppImage"
    echo "  uninstall <AppName>               # 卸載指定 AppImage"
    echo "  update /path/to/MyApp.AppImage    # 更新指定 AppImage"
    ;;
esac

