#!/bin/bash

# 局域网文件共享 - 打包脚本
# 用于构建和导出 macOS 应用

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置
PROJECT_NAME="LanShare"
SCHEME_NAME="LanShare"
BUILD_DIR="build"
ARCHIVE_PATH="${BUILD_DIR}/${PROJECT_NAME}.xcarchive"
EXPORT_PATH="${BUILD_DIR}/export"
XCODE_APP_NAME="LanShare.app"  # Xcode 构建的应用名
FINAL_APP_NAME="${PROJECT_NAME}.app"  # 最终的应用名

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  LanShare - 打包脚本${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 检查 Xcode 是否安装
if ! command -v xcodebuild &> /dev/null; then
    echo -e "${RED}错误: 未找到 xcodebuild 命令${NC}"
    echo -e "${YELLOW}请确保已安装 Xcode 和 Command Line Tools${NC}"
    exit 1
fi

# 清理旧的构建文件
echo -e "${YELLOW}[1/5] 清理旧的构建文件...${NC}"
if [ -d "$BUILD_DIR" ]; then
    rm -rf "$BUILD_DIR"
fi
mkdir -p "$BUILD_DIR"
echo -e "${GREEN}✓ 清理完成${NC}"
echo ""

# 构建项目
echo -e "${YELLOW}[2/5] 构建项目...${NC}"
if command -v xcpretty &> /dev/null; then
    xcodebuild clean build \
        -project "LanShare.xcodeproj" \
        -scheme "$SCHEME_NAME" \
        -configuration Release \
        -derivedDataPath "$BUILD_DIR/DerivedData" \
        | xcpretty
else
    xcodebuild clean build \
        -project "LanShare.xcodeproj" \
        -scheme "$SCHEME_NAME" \
        -configuration Release \
        -derivedDataPath "$BUILD_DIR/DerivedData"
fi

echo -e "${GREEN}✓ 构建完成${NC}"
echo ""

# 归档项目
echo -e "${YELLOW}[3/5] 归档项目...${NC}"
if command -v xcpretty &> /dev/null; then
    xcodebuild archive \
        -project "LanShare.xcodeproj" \
        -scheme "$SCHEME_NAME" \
        -configuration Release \
        -archivePath "$ARCHIVE_PATH" \
        -derivedDataPath "$BUILD_DIR/DerivedData" \
        | xcpretty
else
    xcodebuild archive \
        -project "LanShare.xcodeproj" \
        -scheme "$SCHEME_NAME" \
        -configuration Release \
        -archivePath "$ARCHIVE_PATH" \
        -derivedDataPath "$BUILD_DIR/DerivedData"
fi

echo -e "${GREEN}✓ 归档完成${NC}"
echo ""

# 导出应用
echo -e "${YELLOW}[4/5] 导出应用...${NC}"

# 创建导出选项 plist
cat > "${BUILD_DIR}/ExportOptions.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>mac-application</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>stripSwiftSymbols</key>
    <true/>
    <key>uploadSymbols</key>
    <false/>
</dict>
</plist>
EOF

xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "${BUILD_DIR}/ExportOptions.plist" \
    | xcpretty || xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "${BUILD_DIR}/ExportOptions.plist"

echo -e "${GREEN}✓ 导出完成${NC}"
echo ""

# 创建 DMG（可选）
echo -e "${YELLOW}[5/5] 创建 DMG 安装包...${NC}"

# 获取版本号
APP_VERSION=$(defaults read "$(pwd)/${EXPORT_PATH}/${XCODE_APP_NAME}/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "1.0")

DMG_NAME="${PROJECT_NAME}-${APP_VERSION}.dmg"
DMG_PATH="${BUILD_DIR}/${DMG_NAME}"
VOLUME_NAME="LanShare"

# 删除旧的 DMG
if [ -f "$DMG_PATH" ]; then
    rm "$DMG_PATH"
fi

# 创建临时 DMG 目录
DMG_TEMP="${BUILD_DIR}/dmg_temp"
mkdir -p "$DMG_TEMP"

# 复制应用到临时目录（重命名为 LanShare.app）
if [ -d "${EXPORT_PATH}/${XCODE_APP_NAME}" ]; then
    cp -R "${EXPORT_PATH}/${XCODE_APP_NAME}" "$DMG_TEMP/${FINAL_APP_NAME}"
else
    echo -e "${RED}错误: 未找到导出的应用 ${EXPORT_PATH}/${XCODE_APP_NAME}${NC}"
    exit 1
fi

# 创建应用程序文件夹的符号链接
ln -s /Applications "$DMG_TEMP/Applications"

# 创建 DMG
hdiutil create -volname "$VOLUME_NAME" \
    -srcfolder "$DMG_TEMP" \
    -ov -format UDZO \
    "$DMG_PATH"

# 清理临时目录
rm -rf "$DMG_TEMP"

echo -e "${GREEN}✓ DMG 创建完成${NC}"
echo ""

# 显示结果
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✓ 打包完成！${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}输出文件：${NC}"
echo -e "  原始应用: ${GREEN}${EXPORT_PATH}/${XCODE_APP_NAME}${NC}"
echo -e "  DMG 安装包: ${GREEN}${DMG_PATH}${NC}"
echo ""
echo -e "${YELLOW}应用信息：${NC}"
APP_BUILD=$(defaults read "$(pwd)/${EXPORT_PATH}/${XCODE_APP_NAME}/Contents/Info.plist" CFBundleVersion 2>/dev/null || echo "未知")
APP_SIZE=$(du -sh "${EXPORT_PATH}/${XCODE_APP_NAME}" | cut -f1)
DMG_SIZE=$(du -sh "$DMG_PATH" | cut -f1)

echo -e "  版本: ${GREEN}${APP_VERSION} (${APP_BUILD})${NC}"
echo -e "  应用大小: ${GREEN}${APP_SIZE}${NC}"
echo -e "  DMG 大小: ${GREEN}${DMG_SIZE}${NC}"
echo ""
echo -e "${YELLOW}安装方法：${NC}"
echo -e "  1. 打开 ${GREEN}${DMG_NAME}${NC}"
echo -e "  2. 将 ${GREEN}${FINAL_APP_NAME}${NC} 拖到 Applications 文件夹"
echo -e "  3. 首次运行时，右键点击应用选择"打开""
echo ""
