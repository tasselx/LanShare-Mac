import Foundation

struct SharedFile: Identifiable, Hashable {
    let id: String
    let name: String
    let url: URL
    let size: Int64
    let shareDate: Date
    
    var sizeString: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: SharedFile, rhs: SharedFile) -> Bool {
        lhs.id == rhs.id
    }
}

// 局域网共享剪贴板条目（一条被复制/发送的文本）
struct ClipboardItem: Identifiable, Hashable {
    let id: String
    let text: String
    let date: Date
    
    init(text: String, date: Date = Date()) {
        self.id = UUID().uuidString
        self.text = text
        self.date = date
    }
}
