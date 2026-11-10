import SwiftUI
import UIKit

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }

    static func dynamic(light: UInt32, dark: UInt32, lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1) -> Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark, alpha: darkAlpha) : UIColor(hex: light, alpha: lightAlpha)
        })
    }

    // Zemin ve yüzeyler
    static let appBackground = Color.dynamic(light: 0xF3F5FA, dark: 0x070A12)
    static let surface = Color.dynamic(light: 0xFFFFFF, dark: 0x10151F)
    static let surfaceRaised = Color.dynamic(light: 0xF1F4F9, dark: 0x182033)
    static let hairline = Color.dynamic(light: 0x0B1220, dark: 0xFFFFFF, lightAlpha: 0.07, darkAlpha: 0.07)

    // Seçili temaya göre değişen vurgu renkleri
    static var kasaAccent: Color { Theme.palette.accent }
    static var kasaAccent2: Color { Theme.palette.accent2 }

    // Sabit durum renkleri
    static let kasaDanger = Color(hex: 0xF43F5E)
    static let kasaOK = Color(hex: 0x10B981)
    static let kasaWarn = Color(hex: 0xF59E0B)
}

/// Uygulamanın renk temaları
enum Palette: String, CaseIterable, Identifiable {
    case gece, mor, okyanus, zumrut, gunbatimi, grafit

    var id: String { rawValue }

    var name: String {
        switch self {
        case .gece: return "Gece Mavisi"
        case .mor: return "Mor"
        case .okyanus: return "Okyanus"
        case .zumrut: return "Zümrüt"
        case .gunbatimi: return "Gün Batımı"
        case .grafit: return "Grafit"
        }
    }

    private var hexes: (accent: UInt32, accent2: UInt32, grad: [UInt32], hero: [UInt32]) {
        switch self {
        case .gece: return (0x4F6BF5, 0x0EA5E9, [0x4F46E5, 0x0EA5E9], [0x1E1B5E, 0x4338CA, 0x0EA5E9])
        case .mor: return (0x6C5CFF, 0x3B82F6, [0x7C5CFF, 0x3B82F6], [0x4C2FD6, 0x3B6CF6, 0x1FA2E8])
        case .okyanus: return (0x0EA5C4, 0x22D3EE, [0x0891B2, 0x22D3EE], [0x0C4A5E, 0x0891B2, 0x22D3EE])
        case .zumrut: return (0x10A37F, 0x34D399, [0x059669, 0x34D399], [0x064E3B, 0x059669, 0x34D399])
        case .gunbatimi: return (0xF0567A, 0xF97316, [0xEC4899, 0xF97316], [0x831843, 0xDB2777, 0xF97316])
        case .grafit: return (0x6B7A90, 0x94A3B8, [0x475569, 0x1E293B], [0x0F172A, 0x334155, 0x64748B])
        }
    }

    var accent: Color { Color(hex: hexes.accent) }
    var accent2: Color { Color(hex: hexes.accent2) }
    var gradientColors: [Color] { hexes.grad.map { Color(hex: $0) } }
    var heroColors: [Color] { hexes.hero.map { Color(hex: $0) } }
}

/// Seçili tema. Uygulama açılırken ve tema değiştiğinde güncellenir.
enum Theme {
    static var palette: Palette = Palette(rawValue: UserDefaults.standard.string(forKey: Prefs.palette) ?? "") ?? .gece {
        didSet {
            gradient = LinearGradient(colors: palette.gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
            hero = LinearGradient(colors: palette.heroColors, startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    static var gradient = LinearGradient(colors: palette.gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing)
    static var hero = LinearGradient(colors: palette.heroColors, startPoint: .topLeading, endPoint: .bottomTrailing)

    static func set(_ p: Palette) {
        palette = p
        UserDefaults.standard.set(p.rawValue, forKey: Prefs.palette)
    }
}

extension LinearGradient {
    static var kasa: LinearGradient { Theme.gradient }
    static var hero: LinearGradient { Theme.hero }
}

/// Kart görünümü
struct CardModifier: ViewModifier {
    var padding: CGFloat
    var radius: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(Color.surface))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Color.hairline, lineWidth: 1))
    }
}

extension View {
    func card(padding: CGFloat = 16, radius: CGFloat = 20) -> some View {
        modifier(CardModifier(padding: padding, radius: radius))
    }
}

/// Uygulama genelinde kullanılan arka plan
struct AppBackground: View {
    var body: some View {
        ZStack(alignment: .top) {
            Color.appBackground
            LinearGradient(colors: [Color.kasaAccent.opacity(0.14), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 300)
        }
        .ignoresSafeArea()
    }
}

/// Bilinen servisler için marka renkleri (simge değil, yalnızca renk)
enum BrandPalette {
    private static let table: [([String], [UInt32])] = [
        (["instagram"], [0xF58529, 0xDD2A7B, 0x8134AF]),
        (["facebook", "messenger"], [0x1877F2, 0x0B5BD3]),
        (["whatsapp"], [0x25D366, 0x128C7E]),
        (["telegram"], [0x2AABEE, 0x1E88D1]),
        (["twitter", "x.com"], [0x2B2B2B, 0x0A0A0A]),
        (["tiktok"], [0x25F4EE, 0xFE2C55]),
        (["linkedin"], [0x0A66C2, 0x004182]),
        (["youtube"], [0xFF0033, 0xC4001F]),
        (["discord"], [0x5865F2, 0x3C45C5]),
        (["reddit"], [0xFF5700, 0xE03D00]),
        (["snapchat"], [0xFFD600, 0xF2B600]),
        (["pinterest"], [0xE60023, 0xAD001B]),
        (["gmail", "google"], [0xEA4335, 0xC5221F]),
        (["outlook", "hotmail", "microsoft", "office", "teams"], [0x0078D4, 0x005A9E]),
        (["icloud", "apple"], [0x4A4A50, 0x1C1C1E]),
        (["yandex"], [0xFC3F1D, 0xD9341A]),
        (["netflix"], [0xE50914, 0x99060D]),
        (["spotify"], [0x1ED760, 0x15A24A]),
        (["steam"], [0x2A475E, 0x1B2838]),
        (["playstation", "psn"], [0x0070D1, 0x003791]),
        (["xbox"], [0x16A116, 0x0E6A0E]),
        (["disney"], [0x1F3A93, 0x0B1F5C]),
        (["amazon"], [0xFF9900, 0xE07A00]),
        (["trendyol"], [0xF27A1A, 0xDB5F00]),
        (["hepsiburada"], [0xFF6000, 0xE04F00]),
        (["getir"], [0x6A46D6, 0x4C2FA6]),
        (["yemeksepeti"], [0xFA0050, 0xC9003F]),
        (["paypal"], [0x009CDE, 0x003087]),
        (["papara"], [0x8B3DFF, 0x5A1BD1]),
        (["binance"], [0xF3BA2F, 0xD49A00]),
        (["garanti"], [0x14A35C, 0x00733E]),
        (["akbank"], [0xF0222C, 0xB5050F]),
        (["isbank", "işbank", "iş bankası", "is bankasi"], [0x1F5FBF, 0x0A3A82]),
        (["ziraat"], [0xF0222C, 0xA30812]),
        (["yapı kredi", "yapikredi", "yapi kredi"], [0x1E5BB8, 0x0B2D6B]),
        (["enpara"], [0x6E3FD6, 0x4A23A8]),
        (["e-devlet", "edevlet", "turkiye.gov"], [0xE30A17, 0x9E0712]),
        (["github"], [0x3D444D, 0x161B22]),
    ]

    private static var cache: [String: [Color]] = [:]

    static func colors(for e: Entry) -> [Color] {
        let key = (e.title + "|" + e.url).lowercased()
        if let hit = cache[key] { return hit }
        var result = e.category.colors
        for (words, hexes) in table where words.contains(where: { key.contains($0) }) {
            result = hexes.map { Color(hex: $0) }
            break
        }
        if cache.count > 2000 { cache.removeAll() }
        cache[key] = result
        return result
    }

    static func gradient(for e: Entry) -> LinearGradient {
        LinearGradient(colors: colors(for: e), startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
