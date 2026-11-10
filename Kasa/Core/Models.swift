import Foundation
import SwiftUI

enum AppInfo {
    static let name = "Şifrelerim"
}

/// Kayıt kategorileri
enum EntryCategory: String, Codable, CaseIterable, Identifiable, Hashable {
    case genel
    case sosyal
    case eposta
    case finans
    case isler = "is"
    case alisveris
    case eglence
    case cihaz
    case diger

    var id: String { rawValue }

    var name: String {
        switch self {
        case .genel: return "Genel"
        case .sosyal: return "Sosyal Medya"
        case .eposta: return "E-posta"
        case .finans: return "Banka & Finans"
        case .isler: return "İş"
        case .alisveris: return "Alışveriş"
        case .eglence: return "Eğlence & Oyun"
        case .cihaz: return "Wi-Fi & Cihaz"
        case .diger: return "Diğer"
        }
    }

    var shortName: String {
        switch self {
        case .finans: return "Finans"
        case .eglence: return "Eğlence"
        case .cihaz: return "Wi-Fi & Cihaz"
        default: return name
        }
    }

    var icon: String {
        switch self {
        case .genel: return "key.fill"
        case .sosyal: return "bubble.left.and.bubble.right.fill"
        case .eposta: return "envelope.fill"
        case .finans: return "creditcard.fill"
        case .isler: return "briefcase.fill"
        case .alisveris: return "bag.fill"
        case .eglence: return "play.rectangle.fill"
        case .cihaz: return "wifi"
        case .diger: return "square.grid.2x2.fill"
        }
    }

    var colors: [Color] {
        switch self {
        case .genel: return [Color(hex: 0x8B6CFF), Color(hex: 0x5B3DF5)]
        case .sosyal: return [Color(hex: 0xFF5C93), Color(hex: 0xE0306E)]
        case .eposta: return [Color(hex: 0x4D9BFF), Color(hex: 0x2A6DF0)]
        case .finans: return [Color(hex: 0x2FD58A), Color(hex: 0x13A866)]
        case .isler: return [Color(hex: 0xFFB648), Color(hex: 0xF08A1C)]
        case .alisveris: return [Color(hex: 0xFF8A50), Color(hex: 0xF25A22)]
        case .eglence: return [Color(hex: 0xC77DFF), Color(hex: 0x9B4DF0)]
        case .cihaz: return [Color(hex: 0x33D1E6), Color(hex: 0x119DB8)]
        case .diger: return [Color(hex: 0x9A9AB0), Color(hex: 0x6E6E86)]
        }
    }

    var color: Color { colors[0] }
}

struct PasswordHistoryItem: Codable, Hashable {
    var password: String
    var changedAt: Double
}

/// Tek bir şifre kaydı. Zaman damgaları milisaniye cinsindendir (yedek dosyalarıyla uyumlu).
struct Entry: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var username: String
    var password: String
    var url: String
    var notes: String
    var totp: String
    var category: EntryCategory
    var favorite: Bool
    var createdAt: Double
    var updatedAt: Double
    var pwChangedAt: Double
    var history: [PasswordHistoryItem]

    init(id: String = UUID().uuidString,
         title: String = "",
         username: String = "",
         password: String = "",
         url: String = "",
         notes: String = "",
         totp: String = "",
         category: EntryCategory = .genel,
         favorite: Bool = false,
         createdAt: Double = Entry.nowMs(),
         updatedAt: Double = Entry.nowMs(),
         pwChangedAt: Double = Entry.nowMs(),
         history: [PasswordHistoryItem] = []) {
        self.id = id
        self.title = title
        self.username = username
        self.password = password
        self.url = url
        self.notes = notes
        self.totp = totp
        self.category = category
        self.favorite = favorite
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.pwChangedAt = pwChangedAt
        self.history = history
    }

    enum CodingKeys: String, CodingKey {
        case id, title, username, password, url, notes, totp, category, favorite, createdAt, updatedAt, pwChangedAt, history
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let now = Entry.nowMs()
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        title = (try? c.decode(String.self, forKey: .title)) ?? "Adsız"
        username = (try? c.decode(String.self, forKey: .username)) ?? ""
        password = (try? c.decode(String.self, forKey: .password)) ?? ""
        url = (try? c.decode(String.self, forKey: .url)) ?? ""
        notes = (try? c.decode(String.self, forKey: .notes)) ?? ""
        totp = (try? c.decode(String.self, forKey: .totp)) ?? ""
        let rawCategory = (try? c.decode(String.self, forKey: .category)) ?? "genel"
        category = EntryCategory(rawValue: rawCategory) ?? .genel
        favorite = (try? c.decode(Bool.self, forKey: .favorite)) ?? false
        createdAt = (try? c.decode(Double.self, forKey: .createdAt)) ?? now
        updatedAt = (try? c.decode(Double.self, forKey: .updatedAt)) ?? createdAt
        pwChangedAt = (try? c.decode(Double.self, forKey: .pwChangedAt)) ?? createdAt
        history = (try? c.decode([PasswordHistoryItem].self, forKey: .history)) ?? []
        if title.trimmingCharacters(in: .whitespaces).isEmpty { title = "Adsız" }
    }

    static func nowMs() -> Double { Date().timeIntervalSince1970 * 1000 }

    var createdDate: Date { Date(timeIntervalSince1970: createdAt / 1000) }
    var updatedDate: Date { Date(timeIntervalSince1970: updatedAt / 1000) }
    var pwChangedDate: Date { Date(timeIntervalSince1970: pwChangedAt / 1000) }

    var host: String { URLHelper.host(url) }

    var subtitle: String {
        if !username.isEmpty { return username }
        if !host.isEmpty { return host }
        return category.name
    }

    var initial: String {
        let t = title.trimmingCharacters(in: .whitespaces)
        guard let first = t.first else { return "?" }
        return String(first).uppercased(with: Locale(identifier: "tr_TR"))
    }
}

/// Şifrelenmiş olarak saklanan içerik
struct VaultData: Codable {
    var entries: [Entry] = []
    var lastBackup: Double = 0

    enum CodingKeys: String, CodingKey { case entries, lastBackup }

    init(entries: [Entry] = [], lastBackup: Double = 0) {
        self.entries = entries
        self.lastBackup = lastBackup
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        entries = (try? c.decode([Entry].self, forKey: .entries)) ?? []
        lastBackup = (try? c.decode(Double.self, forKey: .lastBackup)) ?? 0
    }
}

/// Cihazda saklanan dosya. Ana şifre (kurtarma şifresi) isteğe bağlıdır;
/// varsa veri anahtarı bu şifreyle de sarılır.
struct VaultFile: Codable {
    var v: Int = 2
    var data: String
    var createdAt: Double
    var hint: String
    var salt: String?
    var iter: Int?
    var wrappedKey: String?

    var hasMaster: Bool { wrappedKey != nil && salt != nil }
}

/// Şifreli yedek dosyası (web sürümüyle uyumlu)
struct BackupRecord: Codable {
    var app: String
    var v: Int?
    var kdf: String?
    var iter: Int?
    var salt: String
    var hint: String?
    var iv: String
    var ct: String
    var createdAt: Double?
    var updatedAt: Double?
}

struct BackupPayload: Codable {
    var entries: [Entry]
    var createdAt: Double

    enum CodingKeys: String, CodingKey { case entries, createdAt }

    init(entries: [Entry], createdAt: Double) {
        self.entries = entries
        self.createdAt = createdAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        entries = (try? c.decode([Entry].self, forKey: .entries)) ?? []
        createdAt = (try? c.decode(Double.self, forKey: .createdAt)) ?? Entry.nowMs()
    }
}

/// Hassas olmayan tercihler (UserDefaults)
enum Prefs {
    static let theme = "pref.theme"                 // 0 sistem, 1 koyu, 2 açık
    static let legacyBiometrics = "pref.biometrics" // eski sürüm
    static let deviceUnlock = "pref.deviceUnlock"   // Face ID / iPhone parolası ile açma
    static let autoLock = "pref.autoLock"           // saniye; 0 = hemen, -1 = asla
    static let clipboard = "pref.clipboard"         // saniye; 0 = kapalı
    static let sort = "pref.sort"                   // "az" | "recent"
    static let genLength = "gen.length"
    static let genUpper = "gen.upper"
    static let genLower = "gen.lower"
    static let genDigits = "gen.digits"
    static let genSymbols = "gen.symbols"
    static let genNoAmbig = "gen.noAmbig"
    static let failCount = "sec.failCount"
    static let failTime = "sec.failTime"

    static func register() {
        UserDefaults.standard.register(defaults: [
            theme: 0,
            legacyBiometrics: false,
            deviceUnlock: false,
            autoLock: 60,
            clipboard: 30,
            sort: "az",
            genLength: 20,
            genUpper: true,
            genLower: true,
            genDigits: true,
            genSymbols: true,
            genNoAmbig: true,
            failCount: 0,
            failTime: 0.0,
        ])
    }

    static var genOptions: GenOptions {
        let d = UserDefaults.standard
        return GenOptions(length: d.integer(forKey: genLength),
                          upper: d.bool(forKey: genUpper),
                          lower: d.bool(forKey: genLower),
                          digits: d.bool(forKey: genDigits),
                          symbols: d.bool(forKey: genSymbols),
                          noAmbig: d.bool(forKey: genNoAmbig))
    }
}

struct GenOptions {
    var length: Int
    var upper: Bool
    var lower: Bool
    var digits: Bool
    var symbols: Bool
    var noAmbig: Bool
}
