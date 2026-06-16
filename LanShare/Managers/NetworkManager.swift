import Foundation
import Network
import Combine
import CommonCrypto
import AppKit

class NetworkManager: ObservableObject {
    @Published var isServerRunning = false
    @Published var localIPAddress: String = ""
    @Published var sharedFiles: [SharedFile] = []
    @Published private(set) var port: UInt16?
    @Published var isSpeedLimitEnabled = false
    @Published var speedLimitKBps: Int = 1024 // KB/s
    // 局域网共享剪贴板条目列表（最新的在最前；来自 Mac 系统剪贴板或网页发送）
    @Published var clipboardItems: [ClipboardItem] = []

    private var listener: NWListener?
    private var activeConnections: [NWConnection] = []
    // 剪贴板监听：定时轮询 NSPasteboard 的 changeCount
    private var pasteboardTimer: Timer?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount
    private let maxClipboardItems = 50 // 最多保留的剪贴板条目数

    // 两个分享网页共用的设计系统样式（极简纯净 Linear/Things 风 + 深色模式自适应）
    private static let sharedPageStyle = """
        <style>
            :root {
                --bg: #fbfbfc;
                --surface: #ffffff; --surface-2: #f5f5f7;
                --text: #16161a; --text-2: #6b6b76;
                --border: #ececef; --border-strong: #e0e0e4;
                --accent: #007aff; --accent-strong: #0062cc; --accent-soft: #e6f0ff;
                --shadow-sm: 0 1px 2px rgba(20,20,30,0.04), 0 2px 6px rgba(20,20,30,0.05);
                --radius-md: 10px; --radius-lg: 14px;
            }
            @media (prefers-color-scheme: dark) {
                :root {
                    --bg: #0b0c0e;
                    --surface: #16171a; --surface-2: #1e1f23;
                    --text: #f2f2f5; --text-2: #9a9aa5;
                    --border: #26272c; --border-strong: #303137;
                    --accent: #0a84ff; --accent-strong: #409cff; --accent-soft: rgba(10,132,255,0.16);
                    --shadow-sm: 0 1px 2px rgba(0,0,0,0.3), 0 2px 8px rgba(0,0,0,0.35);
                }
            }
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body {
                font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Text', 'Segoe UI', sans-serif;
                color: var(--text); background: var(--bg); padding: 24px 18px 64px; min-height: 100vh;
                -webkit-font-smoothing: antialiased; font-size: 14px;
            }
            .container { max-width: 680px; margin: 0 auto; }
            .hero { display: flex; align-items: center; justify-content: space-between; gap: 14px; margin-bottom: 24px; flex-wrap: wrap; }
            .brand { display: flex; align-items: center; gap: 11px; }
            .brand-badge {
                width: 38px; height: 38px; border-radius: 10px; font-size: 18px;
                display: flex; align-items: center; justify-content: center;
                background: var(--accent-soft); color: var(--accent);
            }
            .brand-title { font-size: 18px; font-weight: 600; letter-spacing: -0.3px; }
            .brand-sub { font-size: 12px; color: var(--text-2); margin-top: 1px; }
            .back { text-decoration: none; color: var(--text-2); font-size: 13px; font-weight: 500; transition: color .15s ease; }
            .back:hover { color: var(--accent); }
            .card {
                background: var(--surface); border: 1px solid var(--border); border-radius: var(--radius-lg);
                padding: 20px; box-shadow: var(--shadow-sm); margin-bottom: 16px;
            }
            .card-title { font-size: 13px; font-weight: 600; color: var(--text-2); margin-bottom: 14px; display: flex; align-items: center; gap: 8px; text-transform: none; letter-spacing: 0.1px; }
            .btn {
                display: inline-flex; align-items: center; justify-content: center; gap: 6px;
                padding: 8px 15px; border-radius: 8px; text-decoration: none; font-size: 13px; font-weight: 600;
                border: 1px solid transparent; cursor: pointer; transition: background .15s ease, border-color .15s ease, color .15s ease;
            }
            .btn-primary { background: var(--accent); color: #fff; }
            .btn-primary:hover { background: var(--accent-strong); }
            .btn-secondary { background: var(--surface); color: var(--text); border-color: var(--border-strong); }
            .btn-secondary:hover { background: var(--surface-2); }
            .hint { font-size: 12px; color: var(--text-2); margin-top: 12px; line-height: 1.6; }
            .empty { text-align: center; padding: 40px 20px; color: var(--text-2); font-size: 14px; line-height: 2; }
            textarea {
                width: 100%; min-height: 110px; border: 1px solid var(--border-strong); border-radius: var(--radius-md);
                padding: 12px 14px; font-size: 14px; font-family: inherit; resize: vertical; outline: none;
                background: var(--surface); color: var(--text); transition: border-color .15s ease, box-shadow .15s ease; line-height: 1.5;
            }
            textarea::placeholder { color: var(--text-2); }
            textarea:focus { border-color: var(--accent); box-shadow: 0 0 0 3px var(--accent-soft); }
            .toast {
                position: fixed; left: 50%; bottom: 28px; transform: translateX(-50%) translateY(16px);
                background: var(--text); color: var(--bg); padding: 11px 20px; border-radius: 10px;
                box-shadow: 0 6px 20px rgba(0,0,0,0.18); display: flex; align-items: center; gap: 8px;
                font-size: 13px; font-weight: 500; opacity: 0; pointer-events: none; transition: opacity .2s ease, transform .2s ease; z-index: 9999;
            }
            .toast.show { opacity: 1; transform: translateX(-50%) translateY(0); }
            @media (max-width: 520px) {
                .file-actions, .actions { width: 100%; }
                .file-header { align-items: flex-start; }
            }
        </style>
        """

    init() {
        getLocalIPAddress()
        startServices()
    }

    func startServices() {
        startHTTPServer()
        startClipboardMonitoring()
    }

    // 获取本机 IP 地址
    private func getLocalIPAddress() {
        var address: String = ""
        var ifaddr: UnsafeMutablePointer<ifaddrs>?

        if getifaddrs(&ifaddr) == 0 {
            var ptr = ifaddr
            while ptr != nil {
                defer { ptr = ptr?.pointee.ifa_next }

                guard let interface = ptr?.pointee else { continue }
                let addrFamily = interface.ifa_addr.pointee.sa_family

                if addrFamily == UInt8(AF_INET) {
                    let name = String(cString: interface.ifa_name)
                    if name == "en0" || name == "en1" {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        getnameinfo(interface.ifa_addr, socklen_t(interface.ifa_addr.pointee.sa_len),
                                    &hostname, socklen_t(hostname.count),
                                    nil, socklen_t(0), NI_NUMERICHOST)
                        address = String(cString: hostname)
                        break
                    }
                }
            }
            freeifaddrs(ifaddr)
        }

        DispatchQueue.main.async {
            self.localIPAddress = address.isEmpty ? "未获取到IP" : address
        }
    }

    // 启动 HTTP 服务器
    func startHTTPServer() {
        guard listener == nil else { return }

        do {
            let parameters = NWParameters.tcp
            let listener = try NWListener(using: parameters)

            listener.newConnectionHandler = { [weak self] connection in
                self?.handleHTTPConnection(connection)
            }

            listener.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    DispatchQueue.main.async {
                        if let assignedPort = listener.port?.rawValue {
                            self?.port = assignedPort
                        }
                        self?.isServerRunning = true
                    }
                    let assignedPort = listener.port?.rawValue ?? 0
                    print("HTTP 服务器已启动，端口: \(assignedPort)")
                case .failed(let error):
                    print("服务器启动失败: \(error)")
                    DispatchQueue.main.async {
                        self?.isServerRunning = false
                        self?.port = nil
                    }
                default:
                    break
                }
            }

            listener.start(queue: .global())
            self.listener = listener

        } catch {
            print("无法创建监听器: \(error)")
        }
    }

    // 处理 HTTP 连接
    private func handleHTTPConnection(_ connection: NWConnection) {
        activeConnections.append(connection)
        connection.start(queue: .global())

        receiveHTTPRequest(connection)
    }

    private func receiveHTTPRequest(_ connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self = self, let data = data, !data.isEmpty else {
                connection.cancel()
                return
            }

            if let request = String(data: data, encoding: .utf8) {
                self.handleHTTPRequest(request, connection: connection)
            }

            if !isComplete {
                self.receiveHTTPRequest(connection)
            }
        }
    }

    private func handleHTTPRequest(_ request: String, connection: NWConnection) {
        let lines = request.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else {
            sendHTTPResponse(connection: connection, statusCode: 400, body: "Bad Request")
            return
        }

        let components = requestLine.components(separatedBy: " ")
        guard components.count >= 2 else {
            sendHTTPResponse(connection: connection, statusCode: 400, body: "Bad Request")
            return
        }

        let method = components[0]
        let path = components[1]

        // 剪贴板相关路由（局域网共享剪贴板）
        switch path {
        case "/clipboard":
            // 返回剪贴板共享网页
            sendClipboardPage(connection: connection)
            return
        case "/clipboard/get":
            // 返回剪贴板条目列表 JSON（供网页轮询）
            sendHTTPResponse(connection: connection, statusCode: 200,
                             contentType: "application/json; charset=utf-8",
                             body: clipboardItemsJSON())
            return
        case "/clipboard/set" where method == "POST":
            // 浏览器把文本发回 Mac：写入系统剪贴板，由监听器统一收录为新条目
            let body = extractRequestBody(from: request)
            writeToSystemPasteboard(body)
            sendHTTPResponse(connection: connection, statusCode: 200,
                             contentType: "text/plain; charset=utf-8",
                             body: "OK")
            return
        default:
            break
        }

        if path == "/" {
            // 返回文件列表页面
            sendFileListPage(connection: connection)
        } else {
            // 下载文件 - 从路径提取文件ID（格式：/{fileId}.{ext} 或 /{fileId}）
            let pathWithoutSlash = String(path.dropFirst())
            // 移除文件后缀，获取文件ID
            let fileId = (pathWithoutSlash as NSString).deletingPathExtension
            downloadFile(fileId: fileId, connection: connection)
        }
    }

    // 从完整 HTTP 请求文本中提取请求体（以空行 \r\n\r\n 分隔头与体）
    private func extractRequestBody(from request: String) -> String {
        guard let range = request.range(of: "\r\n\r\n") else { return "" }
        return String(request[range.upperBound...])
    }

    private func sendFileListPage(connection: NWConnection) {
        guard let port = port else {
            sendHTTPResponse(connection: connection, statusCode: 503, body: "Server not ready")
            return
        }

        let baseURL = "http://\(localIPAddress):\(port)"

        var html = """
        <!DOCTYPE html>
        <html lang="zh-CN">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>LanShare</title>
            <script src="https://cdn.jsdelivr.net/npm/qrcodejs@1.0.0/qrcode.min.js"></script>
            \(Self.sharedPageStyle)
            <style>
                .files { display: flex; flex-direction: column; }
                .file-item { padding: 14px 0; border-bottom: 1px solid var(--border); }
                .file-item:first-child { padding-top: 0; }
                .file-item:last-child { border-bottom: none; padding-bottom: 0; }
                .file-header { display: flex; justify-content: space-between; align-items: center; gap: 14px; flex-wrap: wrap; }
                .file-info { flex: 1; min-width: 0; display: flex; align-items: center; gap: 12px; }
                .file-icon { width: 36px; height: 36px; border-radius: 9px; background: var(--surface-2); display: flex; align-items: center; justify-content: center; font-size: 17px; flex-shrink: 0; }
                .file-meta { min-width: 0; }
                .file-name { font-size: 14px; font-weight: 600; color: var(--text); margin-bottom: 2px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
                .file-size { font-size: 12px; color: var(--text-2); }
                .file-actions { display: flex; gap: 6px; flex-wrap: wrap; }
                .file-details { margin-top: 14px; padding: 16px; border-radius: var(--radius-md); background: var(--surface-2); display: none; }
                .file-details.show { display: block; animation: fadeIn .2s ease; }
                .qr-container { display: flex; gap: 16px; align-items: flex-start; flex-wrap: wrap; }
                .qr-code { background: #fff; padding: 10px; border-radius: 10px; line-height: 0; }
                .link-container { flex: 1; min-width: 220px; }
                .link-box { background: var(--surface); border: 1px solid var(--border-strong); padding: 11px 13px; border-radius: 8px; margin-bottom: 10px; word-break: break-all; font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 12px; color: var(--text); }
                .copy-btn { width: 100%; }
                @keyframes fadeIn { from { opacity: 0; transform: translateY(-3px); } to { opacity: 1; transform: translateY(0); } }
            </style>
        </head>
        <body>
            <div class="container">
                <header class="hero">
                    <div class="brand">
                        <div class="brand-badge">📡</div>
                        <div>
                            <div class="brand-title">LanShare</div>
                            <div class="brand-sub">局域网文件分享</div>
                        </div>
                    </div>
                    <a href="/clipboard" class="btn btn-primary">📋 共享剪贴板</a>
                </header>
                <section class="card">
                    <div class="card-title"><span>📁 共享文件</span></div>
                    <div class="files">
        """

        if sharedFiles.isEmpty {
            html += "<div class='empty'>📭<br>暂无共享文件</div>"
        } else {
            for file in sharedFiles {
                let fileExtension = (file.name as NSString).pathExtension
                let shortLink = fileExtension.isEmpty ? file.id : "\(file.id).\(fileExtension)"
                let fullURL = "\(baseURL)/\(shortLink)"

                html += """
                    <div class="file-item">
                        <div class="file-header">
                            <div class="file-info">
                                <div class="file-icon">📄</div>
                                <div class="file-meta">
                                    <div class="file-name">\(file.name)</div>
                                    <div class="file-size">\(formatFileSize(file.size))</div>
                                </div>
                            </div>
                            <div class="file-actions">
                                <button class="btn btn-secondary" onclick="toggleDetails('\(file.id)')">
                                    <span id="icon-\(file.id)">📱</span> 二维码
                                </button>
                                <button class="btn btn-secondary" onclick="copyLink('\(fullURL)')">
                                    📋 复制链接
                                </button>
                                <a href="/\(shortLink)" class="btn btn-primary">⬇️ 下载</a>
                            </div>
                        </div>
                        <div id="details-\(file.id)" class="file-details">
                            <div class="qr-container">
                                <div class="qr-code" id="qr-\(file.id)"></div>
                                <div class="link-container">
                                    <div class="link-box">\(fullURL)</div>
                                    <button class="btn btn-secondary copy-btn" onclick="copyLink('\(fullURL)')">复制链接</button>
                                    <p class="hint">💡 扫描二维码或复制链接分享给其他设备</p>
                                </div>
                            </div>
                        </div>
                    </div>
                """
            }
        }

        html += """
                    </div>
                </section>
            </div>
            <div id="toast" class="toast">
                <svg width="20" height="20" viewBox="0 0 20 20" fill="none" xmlns="http://www.w3.org/2000/svg">
                    <circle cx="10" cy="10" r="9" fill="white" fill-opacity="0.2"/>
                    <path d="M6 10L9 13L14 7" stroke="white" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"/>
                </svg>
                <span>链接已复制</span>
            </div>
            <script>
                const qrCodes = {};

                function toggleDetails(fileId) {
                    const details = document.getElementById('details-' + fileId);
                    const icon = document.getElementById('icon-' + fileId);
                    const isShowing = details.classList.contains('show');

                    if (isShowing) {
                        details.classList.remove('show');
                        icon.textContent = '📱';
                    } else {
                        details.classList.add('show');
                        icon.textContent = '✕';

                        // 生成二维码（如果还没生成）
                        if (!qrCodes[fileId]) {
                            const qrContainer = document.getElementById('qr-' + fileId);
                            const url = qrContainer.parentElement.parentElement.querySelector('.link-box').textContent;
                            new QRCode(qrContainer, {
                                text: url,
                                width: 150,
                                height: 150,
                                colorDark: '#000000',
                                colorLight: '#ffffff',
                                correctLevel: QRCode.CorrectLevel.M
                            });
                            qrCodes[fileId] = true;
                        }
                    }
                }

                function copyLink(url) {
                    navigator.clipboard.writeText(url).then(() => {
                        const toast = document.getElementById('toast');
                        toast.classList.add('show');
                        setTimeout(() => {
                            toast.classList.remove('show');
                        }, 2000);
                    }).catch(err => {
                        // 降级方案
                        const textarea = document.createElement('textarea');
                        textarea.value = url;
                        document.body.appendChild(textarea);
                        textarea.select();
                        document.execCommand('copy');
                        document.body.removeChild(textarea);

                        const toast = document.getElementById('toast');
                        toast.classList.add('show');
                        setTimeout(() => {
                            toast.classList.remove('show');
                        }, 2000);
                    });
                }
            </script>
        </body>
        </html>
        """

        sendHTTPResponse(connection: connection, statusCode: 200, contentType: "text/html; charset=utf-8", body: html)
    }

    private func downloadFile(fileId: String, connection: NWConnection) {
        guard let file = sharedFiles.first(where: { $0.id == fileId }) else {
            sendHTTPResponse(connection: connection, statusCode: 404, body: "File not found")
            return
        }

        do {
            let fileData = try Data(contentsOf: file.url)
            let fileName = file.name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? file.name

            var response = "HTTP/1.1 200 OK\r\n"
            response += "Content-Type: application/octet-stream\r\n"
            response += "Content-Disposition: attachment; filename=\"\(fileName)\"\r\n"
            response += "Content-Length: \(fileData.count)\r\n"
            response += "Connection: close\r\n"
            response += "\r\n"

            if let headerData = response.data(using: .utf8) {
                if isSpeedLimitEnabled {
                    // 限速传输：分块发送
                    sendFileWithSpeedLimit(headerData: headerData, fileData: fileData, connection: connection)
                } else {
                    // 不限速：一次性发送
                    var fullData = Data()
                    fullData.append(headerData)
                    fullData.append(fileData)

                    connection.send(content: fullData, completion: .contentProcessed { _ in
                        connection.cancel()
                    })
                }
            }
        } catch {
            sendHTTPResponse(connection: connection, statusCode: 500, body: "Error reading file")
        }
    }

    private func sendFileWithSpeedLimit(headerData: Data, fileData: Data, connection: NWConnection) {
        let chunkSize = speedLimitKBps * 1024 // 字节数
        let delayBetweenChunks = 1.0 // 秒

        // 先发送HTTP头
        connection.send(content: headerData, completion: .contentProcessed { [weak self] error in
            guard error == nil else {
                connection.cancel()
                return
            }

            // 然后分块发送文件数据
            self?.sendChunks(data: fileData, chunkSize: chunkSize, delay: delayBetweenChunks, connection: connection, offset: 0)
        })
    }

    private func sendChunks(data: Data, chunkSize: Int, delay: TimeInterval, connection: NWConnection, offset: Int) {
        guard offset < data.count else {
            // 所有数据发送完成
            connection.cancel()
            return
        }

        let remainingBytes = data.count - offset
        let currentChunkSize = min(chunkSize, remainingBytes)
        let chunk = data.subdata(in: offset..<(offset + currentChunkSize))

        connection.send(content: chunk, completion: .contentProcessed { [weak self] error in
            guard error == nil else {
                connection.cancel()
                return
            }

            let newOffset = offset + currentChunkSize
            if newOffset < data.count {
                // 延迟后继续发送下一块
                DispatchQueue.global().asyncAfter(deadline: .now() + delay) {
                    self?.sendChunks(data: data, chunkSize: chunkSize, delay: delay, connection: connection, offset: newOffset)
                }
            } else {
                // 发送完成
                connection.cancel()
            }
        })
    }

    private func sendHTTPResponse(connection: NWConnection, statusCode: Int, contentType: String = "text/plain", body: String) {
        let statusText = statusCode == 200 ? "OK" : statusCode == 404 ? "Not Found" : "Error"
        var response = "HTTP/1.1 \(statusCode) \(statusText)\r\n"
        response += "Content-Type: \(contentType)\r\n"
        response += "Content-Length: \(body.utf8.count)\r\n"
        response += "Connection: close\r\n"
        response += "\r\n"
        response += body

        if let data = response.data(using: .utf8) {
            connection.send(content: data, completion: .contentProcessed { _ in
                connection.cancel()
            })
        }
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    // 添加共享文件
    func shareFile(url: URL) -> SharedFile {
        let fileName = url.lastPathComponent
        // 使用文件路径的 MD5 作为短链接 ID
        let fileId = generateMD5(from: url.path + Date().timeIntervalSince1970.description)

        var fileSize: Int64 = 0
        if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attributes[.size] as? Int64 {
            fileSize = size
        }

        let sharedFile = SharedFile(
            id: fileId,
            name: fileName,
            url: url,
            size: fileSize,
            shareDate: Date()
        )

        DispatchQueue.main.async {
            self.sharedFiles.append(sharedFile)
        }

        return sharedFile
    }

    // 生成 MD5 短链接
    private func generateMD5(from string: String) -> String {
        guard let data = string.data(using: .utf8) else { return UUID().uuidString }

        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_MD5(buffer.baseAddress, CC_LONG(buffer.count), &digest)
        }

        // 取前8位作为短链接
        return digest.prefix(4).map { String(format: "%02x", $0) }.joined()
    }

    // 移除共享文件
    func removeSharedFile(_ file: SharedFile) {
        DispatchQueue.main.async {
            self.sharedFiles.removeAll { $0.id == file.id }
        }
    }

    // 生成分享链接（MD5短链 + 文件后缀）
    func getShareURL(for file: SharedFile) -> String {
        let fileExtension = (file.name as NSString).pathExtension
        let shortLink = fileExtension.isEmpty ? file.id : "\(file.id).\(fileExtension)"
        guard let port = port else { return "" }
        return "http://\(localIPAddress):\(port)/\(shortLink)"
    }

    // 生成文件列表链接
    func getFileListURL() -> String {
        guard let port = port else { return "" }
        return "http://\(localIPAddress):\(port)/"
    }

    // MARK: - 局域网共享剪贴板

    // 生成剪贴板网页链接
    func getClipboardURL() -> String {
        guard let port = port else { return "" }
        return "http://\(localIPAddress):\(port)/clipboard"
    }

    // 启动剪贴板监听：定时轮询系统剪贴板，内容变化时自动收录为新条目
    private func startClipboardMonitoring() {
        guard pasteboardTimer == nil else { return }

        let timer = Timer(timeInterval: 0.8, repeats: true) { [weak self] _ in
            self?.checkPasteboardChange()
        }
        RunLoop.main.add(timer, forMode: .common)
        pasteboardTimer = timer
    }

    private func checkPasteboardChange() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        guard let text = pasteboard.string(forType: .string), !text.isEmpty else { return }
        // 与最新条目相同则跳过，避免重复
        if clipboardItems.first?.text == text { return }

        let item = ClipboardItem(text: text)
        DispatchQueue.main.async {
            self.clipboardItems.insert(item, at: 0)
            if self.clipboardItems.count > self.maxClipboardItems {
                self.clipboardItems.removeLast(self.clipboardItems.count - self.maxClipboardItems)
            }
        }
    }

    // 写入 Mac 系统剪贴板（监听器会自动收录为新条目）
    func writeToSystemPasteboard(_ text: String) {
        guard !text.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    // 删除指定剪贴板条目
    func removeClipboardItem(_ item: ClipboardItem) {
        DispatchQueue.main.async {
            self.clipboardItems.removeAll { $0.id == item.id }
        }
    }

    // 清空全部剪贴板条目
    func clearClipboardItems() {
        DispatchQueue.main.async {
            self.clipboardItems.removeAll()
        }
    }

    // 把剪贴板条目列表序列化为 JSON（供网页轮询渲染）
    private func clipboardItemsJSON() -> String {
        let formatter = ISO8601DateFormatter()
        let array: [[String: Any]] = clipboardItems.map { item in
            ["id": item.id, "text": item.text, "date": formatter.string(from: item.date)]
        }
        if let data = try? JSONSerialization.data(withJSONObject: array, options: []),
           let json = String(data: data, encoding: .utf8) {
            return json
        }
        return "[]"
    }

    // 生成剪贴板共享网页：发送文本到 Mac + 实时展示剪贴板条目列表（各自一键复制）
    private func sendClipboardPage(connection: NWConnection) {
        let html = """
        <!DOCTYPE html>
        <html lang="zh-CN">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>LanShare 剪贴板</title>
            \(Self.sharedPageStyle)
            <style>
                .actions { display: flex; gap: 8px; margin-top: 14px; flex-wrap: wrap; }
                .dot { width: 7px; height: 7px; border-radius: 50%; background: #30c060; }
                .item { padding: 14px 0; border-bottom: 1px solid var(--border); }
                .item:first-child { padding-top: 0; }
                .item:last-child { border-bottom: none; padding-bottom: 0; }
                .item-text { font-size: 14px; line-height: 1.55; white-space: pre-wrap; word-break: break-word; max-height: 140px; overflow: auto; margin-bottom: 10px; color: var(--text); }
                .item-foot { display: flex; align-items: center; justify-content: space-between; gap: 10px; }
                .item-date { font-size: 12px; color: var(--text-2); font-variant-numeric: tabular-nums; }
                .copy-btn { padding: 6px 14px; border-radius: 8px; border: 1px solid var(--border-strong); background: var(--surface); color: var(--text); cursor: pointer; font-size: 13px; font-weight: 600; transition: background .15s ease, border-color .15s ease, color .15s ease; }
                .copy-btn:hover { background: var(--accent-soft); border-color: var(--accent); color: var(--accent); }
            </style>
        </head>
        <body>
            <div class="container">
                <header class="hero">
                    <div class="brand">
                        <div class="brand-badge">📋</div>
                        <div>
                            <div class="brand-title">共享剪贴板</div>
                            <div class="brand-sub">局域网实时同步</div>
                        </div>
                    </div>
                    <a class="back" href="/">← 返回文件</a>
                </header>

                <section class="card">
                    <div class="card-title">⬆️ 发送文本到 Mac</div>
                    <textarea id="outgoing" placeholder="在此输入要发送到 Mac 的文本…"></textarea>
                    <div class="actions">
                        <button class="btn btn-primary" onclick="sendText()">发送到电脑</button>
                        <button class="btn btn-secondary" onclick="document.getElementById('outgoing').value=''">清空</button>
                    </div>
                    <div class="hint">💡 发送后会写入 Mac 的系统剪贴板，并出现在下方列表</div>
                </section>

                <section class="card">
                    <div class="card-title"><span class="dot"></span> 剪贴板记录（实时同步）</div>
                    <div id="list"><div class="empty">加载中…</div></div>
                </section>
            </div>

            <div id="toast" class="toast">操作成功</div>

            <script>
                let lastSignature = '';

                function showToast(msg) {
                    const t = document.getElementById('toast');
                    t.textContent = msg;
                    t.classList.add('show');
                    setTimeout(() => t.classList.remove('show'), 1800);
                }

                function copyText(text) {
                    navigator.clipboard.writeText(text).then(() => showToast('已复制')).catch(() => {
                        const ta = document.createElement('textarea');
                        ta.value = text;
                        document.body.appendChild(ta);
                        ta.select();
                        document.execCommand('copy');
                        document.body.removeChild(ta);
                        showToast('已复制');
                    });
                }

                function sendText() {
                    const text = document.getElementById('outgoing').value;
                    if (!text) { showToast('请输入内容'); return; }
                    fetch('/clipboard/set', { method: 'POST', body: text })
                        .then(() => { showToast('已发送到 Mac'); document.getElementById('outgoing').value=''; poll(); })
                        .catch(() => showToast('发送失败'));
                }

                function fmtDate(iso) {
                    const d = new Date(iso);
                    if (isNaN(d)) return '';
                    const p = n => (n < 10 ? '0' + n : n);
                    return d.getFullYear() + '-' + p(d.getMonth()+1) + '-' + p(d.getDate()) + ' ' + p(d.getHours()) + ':' + p(d.getMinutes());
                }

                function render(items) {
                    const list = document.getElementById('list');
                    list.innerHTML = '';
                    if (!items.length) {
                        const e = document.createElement('div');
                        e.className = 'empty';
                        e.textContent = '暂无记录，在 Mac 上复制任意文本即可出现';
                        list.appendChild(e);
                        return;
                    }
                    items.forEach(it => {
                        const item = document.createElement('div');
                        item.className = 'item';

                        const txt = document.createElement('div');
                        txt.className = 'item-text';
                        txt.textContent = it.text;

                        const foot = document.createElement('div');
                        foot.className = 'item-foot';

                        const date = document.createElement('span');
                        date.className = 'item-date';
                        date.textContent = fmtDate(it.date);

                        const btn = document.createElement('button');
                        btn.className = 'copy-btn';
                        btn.textContent = '📋 复制';
                        btn.onclick = () => copyText(it.text);

                        foot.appendChild(date);
                        foot.appendChild(btn);
                        item.appendChild(txt);
                        item.appendChild(foot);
                        list.appendChild(item);
                    });
                }

                async function poll() {
                    try {
                        const res = await fetch('/clipboard/get');
                        const items = await res.json();
                        const sig = JSON.stringify(items.map(i => i.id));
                        if (sig !== lastSignature) {
                            lastSignature = sig;
                            render(items);
                        }
                    } catch (e) {}
                }
                poll();
                setInterval(poll, 1500);
            </script>
        </body>
        </html>
        """

        sendHTTPResponse(connection: connection, statusCode: 200, contentType: "text/html; charset=utf-8", body: html)
    }

    deinit {
        pasteboardTimer?.invalidate()
        listener?.cancel()
        activeConnections.forEach { $0.cancel() }
    }
}
