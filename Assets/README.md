# LanShare 应用图标

## 📁 文件说明

### 图标文件

- **AppIcon.svg** - 主图标（渐变版本）
  - 蓝色渐变背景
  - 白色电脑和上传箭头
  - 信号波纹效果
  - 适合应用图标

- **AppIcon-Simple.svg** - 简化图标（纯色版本）
  - 纯蓝色背景 (#007AFF)
  - 白色图标元素
  - 更简洁的设计
  - 适合小尺寸显示

### 生成的文件

- **AppIcon.icns** - macOS 应用图标文件
- **AppIcon.iconset/** - 各种尺寸的 PNG 文件

## 🎨 图标设计

### 设计理念

图标由以下元素组成：

1. **电脑显示器** - 代表本地设备
2. **上传箭头** - 代表文件分享/上传
3. **信号波纹** - 代表局域网连接
4. **蓝色背景** - macOS 系统色，现代感

### 颜色方案

- **主色调**: #007AFF (iOS/macOS 蓝色)
- **渐变色**: #5AC8FA → #007AFF
- **图标色**: #FFFFFF (白色)

## 🔨 生成图标

### 方法一：使用脚本（推荐）

```bash
# 安装依赖（选择其一）
brew install librsvg    # rsvg-convert
# 或
brew install inkscape   # inkscape

# 生成图标
./generate-icon.sh
```

### 方法二：在线工具

1. 访问 [CloudConvert](https://cloudconvert.com/svg-to-icns) 或类似工具
2. 上传 `AppIcon.svg`
3. 转换为 ICNS 格式
4. 下载并保存为 `Assets/AppIcon.icns`

### 方法三：手动生成

```bash
# 创建 iconset 目录
mkdir -p Assets/AppIcon.iconset

# 使用 rsvg-convert 生成各种尺寸
rsvg-convert -w 16 -h 16 Assets/AppIcon.svg -o Assets/AppIcon.iconset/icon_16x16.png
rsvg-convert -w 32 -h 32 Assets/AppIcon.svg -o Assets/AppIcon.iconset/icon_16x16@2x.png
rsvg-convert -w 32 -h 32 Assets/AppIcon.svg -o Assets/AppIcon.iconset/icon_32x32.png
rsvg-convert -w 64 -h 64 Assets/AppIcon.svg -o Assets/AppIcon.iconset/icon_32x32@2x.png
rsvg-convert -w 128 -h 128 Assets/AppIcon.svg -o Assets/AppIcon.iconset/icon_128x128.png
rsvg-convert -w 256 -h 256 Assets/AppIcon.svg -o Assets/AppIcon.iconset/icon_128x128@2x.png
rsvg-convert -w 256 -h 256 Assets/AppIcon.svg -o Assets/AppIcon.iconset/icon_256x256.png
rsvg-convert -w 512 -h 512 Assets/AppIcon.svg -o Assets/AppIcon.iconset/icon_256x256@2x.png
rsvg-convert -w 512 -h 512 Assets/AppIcon.svg -o Assets/AppIcon.iconset/icon_512x512.png
rsvg-convert -w 1024 -h 1024 Assets/AppIcon.svg -o Assets/AppIcon.iconset/icon_512x512@2x.png

# 转换为 .icns
iconutil -c icns Assets/AppIcon.iconset -o Assets/AppIcon.icns
```

## 📦 在 Xcode 中使用

### 方式一：使用 Asset Catalog（推荐）

1. 在 Xcode 中打开项目
2. 打开 `Assets.xcassets`
3. 如果没有 AppIcon，右键 → New App Icon
4. 将生成的 PNG 文件拖入对应尺寸
5. 或直接拖入 `AppIcon.icns` 文件

### 方式二：直接使用 ICNS

1. 将 `AppIcon.icns` 复制到项目中
2. 在项目设置中设置图标路径
3. Build Settings → App Icon → 选择 AppIcon.icns

## 🎯 所需尺寸

macOS 应用图标需要以下尺寸：

| 尺寸 | 用途 |
|------|------|
| 16x16 | 小图标 |
| 32x32 | 小图标 @2x |
| 128x128 | 中等图标 |
| 256x256 | 中等图标 @2x |
| 512x512 | 大图标 |
| 1024x1024 | 大图标 @2x |

## 🔧 自定义图标

### 修改颜色

编辑 SVG 文件中的颜色值：

```xml
<!-- 背景渐变 -->
<stop offset="0%" style="stop-color:#5AC8FA;stop-opacity:1" />
<stop offset="100%" style="stop-color:#007AFF;stop-opacity:1" />
```

### 修改设计

使用以下工具编辑 SVG：

- [Figma](https://figma.com) - 在线设计工具
- [Sketch](https://sketch.com) - macOS 设计工具
- [Inkscape](https://inkscape.org) - 免费开源工具
- [Adobe Illustrator](https://adobe.com/illustrator) - 专业工具

## 📝 注意事项

1. **圆角半径**: macOS 图标使用 22% 的圆角半径（1024px 图标为 226px）
2. **安全区域**: 保持重要元素在中心 80% 区域内
3. **阴影**: macOS 会自动添加阴影，无需在图标中添加
4. **透明度**: 背景应该是不透明的
5. **分辨率**: 使用矢量格式（SVG）以支持任意缩放

## 🚀 快速开始

```bash
# 1. 生成图标
./generate-icon.sh

# 2. 在 Xcode 中设置
# 打开 Assets.xcassets → AppIcon → 拖入图标

# 3. 构建应用
make build
```

## 📚 参考资料

- [Apple Human Interface Guidelines - App Icons](https://developer.apple.com/design/human-interface-guidelines/app-icons)
- [macOS Icon Template](https://developer.apple.com/design/resources/)
- [SF Symbols](https://developer.apple.com/sf-symbols/)
