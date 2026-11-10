import Foundation
import SwiftUI
import UIKit
import CryptoKit
import UniformTypeIdentifiers

// MARK: - URL

enum URLHelper {
    static func withScheme(_ raw: String) -> String {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.range(of: "^[a-zA-Z][a-zA-Z0-9+.-]*://", options: .regularExpression) != nil { return s }
        return "https://" + s
    }

    static func host(_ raw: String) -> String {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return "" }
        if let h = URL(string: withScheme(s))?.host {
            return h.hasPrefix("www.") ? String(h.dropFirst(4)) : h
        }
        return s
    }

    static func openable(_ raw: String) -> URL? {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty, let u = URL(string: withScheme(s)),
              let scheme = u.scheme?.lowercased(), scheme == "https" || scheme == "http" else { return nil }
        return u
    }
}

// MARK: - Şifre gücü

struct Strength {
    let score: Int   // 0...4
    let bits: Int

    var label: String { ["Çok zayıf", "Zayıf", "Orta", "Güçlü", "Çok güçlü"][score] }

    var color: Color {
        switch score {
        case 0: return .kasaDanger
        case 1: return Color(hex: 0xFF7A45)
        case 2: return .kasaWarn
        case 3: return Color(hex: 0x7CD352)
        default: return .kasaOK
        }
    }

    var fraction: Double { [0.18, 0.38, 0.6, 0.82, 1.0][score] }

    private static let common = ["password", "parola", "sifre", "şifre", "123456", "12345", "qwerty", "asdf", "abc123",
                                 "admin", "iloveyou", "letmein", "111111", "000000", "welcome", "monkey", "dragon",
                                 "galatasaray", "fenerbahce", "fenerbahçe", "besiktas", "beşiktaş", "trabzon",
                                 "istanbul", "ankara", "izmir", "turkiye", "türkiye", "seviyorum", "askim", "aşkım", "qwe", "zxc"]

    static func of(_ pw: String) -> Strength {
        guard !pw.isEmpty else { return Strength(score: 0, bits: 0) }
        var pool = 0
        let lowerSet = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzçğıöşü")
        let upperSet = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZÇĞİÖŞÜ")
        let digitSet = CharacterSet(charactersIn: "0123456789")
        var hasLower = false, hasUpper = false, hasDigit = false, hasOther = false
        for scalar in pw.unicodeScalars {
            if lowerSet.contains(scalar) { hasLower = true }
            else if upperSet.contains(scalar) { hasUpper = true }
            else if digitSet.contains(scalar) { hasDigit = true }
            else { hasOther = true }
        }
        if hasLower { pool += 26 }
        if hasUpper { pool += 26 }
        if hasDigit { pool += 10 }
        if hasOther { pool += 33 }
        let length = pw.count
        var bits = Double(length) * log2(Double(max(pool, 1)))
        let low = pw.lowercased(with: Locale(identifier: "tr_TR"))
        if common.contains(where: { low.contains($0) }) { bits *= 0.5 }
        if pw.range(of: "(.)\\1{2,}", options: .regularExpression) != nil { bits -= 10 }
        if pw.range(of: "(0123|1234|2345|3456|4567|5678|6789|9876|8765|7654|abcd|bcde|qwer|wert|asdf|zxcv)",
                    options: [.regularExpression, .caseInsensitive]) != nil { bits -= 10 }
        if length < 12, pw.range(of: "(19|20)[0-9]{2}$", options: .regularExpression) != nil { bits -= 6 }
        if Set(pw).count * 2 < length { bits *= 0.75 }
        let b = max(0, Int(bits.rounded()))
        let score: Int
        if b < 28 { score = 0 } else if b < 40 { score = 1 } else if b < 60 { score = 2 } else if b < 80 { score = 3 } else { score = 4 }
        return Strength(score: score, bits: b)
    }

    static func crackTime(bits: Int) -> String {
        let s = pow(2.0, Double(bits)) / 2 / 1e10   // saniyede 10 milyar tahmin
        if s < 1 { return "anında" }
        if s < 60 { return "\(Int(s)) saniye" }
        if s < 3600 { return "\(Int(s / 60)) dakika" }
        if s < 86400 { return "\(Int(s / 3600)) saat" }
        if s < 31_536_000 { return "\(Int(s / 86400)) gün" }
        if s < 31_536_000_000 { return "\(Int(s / 31_536_000)) yıl" }
        return "yüzyıllar"
    }
}

// MARK: - Şifre üretici

enum PasswordGenerator {
    static let upper = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    static let lower = "abcdefghijklmnopqrstuvwxyz"
    static let digits = "0123456789"
    static let symbols = "!@#$%^&*()-_=+[]{};:,.?/~"
    static let ambiguous = Set("Il1O0o")

    static func generate(_ o: GenOptions) -> String {
        var sets: [[Character]] = []
        if o.upper { sets.append(Array(upper)) }
        if o.lower { sets.append(Array(lower)) }
        if o.digits { sets.append(Array(digits)) }
        if o.symbols { sets.append(Array(symbols)) }
        if sets.isEmpty { sets.append(Array(lower)) }
        if o.noAmbig { sets = sets.map { $0.filter { !ambiguous.contains($0) } } }
        let all = sets.flatMap { $0 }
        let length = max(o.length, sets.count)
        var rng = SystemRandomNumberGenerator()
        var out: [Character] = sets.map { $0.randomElement(using: &rng)! }
        while out.count < length { out.append(all.randomElement(using: &rng)!) }
        out.shuffle(using: &rng)
        return String(out)
    }
}

// MARK: - TOTP (iki adımlı doğrulama)

struct TOTPConfig {
    enum Algorithm { case sha1, sha256, sha512 }
    let key: Data
    let digits: Int
    let period: Int
    let algorithm: Algorithm
}

enum TOTP {
    static func base32Decode(_ input: String) -> Data? {
        let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")
        var map: [Character: UInt32] = [:]
        for (i, c) in alphabet.enumerated() { map[c] = UInt32(i) }
        let clean = input.uppercased().filter { !" =-\n\t\r".contains($0) }
        var buffer: UInt32 = 0
        var bits: UInt32 = 0
        var out = Data()
        for ch in clean {
            guard let v = map[ch] else { return nil }
            buffer = (buffer << 5) | v
            bits += 5
            if bits >= 8 {
                out.append(UInt8((buffer >> (bits - 8)) & 0xFF))
                bits -= 8
                buffer &= (UInt32(1) << bits) - 1
            }
        }
        return out
    }

    static func parse(_ input: String) -> TOTPConfig? {
        let raw = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return nil }
        var secret = raw
        var digits = 6
        var period = 30
        var algorithm = TOTPConfig.Algorithm.sha1
        if raw.lowercased().hasPrefix("otpauth:") {
            guard let comps = URLComponents(string: raw) else { return nil }
            secret = ""
            for item in comps.queryItems ?? [] {
                let value = item.value ?? ""
                switch item.name.lowercased() {
                case "secret": secret = value
                case "digits": digits = Int(value) ?? 6
                case "period": period = Int(value) ?? 30
                case "algorithm":
                    let a = value.uppercased().replacingOccurrences(of: "-", with: "")
                    if a == "SHA256" { algorithm = .sha256 } else if a == "SHA512" { algorithm = .sha512 }
                default: break
                }
            }
        }
        guard let key = base32Decode(secret), key.count >= 5 else { return nil }
        if digits < 6 || digits > 8 { digits = 6 }
        if period <= 0 { period = 30 }
        return TOTPConfig(key: key, digits: digits, period: period, algorithm: algorithm)
    }

    static func code(_ c: TOTPConfig, at date: Date = Date()) -> String {
        let counter = UInt64(max(0, date.timeIntervalSince1970)) / UInt64(c.period)
        var big = counter.bigEndian
        let message = withUnsafeBytes(of: &big) { Data($0) }
        let key = SymmetricKey(data: c.key)
        let mac: [UInt8]
        switch c.algorithm {
        case .sha1: mac = Array(HMAC<Insecure.SHA1>.authenticationCode(for: message, using: key))
        case .sha256: mac = Array(HMAC<SHA256>.authenticationCode(for: message, using: key))
        case .sha512: mac = Array(HMAC<SHA512>.authenticationCode(for: message, using: key))
        }
        let offset = Int(mac[mac.count - 1] & 0x0F)
        let p0 = UInt32(mac[offset] & 0x7F) << 24
        let p1 = UInt32(mac[offset + 1]) << 16
        let p2 = UInt32(mac[offset + 2]) << 8
        let p3 = UInt32(mac[offset + 3])
        let binary = p0 | p1 | p2 | p3
        var modulo: UInt32 = 1
        for _ in 0..<c.digits { modulo *= 10 }
        let s = String(binary % modulo)
        return String(repeating: "0", count: max(0, c.digits - s.count)) + s
    }

    static func secondsRemaining(_ c: TOTPConfig, at date: Date = Date()) -> Int {
        c.period - (Int(date.timeIntervalSince1970) % c.period)
    }

    static func formatted(_ code: String) -> String {
        let half = (code.count + 1) / 2
        return String(code.prefix(half)) + " " + String(code.suffix(code.count - half))
    }

    static func uri(for e: Entry) -> String {
        guard !e.totp.isEmpty else { return "" }
        if e.totp.lowercased().hasPrefix("otpauth:") { return e.totp }
        let label = e.title.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? "Kasa"
        return "otpauth://totp/\(label)?secret=\(e.totp)"
    }
}

// MARK: - Kategori tahmini

enum CategoryGuess {
    private static let rules: [(EntryCategory, String)] = [
        (.sosyal, "instagram|facebook|twitter|\\bx\\.com|tiktok|linkedin|snapchat|reddit|pinterest|threads|telegram|whatsapp|discord|tumblr|youtube|eksi"),
        (.eposta, "gmail|outlook|hotmail|yandex|yahoo|icloud|proton|mail|e-?posta"),
        (.finans, "bank|banka|garanti|akbank|i[sş]bank|ziraat|yap[ıi] ?kredi|enpara|qnb|deniz|halkbank|vak[ıi]f|kuveyt|papara|paypal|binance|btcturk|paribu|ininal|kart|kredi|borsa|midas|e-?devlet|vergi"),
        (.alisveris, "trendyol|hepsiburada|amazon|n11|getir|yemeksepeti|sahibinden|aliexpress|ebay|migros|letgo|dolap|ciceksepeti|temu|shein|zara|lcw"),
        (.eglence, "netflix|spotify|steam|epic|playstation|psn|xbox|nintendo|exxen|blutv|disney|twitch|riot|valorant|prime video|tabii|gain|apple music|origin|ubisoft|battle\\.?net"),
        (.cihaz, "wi-?fi|wifi|modem|router|kablosuz|kamera"),
        (.isler, "slack|jira|teams|zoom|office|microsoft|notion|github|gitlab|asana|trello|vpn|şirket|sirket|kurumsal"),
    ]

    static func guess(title: String, url: String) -> EntryCategory? {
        let s = "\(title) \(url)"
        for (cat, pattern) in rules where s.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
            return cat
        }
        return nil
    }
}

// MARK: - CSV

enum CSV {
    static func parse(_ text: String, delimiter: Character) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        let chars = Array(text)
        var i = 0
        while i < chars.count {
            let ch = chars[i]
            if inQuotes {
                if ch == "\"" {
                    if i + 1 < chars.count && chars[i + 1] == "\"" { field.append("\""); i += 1 } else { inQuotes = false }
                } else {
                    field.append(ch)
                }
            } else if ch == "\"" {
                inQuotes = true
            } else if ch == delimiter {
                row.append(field); field = ""
            } else if ch == "\n" || ch == "\r" || ch == "\r\n" {
                row.append(field); rows.append(row); row = []; field = ""
            } else {
                field.append(ch)
            }
            i += 1
        }
        if !field.isEmpty || !row.isEmpty { row.append(field); rows.append(row) }
        return rows.filter { r in r.contains { !$0.trimmingCharacters(in: .whitespaces).isEmpty } }
    }

    static func detectDelimiter(_ text: String) -> Character {
        let first = text.split(whereSeparator: { $0 == "\n" || $0 == "\r" || $0 == "\r\n" }).first.map(String.init) ?? ""
        let commas = first.filter { $0 == "," }.count
        let semis = first.filter { $0 == ";" }.count
        let tabs = first.filter { $0 == "\t" }.count
        if semis > commas && semis >= tabs { return ";" }
        if tabs > commas { return "\t" }
        return ","
    }

    static func escape(_ s: String) -> String {
        "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

// MARK: - Pano, titreşim, paylaşım

@MainActor
enum Clipboard {
    static func copy(_ text: String) {
        guard !text.isEmpty else { return }
        let seconds = UserDefaults.standard.integer(forKey: Prefs.clipboard)
        var options: [UIPasteboard.OptionsKey: Any] = [.localOnly: true]
        if seconds > 0 { options[.expirationDate] = Date().addingTimeInterval(TimeInterval(seconds)) }
        UIPasteboard.general.setItems([[UTType.utf8PlainText.identifier: text]], options: options)
        Haptics.success()
    }
}

@MainActor
enum Haptics {
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func error() { UINotificationFeedbackGenerator().notificationOccurred(.error) }
    static func tap() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
}

@MainActor
enum ShareHelper {
    static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first(where: { $0.activationState == .foregroundActive }) ?? scenes.first
        var vc = scene?.windows.first(where: { $0.isKeyWindow })?.rootViewController ?? scene?.windows.first?.rootViewController
        while let presented = vc?.presentedViewController { vc = presented }
        return vc
    }

    /// Dosyayı paylaşım menüsüyle sunar; bittiğinde (isteğe bağlı) geçici dosyayı siler
    static func share(url: URL, deleteAfter: Bool, completion: ((Bool) -> Void)? = nil) {
        let vc = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        vc.completionWithItemsHandler = { _, completed, _, _ in
            if deleteAfter { try? FileManager.default.removeItem(at: url) }
            completion?(completed)
        }
        if let top = topViewController() {
            vc.popoverPresentationController?.sourceView = top.view
            vc.popoverPresentationController?.sourceRect = CGRect(x: top.view.bounds.midX, y: top.view.bounds.midY, width: 0, height: 0)
            top.present(vc, animated: true)
        }
    }

    static func writeTemp(name: String, data: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        try? FileManager.default.removeItem(at: url)
        try data.write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }
}

// MARK: - Tarih biçimleri

enum DateText {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateStyle = .long
        f.timeStyle = .short
        return f
    }()

    static func full(_ d: Date) -> String { formatter.string(from: d) }

    static func relative(_ d: Date) -> String {
        let days = Int(Date().timeIntervalSince(d) / 86400)
        if days <= 0 { return "bugün" }
        if days == 1 { return "dün" }
        return "\(days) gün önce"
    }

    static func stamp() -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
