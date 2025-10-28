import Foundation
import Network
import Combine
import CommonCrypto

class NetworkManager: ObservableObject {
    @Published var isServerRunning = false
    @Published var localIPAddress: String = ""
    @Published var sharedFiles: [SharedFile] = []
    @Published private(set) var port: UInt16?
    
    private var listener: NWListener?
    private var activeConnections: [NWConnection] = []
    
    init() {
        getLocalIPAddress()
        startHTTPServer()
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
        
        let path = components[1]
        
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
    
    private func sendFileListPage(connection: NWConnection) {
        guard let port = port else {
            sendHTTPResponse(connection: connection, statusCode: 503, body: "Server not ready")
            return
        }
        
        let baseURL = "http://\(localIPAddress):\(port)"
        
        var html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>LanShare</title>
            <script src="https://cdn.jsdelivr.net/npm/qrcodejs@1.0.0/qrcode.min.js"></script>
            <style>
                * { margin: 0; padding: 0; box-sizing: border-box; }
                body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #f5f5f7; padding: 20px; }
                .container { max-width: 900px; margin: 0 auto; }
                h1 { color: #1d1d1f; margin-bottom: 30px; text-align: center; }
                .file-list { background: white; border-radius: 12px; padding: 20px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
                .file-item { padding: 15px; border-bottom: 1px solid #e5e5e7; }
                .file-item:last-child { border-bottom: none; }
                .file-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px; }
                .file-info { flex: 1; }
                .file-name { font-size: 16px; font-weight: 500; color: #1d1d1f; margin-bottom: 5px; }
                .file-size { font-size: 14px; color: #86868b; }
                .file-actions { display: flex; gap: 8px; }
                .btn { padding: 8px 16px; border-radius: 8px; text-decoration: none; font-size: 14px; border: none; cursor: pointer; transition: all 0.2s; }
                .btn-primary { background: #007aff; color: white; }
                .btn-primary:hover { background: #0051d5; }
                .btn-secondary { background: #e5e5e7; color: #1d1d1f; }
                .btn-secondary:hover { background: #d1d1d6; }
                .file-details { margin-top: 15px; padding: 15px; background: #f9f9f9; border-radius: 8px; display: none; }
                .file-details.show { display: block; }
                .qr-container { display: flex; gap: 20px; align-items: flex-start; }
                .qr-code { background: white; padding: 10px; border-radius: 8px; box-shadow: 0 2px 5px rgba(0,0,0,0.1); }
                .link-container { flex: 1; }
                .link-box { background: white; padding: 12px; border-radius: 6px; margin-bottom: 10px; word-break: break-all; font-family: monospace; font-size: 13px; }
                .copy-btn { width: 100%; }
                .empty { text-align: center; padding: 40px; color: #86868b; }
                .toast { position: fixed; top: 50%; left: 50%; transform: translate(-50%, -50%); background: rgba(0, 0, 0, 0.85); color: white; padding: 14px 24px; border-radius: 25px; box-shadow: 0 5px 20px rgba(0,0,0,0.3); display: none; animation: toastIn 0.3s; z-index: 9999; }
                .toast.show { display: flex; align-items: center; gap: 8px; }
                @keyframes toastIn { from { opacity: 0; transform: translate(-50%, -50%) scale(0.8); } to { opacity: 1; transform: translate(-50%, -50%) scale(1); } }
            </style>
        </head>
        <body>
            <div class="container">
                <h1>📁 LanShare</h1>
                <div class="file-list">
        """
        
        if sharedFiles.isEmpty {
            html += "<div class='empty'>暂无共享文件</div>"
        } else {
            for file in sharedFiles {
                let fileExtension = (file.name as NSString).pathExtension
                let shortLink = fileExtension.isEmpty ? file.id : "\(file.id).\(fileExtension)"
                let fullURL = "\(baseURL)/\(shortLink)"
                
                html += """
                    <div class="file-item">
                        <div class="file-header">
                            <div class="file-info">
                                <div class="file-name">\(file.name)</div>
                                <div class="file-size">\(formatFileSize(file.size))</div>
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
                                    <p style="margin-top: 10px; font-size: 12px; color: #86868b;">
                                        💡 扫描二维码或复制链接分享给其他设备
                                    </p>
                                </div>
                            </div>
                        </div>
                    </div>
                """
            }
        }
        
        html += """
                </div>
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
                var fullData = Data()
                fullData.append(headerData)
                fullData.append(fileData)
                
                connection.send(content: fullData, completion: .contentProcessed { _ in
                    connection.cancel()
                })
            }
        } catch {
            sendHTTPResponse(connection: connection, statusCode: 500, body: "Error reading file")
        }
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
    
    deinit {
        listener?.cancel()
        activeConnections.forEach { $0.cancel() }
    }
}
