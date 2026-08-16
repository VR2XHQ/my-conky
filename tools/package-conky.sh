#!/bin/bash
# package-conky.sh - 智能打包脚本

MODE="${1:-}"
VERSION="$2"

# 檢查是否有提供參數
if [ -z "$MODE" ]; then
    echo "錯誤：請指定模式"
    echo "用法：$0 debug 或 release"
    exit 1
fi

# 如果 $2 是空的，就跳出詢問
if [ -z "$VERSION" ]; then
    read -p "請輸入 Version [預設: my-cairo-experiment]: " input_version
    # 如果使用者直接按 Enter（沒有輸入任何字），就套用預設值
    VERSION="${input_version:-"my-cairo-experiment"}"
fi
echo "最終採用的 VERSION 是: $VERSION"

# VERSION="${2:-my-cairo-experiment}"
PACKAGE_NAME="conky-${VERSION}-linux-x86_64"
OUTPUT="conky-${VERSION}-linux-x86_64.tar.gz"

# 打包的臨時目錄
PACKAGE_DIR="/tmp/conky-package"
INSTALLER_DIR="/tmp/conky-tmp-install"

# 本地編繹環境設定
SOURCE_DIR="/home/beny/testdrive/conky" # 設定源碼目錄
BUILD_RELEASE_DIR="${SOURCE_DIR}/build-release"
BUILD_DEBUG_DIR="${SOURCE_DIR}/build-debug"
LOCAL_INSTALL_DIR="$HOME/.local"
RELEASE_INSTALL_DIR="/usr/local" # 打包的預設安裝目錄

# 去掉開頭的 /
INSTALL_PATH="${RELEASE_INSTALL_DIR#/}"
echo "INSTALL_PATH : ${INSTALL_PATH}"  # 輸出: usr/local

# 用於收納打包系統的庫
TARGET_LIB="${PACKAGE_DIR}/${INSTALL_PATH}/lib/conky"
CONKY_BIN="${PACKAGE_DIR}/${INSTALL_PATH}/bin/conky"

# 清除臨時檔目錄內容
rm -rf ${PACKAGE_DIR} 2>/dev/null || true
rm -rf ${INSTALLER_DIR} 2>/dev/null || true
rm -f /tmp/${PACKAGE_NAME}.tar.gz


# 首先進行編繹進程
case $MODE in
    # 在 ./build-debug 先調試好
    debug)
        cd ${BUILD_DEBUG_DIR}
        cmake .. -DCMAKE_INSTALL_PREFIX=${RELEASE_INSTALL_DIR} 1>/dev/null
        make clean && make -j$(nproc) 1>/dev/null
        make install DESTDIR=${PACKAGE_DIR}
        cmake .. -DCMAKE_INSTALL_PREFIX=${LOCAL_INSTALL_DIR} 1>/dev/null
        echo "已經還原為本地安裝 ${LOCAL_INSTALL_DIR}"
        ;;
    # 設定選項作為 release 版本
    release)
        mkdir -p ${BUILD_RELEASE_DIR}
        cd ${BUILD_RELEASE_DIR}
        cmake ${SOURCE_DIR} \
            -DCMAKE_BUILD_TYPE=Release \
            -DCMAKE_INSTALL_PREFIX=${RELEASE_INSTALL_DIR} \
            -DBUILD_LUA_CAIRO=ON \
            -DBUILD_LUA_CAIRO_XLIB=OFF \
            -DBUILD_LUA_RSVG=ON \
            -DBUILD_LUA_IMLIB2=ON \
            -DBUILD_LUA_TEXT=ON \
            -DBUILD_PULSEAUDIO=ON \
            -DCMAKE_SKIP_BUILD_RPATH:BOOL=OFF \
            -DCMAKE_BUILD_WITH_INSTALL_RPATH:BOOL=ON \
            -DCMAKE_INSTALL_RPATH:STRING='$ORIGIN/../lib/conky' \
            -DCMAKE_INSTALL_RPATH_USE_LINK_PATH:BOOL=ON  1>/dev/null
        make clean && make -j$(nproc) 1>/dev/null
        make install DESTDIR=${PACKAGE_DIR}
        ;;
    *)
        echo "錯誤：未知模式 '$MODE'"
        echo "用法：$0 debug 或 $0 release"
        exit 1
        ;;
esac


# 在編譯完成後，從 PACKAGE_DIR 中讀取實際的 doc 目錄名稱
# 在生成卸載腳本之前
CONKY_DOC_DIR=$(find ${PACKAGE_DIR}/usr/share/doc -maxdepth 1 -type d -name "conky-*" -exec basename {} \; 2>/dev/null | head -1)
# 如果找不到，就用默認值
if [ -z "$CONKY_DOC_DIR" ]; then
  CONKY_DOC_DIR="conky-1.24.3"
fi
echo "檢測到的文檔目錄: $CONKY_DOC_DIR"

# 創建額外文件的目錄結構
mkdir -p ${PACKAGE_DIR}/opt/conky-${VERSION}

# 生成卸載腳本到 opt 目錄（不汙染系統 bin）
cat > ${PACKAGE_DIR}/opt/conky-${VERSION}/uninstall.sh << 'EOF'
#!/bin/bash
# uninstall.sh - Conky 卸載腳本（修正版）

VERSION="@VERSION@"
PACKAGE_NAME="conky-${VERSION}"

echo "🗑️  Uninstalling ${PACKAGE_NAME}..."

# 檢查權限
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Please run as root (use sudo)"
    exit 1
fi

INSTALL_PREFIX="@RELEASE_INSTALL_DIR@"

# 定義要刪除的文件和目錄
FILES_TO_REMOVE=(
    "${INSTALL_PREFIX}/bin/conky"
    "${INSTALL_PREFIX}/bin/conky.bin"
    "${INSTALL_PREFIX}/bin/conky.wrapper"
    "${INSTALL_PREFIX}/lib/libtcp-portmon.a"
    "${INSTALL_PREFIX}/share/doc/@CONKY_DOC_DIR@"
    "${INSTALL_PREFIX}/share/icons/hicolor/scalable/apps/conky-logomark-violet.svg"
    "${INSTALL_PREFIX}/share/applications/conky.desktop"
)

DIRS_TO_REMOVE=(
    "${INSTALL_PREFIX}/lib/conky"
)

# 顯示將要刪除的內容
echo "The following files/directories will be removed:"
for file in "${FILES_TO_REMOVE[@]}"; do
    if [ -e "$file" ] || [ -L "$file" ]; then
        echo "  📁 $file"
    fi
done
for dir in "${DIRS_TO_REMOVE[@]}"; do
    if [ -d "$dir" ]; then
        echo "  📁 $dir (directory)"
    fi
done

# 如果沒有文件要刪除，提示並退出
TOTAL_ITEMS=$(for f in "${FILES_TO_REMOVE[@]}"; do [ -e "$f" ] || [ -L "$f" ] && echo; done | wc -l)
TOTAL_DIRS=$(for d in "${DIRS_TO_REMOVE[@]}"; do [ -d "$d" ] && echo; done | wc -l)
if [ $((TOTAL_ITEMS + TOTAL_DIRS)) -eq 0 ]; then
    echo "✅ No files to remove. Uninstall already completed."
    # 刪除卸載腳本目錄
    SCRIPT_DIR="/opt/conky-${VERSION}"
    if [ -d "$SCRIPT_DIR" ]; then
        echo "🗑️  Removing uninstall script directory: $SCRIPT_DIR"
        rm -rf "$SCRIPT_DIR"
    fi
    exit 0
fi

# 確認卸載
read -p "Are you sure you want to continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Uninstall cancelled"
    exit 0
fi

# 先刪除文件（忽略錯誤）
REMOVED_COUNT=0
for file in "${FILES_TO_REMOVE[@]}"; do
    if [ -e "$file" ] || [ -L "$file" ]; then
        echo "🗑️  Removing $file"
        rm -rf "$file" 2>/dev/null || true
        ((REMOVED_COUNT++))
    fi
done

# 再刪除目錄
for dir in "${DIRS_TO_REMOVE[@]}"; do
    if [ -d "$dir" ]; then
        echo "🗑️  Removing directory $dir"
        rm -rf "$dir" 2>/dev/null || true
        ((REMOVED_COUNT++))
    fi
done

# 更新動態鏈接庫緩存
if command -v ldconfig &> /dev/null; then
    echo "🔄 Updating ldconfig..."
    ldconfig 2>/dev/null || true
fi

# 刪除卸載腳本本身
SCRIPT_DIR="/opt/conky-${VERSION}"
if [ -d "$SCRIPT_DIR" ]; then
    echo "🗑️  Removing uninstall script directory: $SCRIPT_DIR"
    rm -rf "$SCRIPT_DIR" 2>/dev/null || true
fi

echo "✅ Uninstall completed! (${REMOVED_COUNT} items removed)"

# 檢查是否還有其他 conky
if command -v conky &> /dev/null; then
    echo ""
    echo "⚠️  Note: Another version of conky may still be installed:"
    echo "   $(which conky)"
    echo "   If this is not intended, please remove it manually."
else
    echo ""
    echo "✅ No 'conky' command found in PATH. Uninstall successful!"
fi

# 檢查殘留文件
echo ""
echo "🔍 Checking for残留 files..."
FOUND=0
for file in "${FILES_TO_REMOVE[@]}"; do
    if [ -e "$file" ] || [ -L "$file" ]; then
        echo "  ⚠️  Remaining: $file"
        FOUND=1
    fi
done
for dir in "${DIRS_TO_REMOVE[@]}"; do
    if [ -d "$dir" ]; then
        echo "  ⚠️  Remaining directory: $dir"
        FOUND=1
    fi
done

if [ $FOUND -eq 0 ]; then
    echo "  ✅ No remaining files found."
fi
EOF

# 替換版本號
sed -i -e "s/@VERSION@/${VERSION}/g" -e "s|@RELEASE_INSTALL_DIR@|${RELEASE_INSTALL_DIR}|g" -e "s/@CONKY_DOC_DIR@/${CONKY_DOC_DIR}/g" ${PACKAGE_DIR}/opt/conky-${VERSION}/uninstall.sh
chmod +x ${PACKAGE_DIR}/opt/conky-${VERSION}/uninstall.sh


# 生成完整的 README.md
cat > ${PACKAGE_DIR}/opt/conky-${VERSION}/README.md << 'EOF'
# Conky My Cairo Experiment - portable version

Conky 是一個輕量級的系統監控工具，這個版本包含了 Cairo 圖形支援的實驗性功能。

## 功能特性

- ✅ Cairo 圖形渲染
- ✅ Lua 腳本支援
- ✅ PulseAudio 音頻監控
- ✅ RSVG 向量圖形支援
- ✅ IMLIB2 圖片支援

## 系統要求

- Linux 內核 2.6+
- X11 或 Wayland
- 推薦記憶體：256MB+

## 安裝
```bash
cd conky-installer
sudo ./install.sh
```

## 更改執行檔連結
```bash
sudo /opt/conky-@VERSION@/install.sh
```

## 卸載
```bash
sudo /opt/conky-@VERSION@/uninstall.sh
```
EOF

# 替換版本號
sed -i "s/@VERSION@/${VERSION}/g" ${PACKAGE_DIR}/opt/conky-${VERSION}/README.md


# 將需要的庫也打包，成為真正 portable。
# mkdir -p "$TARGET_LIB"
# # 使用 egrep 過濾掉 libc, libm, libgcc, libpthread, libdl 等 Glibc 核心庫
# ldd "$CONKY_BIN" 2>/dev/null | awk '{if ($3 ~ /^\//) print $3}' | \
#   egrep -v 'libc\.so|libm\.so|libgcc_s\.so|libpthread\.so|libdl\.so|ld-linux' | \
#   xargs -I {} cp -vu {} "$TARGET_LIB/" 1>/dev/null
ldd "$CONKY_BIN" 2>/dev/null | awk '{if ($3 ~ /^\//) print $3}' | \
  egrep -v 'libc\.so|libm\.so|libgcc_s\.so|libpthread\.so|libdl\.so|ld-linux' | \
  while read lib; do
    if [ -f "$lib" ]; then
      cp -v "$lib" "$TARGET_LIB/" 1>/dev/null || true
    fi
  done
echo "解壓並複製相容庫完成！已自動排除 Glibc 核心檔案。"


# 正式進入打包過程
# 第一層：包含 README.md 和 install.sh / uninstalled 的安裝包
# 第二層：實際的程式文件 (conky-package.tar.gz)
cd ${PACKAGE_DIR}

# 1. 創建安裝器目錄
mkdir -p ${INSTALLER_DIR}/conky-${VERSION}-installer

# 2. 創建安裝腳本
cat > ${INSTALLER_DIR}/conky-${VERSION}-installer/install.sh << 'EOF'
#!/bin/bash
# install.sh - Conky 安裝與模式切換腳本

set -e

# 定義目標路徑
CONKY_BINARY="@RELEASE_INSTALL_DIR@/bin/conky.bin"
CONKY_WRAPPER="@RELEASE_INSTALL_DIR@/bin/conky.wrapper"
CONKY_LINK="@RELEASE_INSTALL_DIR@/bin/conky"

# 檢查權限
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Please run as root (use sudo)"
    exit 1
fi

# ----------------------------------------------------
# 判斷：僅當打包檔存在時才執行檔案解壓與安裝（首次安裝）
# 若是在 /opt/conky-@VERSION@/ 再次執行，則自動跳過解壓步驟
# ----------------------------------------------------
if [ -f "conky-files.tar.gz" ]; then
    echo "📦 Installing ${PACKAGE_NAME}..."
    echo ""

    if [ -f "README.md" ]; then
        echo "📖 Reading README..."
        echo "----------------------------------------"
        cat README.md
        echo "----------------------------------------"
        echo ""
    fi

    # 解壓程式文件
    echo "📦 Extracting files..."
    tar -xzf conky-files.tar.gz -C /

    # 更新動態鏈接庫
    echo "🔄 Updating ldconfig..."
    ldconfig
    echo ""
else
    echo "🔄 僅進行 Conky 執行模式切換..."
fi

# ----------------------------------------------------
# 模式切換邏輯
# ----------------------------------------------------
echo "=========================================="
echo "    Conky Portable 模式切換與安裝"
echo "=========================================="
echo " 1) 使用 Wrapper 模式 (conky -> conky.wrapper)"
echo " 2) 使用原生模式   (conky -> conky.bin)"
echo "=========================================="
read -p "請選擇模式 [1/2] (預設為 1): " choice

# [微調 1] 變數的大小寫修正為 choice，預設為 1
choice=${choice:-1}

# [微調 2] 原本腳本已是 root 身份，內部無需再用 sudo
if [ "$choice" -eq 2 ]; then
    echo "--> 切換至原生模式..."
    ln -snf "$CONKY_BINARY" "$CONKY_LINK"
    echo "✅ 切換成功！'$CONKY_LINK' 目前指向 'conky.bin'"
else
    echo "--> 切換至 Wrapper 模式..."
    ln -snf "$CONKY_WRAPPER" "$CONKY_LINK"
    echo "✅ 切換成功！'$CONKY_LINK' 目前指向 'conky.wrapper'"
fi

# 驗證安裝/連結狀態
if command -v conky &> /dev/null; then
    echo "✅ 驗證成功！目前執行的 Conky 為：$(which conky)"
    conky -v | head -1
else
    echo "⚠️  注意：'@RELEASE_INSTALL_DIR@/bin' 可能不在系統 PATH 中"
fi

echo ""
echo "🎉 處理完成！日後如需變更模式，可隨時執行："
echo "   sudo /opt/conky-@VERSION@/install.sh"
EOF

# 替換版本號
sed -i -e "s/@VERSION@/${VERSION}/g" -e "s|@RELEASE_INSTALL_DIR@|${RELEASE_INSTALL_DIR}|g" ${INSTALLER_DIR}/conky-${VERSION}-installer/install.sh
chmod +x ${INSTALLER_DIR}/conky-${VERSION}-installer/install.sh

# 3. 創建第二層程式包
# 使用 Shell Wrapper 腳本
mv ${INSTALL_PATH}/bin/conky ${INSTALL_PATH}/bin/conky.bin
cat > ${INSTALL_PATH}/bin/conky.wrapper << 'EOF'
#!/usr/bin/env bash
# 僅為 conky 臨時注入私有庫路徑，不影響系統其他程式
export LD_LIBRARY_PATH="@RELEASE_INSTALL_DIR@/lib/conky:${LD_LIBRARY_PATH}"
# 如果遇到問題，可以取消註解下一行來除錯
# echo "LD_LIBRARY_PATH=${LD_LIBRARY_PATH}"
exec @RELEASE_INSTALL_DIR@/bin/conky.bin "$@"
EOF
sed -i "s|@RELEASE_INSTALL_DIR@|${RELEASE_INSTALL_DIR}|g" ${PACKAGE_DIR}/${INSTALL_PATH}/bin/conky.wrapper
chmod +x ${PACKAGE_DIR}/${INSTALL_PATH}/bin/conky.wrapper

# 將 install.sh 也放到 opt/conky-${VERSION}
cp ${INSTALLER_DIR}/conky-${VERSION}-installer/install.sh ${PACKAGE_DIR}/opt/conky-${VERSION}/

# 一切設置好，正式打包
tar -czf ${INSTALLER_DIR}/conky-${VERSION}-installer/conky-files.tar.gz ${INSTALL_PATH}/ opt/

# 4. 創建第一層打包
cd ${INSTALLER_DIR}
# 複製 README 及卸載腳本
cp ${PACKAGE_DIR}/opt/conky-${VERSION}/README.md ${INSTALLER_DIR}/conky-${VERSION}-installer/

# 改為更短的名稱
mv ${INSTALLER_DIR}/conky-${VERSION}-installer ${INSTALLER_DIR}/conky-installer

# 一切設置好，正式打包
tar -czf /tmp/${OUTPUT} conky-installer/

# 5. 簡單驗証
echo ""
echo "✅ Installer created: /tmp/${OUTPUT}"
ls -lh /tmp/${OUTPUT}

echo ""
echo "📋 Installer contents:"
tar -tzf /tmp/${OUTPUT} | head -10
