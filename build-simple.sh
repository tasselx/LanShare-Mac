#!/bin/bash

# 简化版打包脚本 - 仅构建应用，不创建 DMG

set -e

PROJECT_NAME="LanShare"
SCHEME_NAME="LanShare"
BUILD_DIR="build"

echo "🔨 开始构建 LanShare..."
echo ""

# 清理
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# 构建
xcodebuild clean build \
    -project "LanShare.xcodeproj" \
    -scheme "$SCHEME_NAME" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO

# 复制应用
APP_PATH="${BUILD_DIR}/DerivedData/Build/Products/Release/LanShare.app"
if [ -d "$APP_PATH" ]; then
    cp -R "$APP_PATH" "${BUILD_DIR}/${PROJECT_NAME}.app"
    echo ""
    echo "✅ 构建完成！"
    echo "📦 应用位置: ${BUILD_DIR}/${PROJECT_NAME}.app"
    echo ""
    echo "运行应用:"
    echo "  open ${BUILD_DIR}/${PROJECT_NAME}.app"
else
    echo "❌ 构建失败：未找到应用文件"
    exit 1
fi
