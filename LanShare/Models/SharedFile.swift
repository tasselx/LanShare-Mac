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
