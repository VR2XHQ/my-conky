#!/bin/bash
# package.sh - 智能打包脚本

VERSION="my-cairo-experiment"
PACKAGE_DIR="/tmp/conky-package"
PACKAGE_NAME="conky-${VERSION}-linux-x86_64"
INSTALLER_DIR="/tmp/conky-tmp-install"
OUTPUT="conky-${VERSION}-linux-x86_64.tar.gz"
SOURCE_DIR="/home/beny/testdrive/conky"
BUILD_RELEASE_DIR="${SOURCE_DIR}/build-release"
BUILD_DEBUG_DIR="${SOURCE_DIR}/build"
LOCAL_INSTALL_DIR="$HOME/.local"
RELEASE_INSTALL_DIR="/usr/local"

MODE="${1:-}"

# 檢查是否有提供參數
if [ -z "$MODE" ]; then
    echo "錯誤：請指定模式"
    echo "用法：$0 debug 或 $0 release"
    exit 1
fi

# 清除臨時檔目錄內容
rm -rf ${PACKAGE_DIR}
rm -rf ${INSTALLER_DIR}

case $MODE in
    debug)
        cd ${BUILD_DEBUG_DIR}
        cmake .. -DCMAKE_INSTALL_PREFIX=${RELEASE_INSTALL_DIR}
        make clean && make -j$(nproc)
        make install DESTDIR=${PACKAGE_DIR}
        cmake .. -DCMAKE_INSTALL_PREFIX=${LOCAL_INSTALL_DIR}
        ;;
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
            -DBUILD_PULSEAUDIO=ON
        make clean && make -j$(nproc)
        make install DESTDIR=${PACKAGE_DIR}
        ;;
    *)
        echo "錯誤：未知模式 '$MODE'"
        echo "用法：$0 debug 或 $0 release"
        exit 1
        ;;
esac

# 創建額外文件的目錄結構
mkdir -p ${PACKAGE_DIR}/opt/conky-${VERSION}

# 生成卸載腳本到 opt 目錄（不汙染系統 bin）
cat > ${PACKAGE_DIR}/opt/conky-${VERSION}/uninstall.sh << 'EOF'
#!/bin/bash
# uninstall.sh - Conky 卸載腳本（修正版）

VERSION="my-cairo-experiment"
PACKAGE_NAME="conky-${VERSION}"

echo "🗑️  Uninstalling ${PACKAGE_NAME}..."

# 檢查權限
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Please run as root (use sudo)"
    exit 1
fi

INSTALL_PREFIX="/usr/local"

# 定義要刪除的文件和目錄
FILES_TO_REMOVE=(
    "${INSTALL_PREFIX}/bin/conky"
    "${INSTALL_PREFIX}/lib/libtcp-portmon.a"
    "${INSTALL_PREFIX}/share/doc/conky-1.22.3"
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

chmod +x ${PACKAGE_DIR}/opt/conky-${VERSION}/uninstall.sh

# 生成完整的 README.md
cat > ${PACKAGE_DIR}/opt/conky-${VERSION}/README.md << 'EOF'
# Conky My Cairo Experiment

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
sudo 。/install.sh

## 卸載

```bash
sudo ./uninstall.sh   # 或 sudo /opt/conky-my-cairo-experiment/uninstall.sh
EOF

# 第一層：包含 README.md 和 install.sh 的安裝包
# 第二層：實際的程式文件 (conky-package.tar.gz)

# 創建安裝器目錄
mkdir -p ${INSTALLER_DIR}/conky-${VERSION}-installer

# 1. 先創建程式包（不含 README）
cd ${PACKAGE_DIR}
tar -czf ${INSTALLER_DIR}/conky-${VERSION}-installer/conky-files.tar.gz usr/ opt/

# 2. 創建安裝腳本
cat > ${INSTALLER_DIR}/conky-${VERSION}-installer/install.sh << 'EOF'
#!/bin/bash
# install.sh - Conky 安裝腳本

set -e

VERSION="my-cairo-experiment"
PACKAGE_NAME="conky-${VERSION}-linux-x86_64"

echo "📦 Installing ${PACKAGE_NAME}..."
echo ""

# 顯示 README
if [ -f "README.md" ]; then
    echo "📖 Reading README..."
    echo "----------------------------------------"
    cat README.md
    echo "----------------------------------------"
    echo ""
fi

# 檢查是否已安裝
if [ -f "/usr/local/bin/conky" ]; then
    echo "⚠️  Warning: /usr/local/bin/conky already exists"
    read -p "Overwrite? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Installation cancelled"
        exit 0
    fi
fi

# 檢查權限
if [ "$EUID" -ne 0 ]; then 
    echo "❌ Please run as root (use sudo)"
    exit 1
fi

# 解壓程式文件
echo "📦 Extracting files..."
tar -xzf conky-files.tar.gz -C /

# 更新動態鏈接庫
echo "🔄 Updating ldconfig..."
ldconfig

# 驗證安裝
if command -v conky &> /dev/null; then
    echo "✅ Installation successful!"
    echo "   $(which conky)"
    conky -v | head -1
else
    echo "⚠️  Installation completed but 'conky' not found in PATH"
fi

echo ""
echo "📝 To uninstall: sudo /opt/conky-${VERSION}/uninstall.sh"
EOF

chmod +x ${INSTALLER_DIR}/conky-${VERSION}-installer/install.sh

# 3. 複製 README 及卸載腳本
cp ${PACKAGE_DIR}/opt/conky-${VERSION}/* ${INSTALLER_DIR}/conky-${VERSION}-installer/

# 4. 打包（包含目錄結構）
cd ${INSTALLER_DIR}
# tar -czf /tmp/${OUTPUT} conky-${VERSION}-installer/
# 改為更短的名稱
mv ${INSTALLER_DIR}/conky-${VERSION}-installer ${INSTALLER_DIR}/conky-installer
tar -czf /tmp/${OUTPUT} conky-installer/

echo ""
echo "✅ Installer created: /tmp/${OUTPUT}"
ls -lh /tmp/${OUTPUT}

echo ""
echo "📋 Installer contents:"
tar -tzf /tmp/${OUTPUT} | head -10
