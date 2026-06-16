import SwiftUI
import UniformTypeIdentifiers
import CoreImage.CIFilterBuiltins

// 主界面 Tab 枚举
enum AppTab: String, CaseIterable {
    case files = "共享文件"
    case clipboard = "共享剪贴板"

    var icon: String {
        switch self {
        case .files: return "doc.fill"
        case .clipboard: return "doc.on.clipboard.fill"
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var networkManager: NetworkManager
    @StateObject private var updateChecker = UpdateChecker()
    @State private var isDragging = false
    @State private var showFilePicker = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var hoveredFileId: String?
    @State private var selectedTab: AppTab = .files

    var body: some View {
        ZStack {
            Color.lsWindowBackground
            .ignoresSafeArea()

            VStack(spacing: 0) {
                headerBar

                VStack(spacing: 12) {
                    tabPicker

                    if selectedTab == .files {
                        SpeedLimitSettingsView(networkManager: networkManager)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, selectedTab == .files ? 10 : 4)

                Group {
                    if selectedTab == .files {
                        filesContent
                    } else {
                        ClipboardShareView(
                            networkManager: networkManager,
                            onCopySuccess: { message in
                                showToastMessage(message)
                            }
                        )
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
        .frame(minWidth: 780, minHeight: 580)
        .onAppear {
            networkManager.startServices()
            updateChecker.checkForUpdate()
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result: result)
        }
    }

    private var headerBar: some View {
        HStack(spacing: 16) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.lsAccent, .lsTeal],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 38, height: 38)
                        .shadow(color: Color.lsAccent.opacity(0.28), radius: 10, x: 0, y: 5)

                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("LanShare")
                        .font(.system(size: 18, weight: .bold, design: .rounded))

                    Text(networkManager.port.map { "端口 \($0)" } ?? "服务准备中")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }

            Spacer(minLength: 16)

            if !networkManager.localIPAddress.isEmpty {
                statusPill(
                    icon: "network",
                    text: networkManager.localIPAddress,
                    tint: .lsAccent,
                    monospaced: true
                )

                statusPill(
                    icon: networkManager.isServerRunning ? "checkmark.circle.fill" : "exclamationmark.circle.fill",
                    text: networkManager.isServerRunning ? "运行中" : "未启动",
                    tint: networkManager.isServerRunning ? .lsSuccess : .red,
                    monospaced: false
                )
            }

            if updateChecker.hasUpdate {
                toolbarButton(title: "更新", icon: "arrow.down.circle", action: openReleasePage)
                    .overlay(alignment: .topTrailing) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .offset(x: 2, y: -2)
                    }
                    .help("发现新版本 \(updateChecker.latestVersion)，点击前往更新")
            }

            if networkManager.isServerRunning {
                toolbarButton(title: "浏览器", icon: "safari", action: openCurrentPageInBrowser)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.thinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.lsDivider)
                .frame(height: 1)
        }
    }

    private var tabPicker: some View {
        HStack(spacing: 6) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .padding(5)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.lsPanelBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.lsCardBorder, lineWidth: 1)
                )
        )
    }

    private var filesContent: some View {
        ScrollView {
            VStack(spacing: 18) {
                dropZone

                if !networkManager.sharedFiles.isEmpty {
                    sharedFilesSection
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
    }

    private var dropZone: some View {
        VStack(spacing: 15) {
            ZStack {
                Circle()
                    .fill(isDragging ? Color.lsAccent.opacity(0.16) : Color.primary.opacity(0.05))
                    .frame(width: 70, height: 70)

                Image(systemName: isDragging ? "arrow.down.doc.fill" : "square.and.arrow.up")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(isDragging ? .lsAccent : .secondary)
            }

            VStack(spacing: 5) {
                Text(isDragging ? "松开以添加文件" : "拖放文件到这里")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))

                Text("生成局域网链接和二维码，手机或电脑都能直接访问")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Button {
                showFilePicker = true
            } label: {
                Label("选择文件", systemImage: "plus")
                    .font(.system(size: 13, weight: .semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 230)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isDragging ? Color.lsAccent.opacity(0.08) : Color.lsCardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(
                            isDragging ? Color.lsAccent : Color.lsCardBorder,
                            style: StrokeStyle(lineWidth: isDragging ? 2 : 1.2, dash: isDragging ? [] : [9, 7])
                        )
                )
                .shadow(color: Color.black.opacity(0.04), radius: 16, x: 0, y: 8)
        )
        .onDrop(of: [.fileURL], isTargeted: $isDragging) { providers in
            handleDrop(providers: providers)
            return true
        }
    }

    private var sharedFilesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("共享中的文件", systemImage: "tray.full")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))

                Spacer()

                Text("\(networkManager.sharedFiles.count) 个")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.primary.opacity(0.06)))
            }

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
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.lsPanelBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.lsCardBorder, lineWidth: 1)
                )
        )
    }

    private func statusPill(icon: String, text: String, tint: Color, monospaced: Bool) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(tint)

            Text(text)
                .font(monospaced ? .system(size: 12, weight: .medium, design: .monospaced) : .system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(Capsule().fill(tint.opacity(0.12)))
    }

    private func toolbarButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let isSelected = selectedTab == tab
        let count = tab == .files ? networkManager.sharedFiles.count : networkManager.clipboardItems.count

        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                selectedTab = tab
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: tab.icon)
                    .font(.system(size: 13, weight: .semibold))

                Text(tab.rawValue)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))

                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(isSelected ? .white : .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(isSelected ? Color.lsAccent : Color.primary.opacity(0.08)))
                }
            }
            .foregroundColor(isSelected ? .primary : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isSelected ? Color.lsCardBackground : Color.clear)
                    .shadow(color: isSelected ? Color.black.opacity(0.08) : .clear, radius: 8, x: 0, y: 3)
            )
        }
        .buttonStyle(.plain)
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

    private func openCurrentPageInBrowser() {
        let urlString = selectedTab == .clipboard ? networkManager.getClipboardURL() : networkManager.getFileListURL()
        if let url = URL(string: urlString) {
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
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.lsAccent.opacity(0.12))
                    .frame(width: 52, height: 52)

                Image(systemName: iconForFile(file.name))
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundColor(.lsAccent)
            }

            // 文件信息
            VStack(alignment: .leading, spacing: 6) {
                Text(file.name)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .lineLimit(1)

                HStack(spacing: 12) {
                    Label(file.sizeString, systemImage: "doc")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)

                    Label(formatDate(file.shareDate), systemImage: "clock")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // 操作按钮
            HStack(spacing: 8) {
                Button(action: copyToClipboard) {
                    Label("复制链接", systemImage: "link")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button(action: {
                    showQRPopover.toggle()
                    if showQRPopover && qrCodeImage == nil {
                        generateQRCode()
                    }
                }) {
                    Image(systemName: "qrcode")
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 24, height: 24)
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
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundColor(.red)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.lsCardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.lsCardBorder, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.035), radius: 10, x: 0, y: 5)
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

extension Color {
    static let lsAccent = Color(red: 0.0, green: 0.478, blue: 1.0)
    static let lsTeal = Color(red: 0.0, green: 0.72, blue: 0.78)
    static let lsSuccess = Color(red: 0.2, green: 0.78, blue: 0.42)
    static let lsWindowBackground = Color(nsColor: .windowBackgroundColor)
    static let lsPanelBackground = Color(nsColor: .controlBackgroundColor).opacity(0.72)
    static let lsCardBackground = Color(nsColor: .controlBackgroundColor)
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
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                qrColumn
            }
            .padding(.top, 16)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.lsPanelBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
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
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.lsAccent)

            Text("共享剪贴板")
                .font(.system(size: 15, weight: .semibold, design: .rounded))

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
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.lsAccent.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.lsCardBorder, lineWidth: 1))
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
                    .font(.system(size: 13, weight: .medium, design: .rounded))
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
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(isHovered ? Color.primary.opacity(0.035) : Color.clear)
        )
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
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
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
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.lsPanelBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.lsCardBorder, lineWidth: 1)
                )
        )
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
