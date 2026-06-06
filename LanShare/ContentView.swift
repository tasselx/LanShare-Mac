import SwiftUI
import UniformTypeIdentifiers
import CoreImage.CIFilterBuiltins

struct ContentView: View {
    @EnvironmentObject var networkManager: NetworkManager
    @StateObject private var updateChecker = UpdateChecker()
    @State private var isDragging = false
    @State private var showFilePicker = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var hoveredFileId: String?
    
    var body: some View {
        ZStack {
            // 背景渐变
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(nsColor: .controlBackgroundColor),
                    Color(nsColor: .controlBackgroundColor).opacity(0.95)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
            // 顶部状态栏 - 增强版
            HStack(spacing: 0) {
                // Logo 和标题
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.7)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("LanShare")
                            .font(.title3)
                            .fontWeight(.bold)
                        
                        if let port = networkManager.port {
                            Text("端口 \(port)")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // 状态信息区域
                if !networkManager.localIPAddress.isEmpty {
                    HStack(spacing: 15) {
                        // IP 地址卡片
                        HStack(spacing: 8) {
                            Image(systemName: "network")
                                .font(.caption)
                                .foregroundColor(.blue)
                            
                            Text(networkManager.localIPAddress)
                                .font(.system(.caption, design: .monospaced))
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.blue.opacity(0.1))
                        )
                        
                        // 服务状态指示器
                        HStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(networkManager.isServerRunning ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                                    .frame(width: 20, height: 20)
                                
                                Circle()
                                    .fill(networkManager.isServerRunning ? Color.green : Color.red)
                                    .frame(width: 10, height: 10)
                            }
                            
                            Text(networkManager.isServerRunning ? "运行中" : "未启动")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(networkManager.isServerRunning ? .green : .red)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(nsColor: .controlBackgroundColor))
                                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                        )
                    }
                }
                
                // 检查更新按钮（有新版本时显示红点）
                if updateChecker.hasUpdate {
                    Button(action: openReleasePage) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.circle")
                                .font(.caption)
                            Text("更新")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .overlay(alignment: .topTrailing) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .offset(x: 3, y: -3)
                    }
                    .help("发现新版本 \(updateChecker.latestVersion)，点击前往更新")
                }
                
                // 浏览器打开按钮
                if !networkManager.sharedFiles.isEmpty {
                    Button(action: openFileListInBrowser) {
                        HStack(spacing: 6) {
                            Image(systemName: "safari")
                                .font(.caption)
                            Text("浏览器")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, 25)
            .padding(.vertical, 15)
            .background(
                Color(nsColor: .controlBackgroundColor)
                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
            )
            
            Divider()
            
            // 限速设置区域
            SpeedLimitSettingsView(networkManager: networkManager)
            
            Divider()
            
            ScrollView {
                VStack(spacing: 25) {
                    // 拖放区域
                    VStack(spacing: 15) {
                        Image(systemName: isDragging ? "arrow.down.doc.fill" : "square.and.arrow.up")
                            .font(.system(size: 50))
                            .foregroundColor(isDragging ? .blue : .secondary)
                        
                        Text(isDragging ? "松开以添加文件" : "拖放文件到这里")
                            .font(.title3)
                            .fontWeight(.medium)
                        
                        Button("或点击选择文件") {
                            showFilePicker = true
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                isDragging ? Color.blue : Color.gray.opacity(0.3),
                                style: StrokeStyle(lineWidth: 2, dash: [8])
                            )
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isDragging ? Color.blue.opacity(0.05) : Color.clear)
                            )
                    )
                    .padding(.horizontal, 25)
                    .padding(.top, 20)
                    .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers in
                        handleDrop(providers: providers)
                        return true
                    }
                    
                    // 局域网共享剪贴板
                    ClipboardShareView(
                        networkManager: networkManager,
                        onCopySuccess: { message in
                            showToastMessage(message)
                        }
                    )
                    .padding(.horizontal, 25)
                    
                    // 共享文件列表
                    if !networkManager.sharedFiles.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("共享中的文件")
                                    .font(.headline)
                                
                                Spacer()
                                
                                Text("\(networkManager.sharedFiles.count) 个")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.gray.opacity(0.15))
                                    .cornerRadius(8)
                            }
                            .padding(.horizontal, 25)
                            
                            VStack(spacing: 10) {
                                ForEach(networkManager.sharedFiles) { file in
                                    SharedFileCard(
                                        file: file,
                                        networkManager: networkManager,
                                        onRemove: {
                                            withAnimation {
                                                networkManager.removeSharedFile(file)
                                            }
                                        },
                                        onCopySuccess: { message in
                                            showToastMessage(message)
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal, 25)
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
            }
            
            // Toast 提示
            if showToast {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.white)
                            .font(.body)
                        Text(toastMessage)
                            .foregroundColor(.white)
                            .font(.body)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.85))
                    )
                    .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                    Spacer()
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(minWidth: 750, minHeight: 550)
        .onAppear { updateChecker.checkForUpdate() }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result: result)
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) {
        for provider in providers {
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    DispatchQueue.main.async {
                        networkManager.shareFile(url: url)
                    }
                }
            }
        }
    }
    
    private func handleFileSelection(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                networkManager.shareFile(url: url)
            }
        case .failure(let error):
            print("文件选择失败: \(error)")
        }
    }
    
    private func openFileListInBrowser() {
        if let url = URL(string: networkManager.getFileListURL()) {
            NSWorkspace.shared.open(url)
        }
    }
    
    // 打开 GitHub release 页面进行更新
    private func openReleasePage() {
        if let url = URL(string: updateChecker.releaseURL) {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func showToastMessage(_ message: String) {
        toastMessage = message
        withAnimation {
            showToast = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showToast = false
            }
        }
    }
}

struct SharedFileCard: View {
    let file: SharedFile
    let networkManager: NetworkManager
    let onRemove: () -> Void
    let onCopySuccess: (String) -> Void
    
    @State private var showQRPopover = false
    @State private var qrCodeImage: NSImage?
    
    var shareURL: String {
        networkManager.getShareURL(for: file)
    }
    
    var body: some View {
        HStack(spacing: 15) {
            // 文件图标
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 50, height: 50)
                
                Image(systemName: iconForFile(file.name))
                    .font(.system(size: 24))
                    .foregroundColor(.blue)
            }
            
            // 文件信息
            VStack(alignment: .leading, spacing: 4) {
                Text(file.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                HStack(spacing: 12) {
                    Label(file.sizeString, systemImage: "doc")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Label(formatDate(file.shareDate), systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // 操作按钮
            HStack(spacing: 8) {
                Button(action: copyToClipboard) {
                    HStack(spacing: 4) {
                        Image(systemName: "link")
                            .font(.caption)
                        Text("复制链接")
                            .font(.caption)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button(action: { 
                    showQRPopover.toggle()
                    if showQRPopover && qrCodeImage == nil {
                        generateQRCode()
                    }
                }) {
                    Image(systemName: "qrcode")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .popover(isPresented: $showQRPopover, arrowEdge: .bottom) {
                    QRCodePopoverView(
                        qrCodeImage: qrCodeImage,
                        shareURL: shareURL,
                        onCopy: {
                            copyToClipboard()
                            showQRPopover = false
                        }
                    )
                }
                
                Button(action: onRemove) {
                    Image(systemName: "trash")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundColor(.red)
            }
        }
        .padding(15)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func generateQRCode() {
        DispatchQueue.global(qos: .userInitiated).async {
            let context = CIContext()
            let filter = CIFilter.qrCodeGenerator()
            
            filter.message = Data(shareURL.utf8)
            filter.correctionLevel = "M"
            
            if let outputImage = filter.outputImage {
                let transform = CGAffineTransform(scaleX: 10, y: 10)
                let scaledImage = outputImage.transformed(by: transform)
                
                if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                    let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: 120, height: 120))
                    DispatchQueue.main.async {
                        self.qrCodeImage = nsImage
                    }
                }
            }
        }
    }
    
    private func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(shareURL, forType: .string)
        onCopySuccess("链接已复制")
    }
    
    private func iconForFile(_ fileName: String) -> String {
        let ext = (fileName as NSString).pathExtension.lowercased()
        
        switch ext {
        case "jpg", "jpeg", "png", "gif", "bmp", "svg", "heic":
            return "photo"
        case "mp4", "mov", "avi", "mkv", "m4v":
            return "film"
        case "mp3", "wav", "aac", "flac", "m4a":
            return "music.note"
        case "pdf":
            return "doc.text"
        case "zip", "rar", "7z", "tar", "gz":
            return "doc.zipper"
        case "txt", "md", "rtf":
            return "doc.plaintext"
        case "doc", "docx":
            return "doc.richtext"
        case "xls", "xlsx":
            return "tablecells"
        case "ppt", "pptx":
            return "play.rectangle"
        default:
            return "doc"
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// 极简纯净风（Linear/Things）配色，强调色与 App 主色（系统蓝）一致
extension Color {
    static let lsAccent = Color(red: 0.0, green: 0.478, blue: 1.0)   // #007AFF 系统蓝
    static let lsCardBorder = Color.primary.opacity(0.08)
    static let lsDivider = Color.primary.opacity(0.06)
}

// 局域网共享剪贴板视图（Mac 端）：实时监听系统剪贴板，整行卡片列表展示
struct ClipboardShareView: View {
    @ObservedObject var networkManager: NetworkManager
    let onCopySuccess: (String) -> Void
    
    @State private var qrCodeImage: NSImage?
    
    private var clipboardURL: String {
        networkManager.getClipboardURL()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            
            Divider().overlay(Color.lsDivider)
            
            // 左：剪贴板记录列表；右：常驻二维码连接面板
            HStack(alignment: .top, spacing: 18) {
                Group {
                    if networkManager.clipboardItems.isEmpty {
                        emptyState
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(networkManager.clipboardItems.enumerated()), id: \.element.id) { index, item in
                                    ClipboardRowView(
                                        item: item,
                                        onCopy: { copyItem(item) },
                                        onRemove: { networkManager.removeClipboardItem(item) }
                                    )
                                    if index < networkManager.clipboardItems.count - 1 {
                                        Divider().overlay(Color.lsDivider)
                                    }
                                }
                            }
                        }
                        .frame(maxHeight: 240)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                qrColumn
            }
            .padding(.top, 16)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.lsCardBorder, lineWidth: 1)
        )
        .onAppear { generateQRCode() }
        // 端口/IP 就绪或变化时刷新二维码，保证地址实时正确
        .onChange(of: clipboardURL) { _ in generateQRCode() }
    }
    
    // 标题栏
    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.lsAccent)
            
            Text("共享剪贴板")
                .font(.system(size: 15, weight: .semibold))
            
            Text("\(networkManager.clipboardItems.count)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.primary.opacity(0.06)))
            
            Spacer()
            
            iconButton(systemName: "safari") { openClipboardInBrowser() }
                .help("浏览器打开")
            
            if !networkManager.clipboardItems.isEmpty {
                iconButton(systemName: "trash") { networkManager.clearClipboardItems() }
                    .help("清空全部")
            }
        }
        .padding(.bottom, 14)
    }
    
    // 常驻二维码连接面板
    private var qrColumn: some View {
        VStack(spacing: 10) {
            Group {
                if let qrImage = qrCodeImage {
                    Image(nsImage: qrImage)
                        .interpolation(.none)
                        .resizable()
                        .frame(width: 116, height: 116)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.05))
                        .frame(width: 116, height: 116)
                        .overlay(ProgressView())
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.lsCardBorder, lineWidth: 1))
            
            VStack(spacing: 3) {
                HStack(spacing: 5) {
                    Image(systemName: "qrcode")
                        .font(.system(size: 11, weight: .semibold))
                    Text("扫码连接")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.lsAccent)
                
                Text("手机扫码查看/发送")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 140)
        .padding(.vertical, 14)
        .padding(.horizontal, 10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.lsAccent.opacity(0.05)))
    }
    
    // 空态
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 26))
                .foregroundColor(.secondary.opacity(0.5))
            Text("在 Mac 上复制任意文本即可自动出现")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 150)
    }
    
    // 统一的小图标按钮
    private func iconButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(Color.primary.opacity(0.05))
                )
        }
        .buttonStyle(.plain)
    }
    
    // 生成剪贴板地址二维码
    private func generateQRCode() {
        let urlString = clipboardURL
        guard !urlString.isEmpty else { return }
        
        DispatchQueue.global(qos: .userInitiated).async {
            let context = CIContext()
            let filter = CIFilter.qrCodeGenerator()
            filter.message = Data(urlString.utf8)
            filter.correctionLevel = "M"
            
            if let outputImage = filter.outputImage {
                let transform = CGAffineTransform(scaleX: 10, y: 10)
                let scaledImage = outputImage.transformed(by: transform)
                
                if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                    let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: 120, height: 120))
                    DispatchQueue.main.async {
                        self.qrCodeImage = nsImage
                    }
                }
            }
        }
    }
    
    // 把某条剪贴板内容重新写回系统剪贴板
    private func copyItem(_ item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.text, forType: .string)
        onCopySuccess("已复制到系统剪贴板")
    }
    
    private func openClipboardInBrowser() {
        if let url = URL(string: clipboardURL) {
            NSWorkspace.shared.open(url)
        }
    }
}

// 单条剪贴板记录：整行卡片，悬停显示复制/删除
struct ClipboardRowView: View {
    let item: ClipboardItem
    let onCopy: () -> Void
    let onRemove: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(item.text)
                    .font(.system(size: 13))
                    .foregroundColor(.primary)
                    .lineLimit(3)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                
                Text(relativeTime(item.date))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            
            HStack(spacing: 4) {
                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.lsAccent)
                        .frame(width: 26, height: 26)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.lsAccent.opacity(0.1)))
                }
                .buttonStyle(.plain)
                .help("复制到系统剪贴板")
                
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 26, height: 26)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.05)))
                }
                .buttonStyle(.plain)
                .help("删除此条")
            }
            .opacity(isHovered ? 1 : 0.35)
        }
        .padding(.vertical, 11)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
    }
    
    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// 限速设置视图
struct SpeedLimitSettingsView: View {
    @ObservedObject var networkManager: NetworkManager
    @State private var speedInput: String = "1024"
    
    var body: some View {
        HStack(spacing: 15) {
            // 限速开关
            Toggle(isOn: $networkManager.isSpeedLimitEnabled) {
                HStack(spacing: 6) {
                    Image(systemName: networkManager.isSpeedLimitEnabled ? "gauge.high" : "gauge.low")
                        .font(.caption)
                        .foregroundColor(networkManager.isSpeedLimitEnabled ? .orange : .secondary)
                    Text("限速传输")
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            
            Divider()
                .frame(height: 20)
                .opacity(networkManager.isSpeedLimitEnabled ? 1 : 0)
            
            // 速度设置
            HStack(spacing: 8) {
                Text("速度限制:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("", text: $speedInput)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
                    .font(.system(.caption, design: .monospaced))
                    .onSubmit {
                        updateSpeedLimit()
                    }
                    .disabled(!networkManager.isSpeedLimitEnabled)
                
                Text("KB/s")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // 快速设置按钮
                HStack(spacing: 4) {
                    SpeedPresetButton(value: 512, label: "512", networkManager: networkManager, speedInput: $speedInput)
                    SpeedPresetButton(value: 1024, label: "1M", networkManager: networkManager, speedInput: $speedInput)
                    SpeedPresetButton(value: 5120, label: "5M", networkManager: networkManager, speedInput: $speedInput)
                    SpeedPresetButton(value: 10240, label: "10M", networkManager: networkManager, speedInput: $speedInput)
                }
                .disabled(!networkManager.isSpeedLimitEnabled)
            }
            .opacity(networkManager.isSpeedLimitEnabled ? 1 : 0)
            
            // 实时显示当前速度
            HStack(spacing: 6) {
                Image(systemName: "speedometer")
                    .font(.caption2)
                    .foregroundColor(.blue)
                Text("\(formatSpeed(networkManager.speedLimitKBps))")
                    .font(.caption)
                    .foregroundColor(.blue)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(6)
            .opacity(networkManager.isSpeedLimitEnabled ? 1 : 0)
            
            Spacer()
        }
        .frame(height: 40)
        .padding(.horizontal, 25)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .onAppear {
            speedInput = "\(networkManager.speedLimitKBps)"
        }
    }
    
    private func updateSpeedLimit() {
        if let speed = Int(speedInput), speed > 0 {
            networkManager.speedLimitKBps = speed
        } else {
            speedInput = "\(networkManager.speedLimitKBps)"
        }
    }
    
    private func formatSpeed(_ kbps: Int) -> String {
        if kbps >= 1024 {
            let mbps = Double(kbps) / 1024.0
            return String(format: "%.1f MB/s", mbps)
        } else {
            return "\(kbps) KB/s"
        }
    }
}

// 速度预设按钮
struct SpeedPresetButton: View {
    let value: Int
    let label: String
    @ObservedObject var networkManager: NetworkManager
    @Binding var speedInput: String
    
    var body: some View {
        Button(label) {
            networkManager.speedLimitKBps = value
            speedInput = "\(value)"
        }
        .buttonStyle(.bordered)
        .controlSize(.mini)
        .font(.caption2)
    }
}

// 二维码弹窗视图
struct QRCodePopoverView: View {
    let qrCodeImage: NSImage?
    let shareURL: String
    let onCopy: () -> Void
    
    var body: some View {
        VStack(spacing: 15) {
            // 二维码
            if let qrImage = qrCodeImage {
                Image(nsImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 180, height: 180)
                    .background(Color.white)
                    .cornerRadius(8)
                    .shadow(color: .black.opacity(0.1), radius: 3)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 180, height: 180)
                    .overlay(
                        ProgressView()
                    )
            }
            
            Text("扫码下载")
                .font(.headline)
            
            Divider()
            
            // 分享链接
            VStack(spacing: 8) {
                Text("分享链接")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(shareURL)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .textSelection(.enabled)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(6)
                
                Button(action: onCopy) {
                    HStack(spacing: 5) {
                        Image(systemName: "doc.on.doc")
                        Text("复制链接")
                    }
                    .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            HStack(spacing: 6) {
                Image(systemName: "info.circle")
                    .font(.caption2)
                    .foregroundColor(.blue)
                Text("确保设备在同一局域网")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .frame(width: 260)
    }
}
