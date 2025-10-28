import SwiftUI
import UniformTypeIdentifiers
import CoreImage.CIFilterBuiltins

struct ContentView: View {
    @EnvironmentObject var networkManager: NetworkManager
    @State private var isDragging = false
    @State private var showFilePicker = false
    @State private var showToast = false
    @State private var toastMessage = ""
    
    var body: some View {
        ZStack {
            VStack(spacing: 0) {
            // 顶部状态栏
            HStack(spacing: 15) {
                Text("LanShare")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Circle()
                    .fill(networkManager.isServerRunning ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                
                Text(networkManager.isServerRunning ? "服务运行中" : "服务未启动")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                if !networkManager.localIPAddress.isEmpty {
                    HStack(spacing: 5) {
                        Image(systemName: "network")
                            .font(.caption)
                        Text(networkManager.localIPAddress)
                            .font(.system(.caption, design: .monospaced))
                    }
                    .foregroundColor(.secondary)
                }
                
                if !networkManager.sharedFiles.isEmpty {
                    Button(action: openFileListInBrowser) {
                        HStack(spacing: 5) {
                            Image(systemName: "safari")
                            Text("在浏览器中打开")
                        }
                        .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, 25)
            .padding(.vertical, 12)
            .background(Color(nsColor: .controlBackgroundColor))
            
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
