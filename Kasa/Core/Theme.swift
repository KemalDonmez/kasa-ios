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
    static let appBackground = Color.dynamic(light: 0xF2F3F8, dark: 0x08080E)
    static let surface = Color.dynamic(light: 0xFFFFFF, dark: 0x13131C)
    static let surfaceRaised = Color.dynamic(light: 0xF4F5FA, dark: 0x1B1B27)
    static let hairline = Color.dynamic(light: 0x000000, dark: 0xFFFFFF, lightAlpha: 0.06, darkAlpha: 0.07)

    // Marka renkleri
    static let kasaAccent = Color(hex: 0x6C5CFF)
    static let kasaAccent2 = Color(hex: 0x3B82F6)
    static let kasaDanger = Color(hex: 0xFF4D5E)
    static let kasaOK = Color(hex: 0x22C55E)
    static let kasaWarn = Color(hex: 0xF59E0B)
}

extension LinearGradient {
    static let kasa = LinearGradient(colors: [Color(hex: 0x7C5CFF), Color(hex: 0x3B82F6)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing)
    static let hero = LinearGradient(colors: [Color(hex: 0x5B3DF5), Color(hex: 0x3B6CF6), Color(hex: 0x1FA2E8)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing)
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
            LinearGradient(colors: [Color.kasaAccent.opacity(0.16), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 320)
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
