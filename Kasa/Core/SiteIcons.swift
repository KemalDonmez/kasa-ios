import Foundation
import UIKit

/// Site simgelerini indirir ve cihazda saklar. Simgeler bir kez indirilir,
/// sonra internet olmadan gösterilir. Şifre veya kullanıcı bilgisi asla gönderilmez;
/// yalnızca sitenin simge dosyası istenir.
final class SiteIconStore: @unchecked Sendable {
    static let shared = SiteIconStore()

    private let memory = NSCache<NSString, UIImage>()
    private let lock = NSLock()
    private var misses: [String: Double] = [:]
    private var inflight: [String: Task<UIImage?, Never>] = [:]
    private let dir: URL
    private let missesURL: URL
    private let session: URLSession

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        dir = base.appendingPathComponent("SiteIcons", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        missesURL = dir.appendingPathComponent("_misses.json")
        if let data = try? Data(contentsOf: missesURL), let m = try? JSONDecoder().decode([String: Double].self, from: data) {
            misses = m
        }
        memory.countLimit = 400
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 6
        config.timeoutIntervalForResource = 10
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        config.urlCache = nil
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1",
            "Accept": "image/png,image/*;q=0.9,*/*;q=0.5",
        ]
        session = URLSession(configuration: config)
    }

    private func fileURL(for key: String) -> URL {
        let safe = key.replacingOccurrences(of: "[^a-zA-Z0-9.-]", with: "_", options: .regularExpression)
        return dir.appendingPathComponent(safe + ".png")
    }

    /// Bellekte veya diskte varsa hemen döndürür (ağa çıkmaz)
    func cached(key: String) -> UIImage? {
        if let img = memory.object(forKey: key as NSString) { return img }
        if let data = try? Data(contentsOf: fileURL(for: key)), let img = UIImage(data: data) {
            memory.setObject(img, forKey: key as NSString)
            return img
        }
        return nil
    }

    func cachedImage(for e: Entry) -> UIImage? {
        guard let key = IconDomain.cacheKey(for: e) else { return nil }
        return cached(key: key)
    }

    /// Gerekirse indirir
    func image(for e: Entry) async -> UIImage? {
        guard UserDefaults.standard.bool(forKey: Prefs.siteIcons), let key = IconDomain.cacheKey(for: e) else { return nil }
        if let img = cached(key: key) { return img }
        let domains: [String]
        if key.hasPrefix("guess:") { domains = IconDomain.guesses(for: e) } else { domains = [key] }
        return await load(key: key, domains: domains)
    }

    /// Kilidi yalnızca eşzamanlı (async olmayan) bağlamda kullanır
    private func sync<T>(_ body: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    private func recentlyMissed(_ key: String) -> Bool {
        sync {
            guard let t = misses[key] else { return false }
            return Date().timeIntervalSince1970 - t < 3 * 86400
        }
    }

    private func load(key: String, domains: [String]) async -> UIImage? {
        if recentlyMissed(key) { return nil }
        let task: Task<UIImage?, Never> = sync {
            if let existing = inflight[key] { return existing }
            let t = Task<UIImage?, Never>.detached(priority: .utility) { [weak self] in
                guard let self else { return nil }
                for d in domains {
                    if let img = await self.fetch(domain: d) { return img }
                }
                return nil
            }
            inflight[key] = t
            return t
        }

        let result = await task.value
        let snapshot: [String: Double] = sync {
            inflight[key] = nil
            if result == nil { misses[key] = Date().timeIntervalSince1970 }
            return misses
        }

        if let img = result, let png = img.pngData() {
            memory.setObject(img, forKey: key as NSString)
            try? png.write(to: fileURL(for: key), options: .atomic)
        } else if result == nil, let data = try? JSONEncoder().encode(snapshot) {
            try? data.write(to: missesURL, options: .atomic)
        }
        return result
    }

    private func fetch(domain: String) async -> UIImage? {
        let d = domain.lowercased()
        var candidates: [String] = ["https://\(d)/apple-touch-icon.png"]
        if !d.hasPrefix("www."), d.split(separator: ".").count == 2 || d.hasSuffix(".com.tr") {
            candidates.append("https://www.\(d)/apple-touch-icon.png")
        }
        candidates.append("https://icons.duckduckgo.com/ip3/\(d).ico")
        candidates.append("https://\(d)/favicon.ico")
        for c in candidates {
            guard let url = URL(string: c) else { continue }
            do {
                let (data, response) = try await session.data(from: url)
                guard let http = response as? HTTPURLResponse, http.statusCode == 200, data.count > 100,
                      let img = UIImage(data: data), img.size.width >= 16 else { continue }
                return Self.normalize(img)
            } catch {
                if Task.isCancelled { return nil }
                continue
            }
        }
        return nil
    }

    /// Simgeyi 96x96 boyutuna getirir
    private static func normalize(_ img: UIImage) -> UIImage {
        let side: CGFloat = 96
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format).image { _ in
            let w = img.size.width, h = img.size.height
            let scale = min(side / w, side / h)
            let size = CGSize(width: w * scale, height: h * scale)
            img.draw(in: CGRect(x: (side - size.width) / 2, y: (side - size.height) / 2, width: size.width, height: size.height))
        }
    }

    func clearAll() {
        sync { misses.removeAll() }
        memory.removeAllObjects()
        if let files = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) {
            for f in files { try? FileManager.default.removeItem(at: f) }
        }
    }
}
