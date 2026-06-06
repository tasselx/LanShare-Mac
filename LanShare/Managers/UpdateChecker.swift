import Foundation
import Combine

// 自动检查更新：请求 GitHub Releases 最新版本，与本地版本语义化比较
class UpdateChecker: ObservableObject {
    @Published var hasUpdate = false        // 是否有新版本（用于显示红点）
    @Published var latestVersion: String = ""
    @Published var releaseURL: String = ""
    @Published var isChecking = false

    // GitHub 仓库（owner/repo）
    private let repo = "tasselx/LanShare-Mac"

    // 当前 App 版本（CFBundleShortVersionString）
    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    // 检查更新（静默失败，不打扰用户）
    // 直接请求 releases/latest 页面，GitHub 会 302 跳转到 .../releases/tag/<版本>，
    // 从最终跳转地址取版本号比对，无需 API、无需解析 HTML。
    func checkForUpdate() {
        guard !isChecking,
              let url = URL(string: "https://github.com/\(repo)/releases/latest") else { return }

        isChecking = true
        var request = URLRequest(url: url)
        request.timeoutInterval = 12

        URLSession.shared.dataTask(with: request) { [weak self] _, response, _ in
            guard let self = self else { return }
            defer { DispatchQueue.main.async { self.isChecking = false } }

            // 跟随重定向后的最终地址，如 https://github.com/owner/repo/releases/tag/v1.0.2
            guard let finalURL = (response as? HTTPURLResponse)?.url else { return }

            // 无任何 release 时会落到 .../releases，lastPathComponent 不是版本号，比较结果为 false
            let tag = finalURL.lastPathComponent
            let latest = self.normalize(tag)
            let newer = self.isNewer(latest, than: self.normalize(self.currentVersion))

            DispatchQueue.main.async {
                self.latestVersion = latest
                self.releaseURL = finalURL.absoluteString
                self.hasUpdate = newer
            }
        }.resume()
    }

    // 去掉版本号前缀 v/V 与空白
    private func normalize(_ version: String) -> String {
        var s = version.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("v") || s.hasPrefix("V") { s.removeFirst() }
        return s
    }

    // 语义化比较：a 是否比 b 新（逐段比较 major.minor.patch）
    private func isNewer(_ a: String, than b: String) -> Bool {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0) ?? 0 }
        let count = max(pa.count, pb.count)
        for i in 0..<count {
            let x = i < pa.count ? pa[i] : 0
            let y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
