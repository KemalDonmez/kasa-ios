import Foundation
import SwiftUI

/// Kayıt kategorileri (web sürümüyle aynı kimlikler)
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

    var icon: String {
        switch self {
        case .genel: return "key.fill"
        case .sosyal: return "person.2.fill"
        case .eposta: return "envelope.fill"
        case .finans: return "creditcard.fill"
        case .isler: return "briefcase.fill"
        case .alisveris: return "bag.fill"
        case .eglence: return "gamecontroller.fill"
        case .cihaz: return "wifi"
        case .diger: return "square.grid.2x2.fill"
        }
    }

    var color: Color {
        switch self {
        case .genel: return Color(hex: 0x8B6CFF)
        case .sosyal: return Color(hex: 0xFF4F86)
        case .eposta: return Color(hex: 0x3F8CFF)
        case .finans: return Color(hex: 0x22C06F)
        case .isler: return Color(hex: 0xF5A524)
        case .alisveris: return Color(hex: 0xFF7440)
        case .eglence: return Color(hex: 0xB55CFF)
        case .cihaz: return Color(hex: 0x17B5CC)
        case .diger: return Color(hex: 0x7C7C8E)
        }
    }
}

struct PasswordHistoryItem: Codable, Hashable {
    var password: String
    var changedAt: Double
}

/// Tek bir şifre kaydı. Zaman damgaları milisaniye cinsindendir (web sürümüyle uyumlu yedekler için).
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

/// Şifrelenmiş olarak saklanan kasa içeriği
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

/// Cihazda saklanan kasa dosyası
struct VaultFile: Codable {
    var v: Int = 1
    var salt: String
    var iter: Int
    var wrappedKey: String
    var data: String
    var hint: String
    var createdAt: Double
}

/// Web sürümüyle uyumlu şifreli yedek dosyası
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

/// Kullanıcı tercihleri (hassas olmayan, UserDefaults'ta tutulur)
enum Prefs {
    static let theme = "pref.theme"                 // 0 sistem, 1 koyu, 2 açık
    static let biometrics = "pref.biometrics"
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
            biometrics: false,
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

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }

    static let kasaAccent = Color(hex: 0x7B5CFF)
    static let kasaAccent2 = Color(hex: 0x3F7DFF)
    static let kasaDanger = Color(hex: 0xFF4D5E)
    static let kasaOK = Color(hex: 0x22C06F)
    static let kasaWarn = Color(hex: 0xF5A524)
}

extension LinearGradient {
    static let kasa = LinearGradient(colors: [Color(hex: 0x8B6CFF), Color(hex: 0x3F7DFF)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing)
}
