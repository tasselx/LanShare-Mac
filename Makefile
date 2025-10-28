.PHONY: help build build-simple clean run open install

help:
	@echo "LanShare - 构建命令"
	@echo ""
	@echo "可用命令:"
	@echo "  make build        - 完整打包（包含 DMG）"
	@echo "  make build-simple - 快速构建（仅应用）"
	@echo "  make clean        - 清理构建文件"
	@echo "  make run          - 构建并运行应用"
	@echo "  make open         - 在 Xcode 中打开项目"
	@echo "  make install      - 安装应用到 Applications 文件夹"
	@echo ""

build:
	@./build.sh

build-simple:
	@./build-simple.sh

clean:
	@echo "🧹 清理构建文件..."
	@rm -rf build
	@rm -rf DerivedData
	@echo "✅ 清理完成"

run: build-simple
	@echo "🚀 启动应用..."
	@open build/LanShare.app

open:
	@open LanShare.xcodeproj

install: build-simple
	@echo "📦 安装应用到 Applications 文件夹..."
	@cp -R build/LanShare.app /Applications/
	@echo "✅ 安装完成"
	@echo "可以在启动台或 Applications 文件夹中找到应用"
