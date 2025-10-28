# LanShare - 快速开始

## 🚀 5分钟上手指南

### 1. 克隆项目

```bash
git clone <repository-url>
cd LanShare-Mac
```

### 2. 构建应用

选择以下任一方式：

#### 方式 A：使用 Make（推荐）

```bash
# 快速构建
make build-simple

# 构建并运行
make run

# 安装到系统
make install
```

#### 方式 B：使用脚本

```bash
# 快速构建
./build-simple.sh

# 完整打包（包含 DMG）
./build.sh
```

#### 方式 C：使用 Xcode

```bash
# 打开项目
make open

# 或
open LanShare.xcodeproj
```

然后按 `Cmd + R` 运行

### 3. 使用应用

#### 分享文件

1. 启动应用
2. 拖放文件到窗口，或点击"选择文件"
3. 点击"二维码"按钮查看二维码
4. 或点击"复制链接"分享链接

#### 接收文件

在其他设备上：

- **手机/平板**：扫描二维码下载
- **电脑**：在浏览器中输入分享链接
- **批量下载**：访问文件列表页面（点击"在浏览器中打开"）

### 4. 常见问题

#### Q: 其他设备无法访问？

A: 确保：
- 所有设备在同一局域网（WiFi）
- 防火墙允许应用访问网络
- 应用正在运行（服务状态显示"服务运行中"）

#### Q: 如何查看本机 IP？

A: 应用顶部状态栏会显示本机 IP 地址

#### Q: 如何更改端口？

A: 编辑 `LanShare/Managers/NetworkManager.swift`，修改 `port` 变量（默认 8080）

#### Q: 应用名称是什么？

A: 应用显示名称为 **LanShare**，项目文件夹名称为 LanShare

#### Q: 构建失败？

A: 检查：
- Xcode 版本是否 >= 14.0
- macOS 版本是否 >= 13.0
- 是否安装了 Command Line Tools：`xcode-select --install`

### 5. 清理

```bash
# 清理构建文件
make clean

# 或
rm -rf build DerivedData
```

## 📚 更多信息

- 完整文档：[README.md](README.md)
- 项目结构：查看 README.md 中的"项目结构"部分
- 技术实现：查看 README.md 中的"技术实现"部分

## 🎯 下一步

- 自定义端口和配置
- 添加密码保护
- 设置分享链接有效期
- 查看下载统计

祝使用愉快！🎉
