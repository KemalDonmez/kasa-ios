import Foundation

/// Bilinen servisler: ad → alan adı, kategori ve aranacak anahtar kelimeler
struct KnownService {
    let key: String
    let name: String
    let domain: String
    let category: EntryCategory
    let keywords: [String]
}

enum ServiceCatalog {
    static let all: [KnownService] = [
        // E-posta
        .init(key: "gmail", name: "Gmail", domain: "mail.google.com", category: .eposta, keywords: ["gmail", "googlemail"]),
        .init(key: "outlook", name: "Outlook", domain: "outlook.live.com", category: .eposta, keywords: ["outlook", "hotmail", "live.com", "msn"]),
        .init(key: "yandexmail", name: "Yandex Mail", domain: "mail.yandex.com", category: .eposta, keywords: ["yandex mail", "yandex"]),
        .init(key: "yahoo", name: "Yahoo Mail", domain: "mail.yahoo.com", category: .eposta, keywords: ["yahoo"]),
        .init(key: "icloud", name: "iCloud", domain: "icloud.com", category: .eposta, keywords: ["icloud", "apple id", "appleid", "apple kimliği"]),
        .init(key: "proton", name: "Proton Mail", domain: "proton.me", category: .eposta, keywords: ["proton"]),
        // Sosyal
        .init(key: "instagram", name: "Instagram", domain: "instagram.com", category: .sosyal, keywords: ["instagram", "insta "]),
        .init(key: "facebook", name: "Facebook", domain: "facebook.com", category: .sosyal, keywords: ["facebook", "fb "]),
        .init(key: "whatsapp", name: "WhatsApp", domain: "whatsapp.com", category: .sosyal, keywords: ["whatsapp"]),
        .init(key: "telegram", name: "Telegram", domain: "telegram.org", category: .sosyal, keywords: ["telegram"]),
        .init(key: "x", name: "X (Twitter)", domain: "x.com", category: .sosyal, keywords: ["twitter", "x.com"]),
        .init(key: "tiktok", name: "TikTok", domain: "tiktok.com", category: .sosyal, keywords: ["tiktok", "tik tok"]),
        .init(key: "linkedin", name: "LinkedIn", domain: "linkedin.com", category: .sosyal, keywords: ["linkedin"]),
        .init(key: "snapchat", name: "Snapchat", domain: "snapchat.com", category: .sosyal, keywords: ["snapchat"]),
        .init(key: "discord", name: "Discord", domain: "discord.com", category: .sosyal, keywords: ["discord"]),
        .init(key: "reddit", name: "Reddit", domain: "reddit.com", category: .sosyal, keywords: ["reddit"]),
        .init(key: "pinterest", name: "Pinterest", domain: "pinterest.com", category: .sosyal, keywords: ["pinterest"]),
        .init(key: "threads", name: "Threads", domain: "threads.net", category: .sosyal, keywords: ["threads"]),
        .init(key: "eksi", name: "Ekşi Sözlük", domain: "eksisozluk.com", category: .sosyal, keywords: ["ekşi", "eksi sozluk", "eksisozluk"]),
        .init(key: "youtube", name: "YouTube", domain: "youtube.com", category: .eglence, keywords: ["youtube"]),
        .init(key: "google", name: "Google", domain: "google.com", category: .genel, keywords: ["google"]),
        // Eğlence
        .init(key: "netflix", name: "Netflix", domain: "netflix.com", category: .eglence, keywords: ["netflix"]),
        .init(key: "spotify", name: "Spotify", domain: "spotify.com", category: .eglence, keywords: ["spotify"]),
        .init(key: "disney", name: "Disney+", domain: "disneyplus.com", category: .eglence, keywords: ["disney"]),
        .init(key: "primevideo", name: "Prime Video", domain: "primevideo.com", category: .eglence, keywords: ["prime video", "primevideo"]),
        .init(key: "exxen", name: "Exxen", domain: "exxen.com", category: .eglence, keywords: ["exxen"]),
        .init(key: "tabii", name: "tabii", domain: "tabii.com", category: .eglence, keywords: ["tabii"]),
        .init(key: "blutv", name: "BluTV", domain: "blutv.com", category: .eglence, keywords: ["blutv", "blu tv"]),
        .init(key: "gain", name: "Gain", domain: "gain.tv", category: .eglence, keywords: ["gain.tv"]),
        .init(key: "twitch", name: "Twitch", domain: "twitch.tv", category: .eglence, keywords: ["twitch"]),
        .init(key: "applemusic", name: "Apple Music", domain: "music.apple.com", category: .eglence, keywords: ["apple music"]),
        // Oyun
        .init(key: "steam", name: "Steam", domain: "steampowered.com", category: .oyun, keywords: ["steam"]),
        .init(key: "epic", name: "Epic Games", domain: "epicgames.com", category: .oyun, keywords: ["epic games", "epicgames", "epic"]),
        .init(key: "playstation", name: "PlayStation", domain: "playstation.com", category: .oyun, keywords: ["playstation", "psn", "ps plus"]),
        .init(key: "xbox", name: "Xbox", domain: "xbox.com", category: .oyun, keywords: ["xbox"]),
        .init(key: "nintendo", name: "Nintendo", domain: "nintendo.com", category: .oyun, keywords: ["nintendo"]),
        .init(key: "riot", name: "Riot Games", domain: "riotgames.com", category: .oyun, keywords: ["riot", "valorant", "league of legends", "lol hesab"]),
        .init(key: "battlenet", name: "Battle.net", domain: "battle.net", category: .oyun, keywords: ["battle.net", "battlenet", "blizzard"]),
        .init(key: "ubisoft", name: "Ubisoft", domain: "ubisoft.com", category: .oyun, keywords: ["ubisoft", "uplay"]),
        .init(key: "ea", name: "EA", domain: "ea.com", category: .oyun, keywords: ["ea app", "origin", "electronic arts"]),
        .init(key: "rockstar", name: "Rockstar Games", domain: "rockstargames.com", category: .oyun, keywords: ["rockstar"]),
        .init(key: "roblox", name: "Roblox", domain: "roblox.com", category: .oyun, keywords: ["roblox"]),
        .init(key: "minecraft", name: "Minecraft", domain: "minecraft.net", category: .oyun, keywords: ["minecraft"]),
        .init(key: "pubg", name: "PUBG", domain: "pubg.com", category: .oyun, keywords: ["pubg"]),
        .init(key: "itemsatis", name: "İtemSatış", domain: "itemsatis.com", category: .oyun, keywords: ["itemsatis", "itemsatış", "item satış", "item satis"]),
        .init(key: "gamesatis", name: "GameSatış", domain: "gamesatis.com", category: .oyun, keywords: ["gamesatis", "gamesatış"]),
        .init(key: "oyunfor", name: "Oyunfor", domain: "oyunfor.com", category: .oyun, keywords: ["oyunfor"]),
        .init(key: "itempazar", name: "İtemPazar", domain: "itempazar.com", category: .oyun, keywords: ["itempazar"]),
        .init(key: "hesapcomtr", name: "Hesap.com.tr", domain: "hesap.com.tr", category: .oyun, keywords: ["hesap.com.tr", "hesapcomtr"]),
        .init(key: "gameforge", name: "Gameforge", domain: "gameforge.com", category: .oyun, keywords: ["gameforge", "metin2"]),
        .init(key: "knightonline", name: "Knight Online", domain: "knightonline.com.tr", category: .oyun, keywords: ["knight online"]),
        // Alışveriş
        .init(key: "trendyol", name: "Trendyol", domain: "trendyol.com", category: .alisveris, keywords: ["trendyol"]),
        .init(key: "hepsiburada", name: "Hepsiburada", domain: "hepsiburada.com", category: .alisveris, keywords: ["hepsiburada"]),
        .init(key: "amazon", name: "Amazon", domain: "amazon.com.tr", category: .alisveris, keywords: ["amazon"]),
        .init(key: "n11", name: "n11", domain: "n11.com", category: .alisveris, keywords: ["n11"]),
        .init(key: "getir", name: "Getir", domain: "getir.com", category: .alisveris, keywords: ["getir"]),
        .init(key: "yemeksepeti", name: "Yemeksepeti", domain: "yemeksepeti.com", category: .alisveris, keywords: ["yemeksepeti", "yemek sepeti"]),
        .init(key: "sahibinden", name: "Sahibinden", domain: "sahibinden.com", category: .alisveris, keywords: ["sahibinden"]),
        .init(key: "aliexpress", name: "AliExpress", domain: "aliexpress.com", category: .alisveris, keywords: ["aliexpress"]),
        .init(key: "temu", name: "Temu", domain: "temu.com", category: .alisveris, keywords: ["temu"]),
        .init(key: "shein", name: "SHEIN", domain: "shein.com", category: .alisveris, keywords: ["shein"]),
        .init(key: "migros", name: "Migros", domain: "migros.com.tr", category: .alisveris, keywords: ["migros"]),
        .init(key: "ciceksepeti", name: "Çiçeksepeti", domain: "ciceksepeti.com", category: .alisveris, keywords: ["çiçeksepeti", "ciceksepeti"]),
        .init(key: "dolap", name: "Dolap", domain: "dolap.com", category: .alisveris, keywords: ["dolap"]),
        // Finans
        .init(key: "edevlet", name: "e-Devlet", domain: "turkiye.gov.tr", category: .finans, keywords: ["e-devlet", "edevlet", "e devlet", "turkiye.gov"]),
        .init(key: "garanti", name: "Garanti BBVA", domain: "garantibbva.com.tr", category: .finans, keywords: ["garanti"]),
        .init(key: "akbank", name: "Akbank", domain: "akbank.com", category: .finans, keywords: ["akbank"]),
        .init(key: "isbank", name: "İş Bankası", domain: "isbank.com.tr", category: .finans, keywords: ["iş bankası", "is bankasi", "isbank", "işbank", "isbankasi"]),
        .init(key: "ziraat", name: "Ziraat Bankası", domain: "ziraatbank.com.tr", category: .finans, keywords: ["ziraat"]),
        .init(key: "yapikredi", name: "Yapı Kredi", domain: "yapikredi.com.tr", category: .finans, keywords: ["yapı kredi", "yapikredi", "yapi kredi"]),
        .init(key: "qnb", name: "QNB", domain: "qnb.com.tr", category: .finans, keywords: ["qnb", "finansbank"]),
        .init(key: "enpara", name: "Enpara", domain: "enpara.com", category: .finans, keywords: ["enpara"]),
        .init(key: "denizbank", name: "DenizBank", domain: "denizbank.com", category: .finans, keywords: ["denizbank"]),
        .init(key: "halkbank", name: "Halkbank", domain: "halkbank.com.tr", category: .finans, keywords: ["halkbank"]),
        .init(key: "vakifbank", name: "VakıfBank", domain: "vakifbank.com.tr", category: .finans, keywords: ["vakıfbank", "vakifbank", "vakıf"]),
        .init(key: "kuveytturk", name: "Kuveyt Türk", domain: "kuveytturk.com.tr", category: .finans, keywords: ["kuveyt"]),
        .init(key: "papara", name: "Papara", domain: "papara.com", category: .finans, keywords: ["papara"]),
        .init(key: "paypal", name: "PayPal", domain: "paypal.com", category: .finans, keywords: ["paypal"]),
        .init(key: "binance", name: "Binance", domain: "binance.com", category: .finans, keywords: ["binance"]),
        .init(key: "btcturk", name: "BtcTurk", domain: "btcturk.com", category: .finans, keywords: ["btcturk"]),
        .init(key: "paribu", name: "Paribu", domain: "paribu.com", category: .finans, keywords: ["paribu"]),
        .init(key: "midas", name: "Midas", domain: "getmidas.com", category: .finans, keywords: ["midas"]),
        // İş ve araçlar
        .init(key: "microsoft", name: "Microsoft", domain: "microsoft.com", category: .isler, keywords: ["microsoft", "office 365", "teams"]),
        .init(key: "github", name: "GitHub", domain: "github.com", category: .isler, keywords: ["github"]),
        .init(key: "slack", name: "Slack", domain: "slack.com", category: .isler, keywords: ["slack"]),
        .init(key: "zoom", name: "Zoom", domain: "zoom.us", category: .isler, keywords: ["zoom"]),
        .init(key: "notion", name: "Notion", domain: "notion.so", category: .isler, keywords: ["notion"]),
        .init(key: "dropbox", name: "Dropbox", domain: "dropbox.com", category: .isler, keywords: ["dropbox"]),
        .init(key: "chatgpt", name: "ChatGPT", domain: "chatgpt.com", category: .isler, keywords: ["chatgpt", "openai"]),
        .init(key: "claude", name: "Claude", domain: "claude.ai", category: .isler, keywords: ["claude"]),
        // Operatörler
        .init(key: "turkcell", name: "Turkcell", domain: "turkcell.com.tr", category: .cihaz, keywords: ["turkcell"]),
        .init(key: "vodafone", name: "Vodafone", domain: "vodafone.com.tr", category: .cihaz, keywords: ["vodafone"]),
        .init(key: "turktelekom", name: "Türk Telekom", domain: "turktelekom.com.tr", category: .cihaz, keywords: ["türk telekom", "turk telekom", "turktelekom"]),
        .init(key: "superonline", name: "Superonline", domain: "superonline.net", category: .cihaz, keywords: ["superonline"]),
    ]

    private static let trLocale = Locale(identifier: "tr_TR")

    static func normalized(_ s: String) -> String {
        " " + s.lowercased(with: trLocale).trimmingCharacters(in: .whitespacesAndNewlines) + " "
    }

    /// Başlık veya adreste geçen bilinen servisi bulur
    static func match(title: String, url: String) -> KnownService? {
        let host = URLHelper.host(url).lowercased()
        if !host.isEmpty, let s = all.first(where: { host == $0.domain || host.hasSuffix("." + $0.domain) }) {
            return s
        }
        let t = normalized(title + " " + host)
        return all.first { s in s.keywords.contains { t.contains($0) } }
    }

    /// Ada göre öneriler (düzenleme ekranı için)
    static func suggestions(for text: String, limit: Int = 6) -> [KnownService] {
        let q = text.lowercased(with: trLocale).trimmingCharacters(in: .whitespaces)
        guard q.count >= 2 else { return [] }
        let starts = all.filter { $0.name.lowercased(with: trLocale).hasPrefix(q) || $0.key.hasPrefix(q) }
        let contains = all.filter { s in
            !starts.contains(where: { $0.key == s.key }) &&
            (s.name.lowercased(with: trLocale).contains(q) || s.keywords.contains { $0.trimmingCharacters(in: .whitespaces).hasPrefix(q) })
        }
        return Array((starts + contains).prefix(limit))
    }
}

/// Aynı servise ait kayıtları gruplamak için anahtar
enum ServiceKey {
    private static let trLocale = Locale(identifier: "tr_TR")
    private static let noise = ["hesabı", "hesabim", "hesabım", "hesap", "kişisel", "kisisel", "iş", "is", "yedek", "eski", "yeni",
                                "ana", "ikinci", "2.", "ikinci hesap"]

    static func of(_ e: Entry) -> String {
        if let s = ServiceCatalog.match(title: e.title, url: e.url) { return "svc:" + s.key }
        let host = URLHelper.host(e.url).lowercased()
        if !host.isEmpty { return "host:" + host }
        var t = e.title.lowercased(with: trLocale)
        for sep in [" - ", " – ", " (", " / ", " | "] {
            if let r = t.range(of: sep) { t = String(t[..<r.lowerBound]) }
        }
        var words = t.split(separator: " ").map(String.init)
        while let last = words.last, words.count > 1, noise.contains(last) || Int(last) != nil {
            words.removeLast()
        }
        let joined = words.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        return "title:" + (joined.isEmpty ? e.title.lowercased(with: trLocale) : joined)
    }

    static func displayName(for entries: [Entry]) -> String {
        guard let first = entries.first else { return "" }
        if let s = ServiceCatalog.match(title: first.title, url: first.url) { return s.name }
        var counts: [String: Int] = [:]
        for e in entries { counts[e.title, default: 0] += 1 }
        return counts.max { a, b in a.value == b.value ? a.key > b.key : a.value < b.value }?.key ?? first.title
    }
}

/// Simgesi indirilecek alan adı
enum IconDomain {
    private static let stopWords: Set<String> = ["banka", "wifi", "wi-fi", "modem", "mail", "eposta", "e-posta", "okul", "ev", "is", "iş",
                                                 "oyun", "telefon", "kart", "kredi", "bilgisayar", "pc", "laptop", "router", "şifre",
                                                 "sifre", "hesap", "genel", "diğer", "diger", "not", "notlar", "pin", "test", "deneme"]

    /// Kesin alan adı: adres, bilinen servis veya alan adı biçimindeki başlık
    static func exact(for e: Entry) -> String? {
        let host = URLHelper.host(e.url).lowercased()
        if !host.isEmpty, host.contains(".") { return host }
        if let s = ServiceCatalog.match(title: e.title, url: e.url) { return s.domain }
        let t = e.title.lowercased().trimmingCharacters(in: .whitespaces)
        if t.contains("."), !t.contains(" "), t.count >= 4 { return URLHelper.host(t) }
        return nil
    }

    /// Tahmini alan adları (tek kelimelik adlar için: ad.com, ad.com.tr)
    static func guesses(for e: Entry) -> [String] {
        let t = e.title.lowercased(with: Locale(identifier: "tr_TR")).trimmingCharacters(in: .whitespaces)
        guard t.count >= 3, !t.contains(" "), !stopWords.contains(t) else { return [] }
        let ascii = t.applyingTransform(.toLatin, reverse: false)?
            .applyingTransform(.stripDiacritics, reverse: false)?
            .replacingOccurrences(of: "ı", with: "i") ?? t
        let clean = ascii.filter { $0.isLetter || $0.isNumber || $0 == "-" }
        guard clean.count >= 3 else { return [] }
        return ["\(clean).com", "\(clean).com.tr"]
    }

    static func cacheKey(for e: Entry) -> String? {
        if let d = exact(for: e) { return d }
        if let g = guesses(for: e).first { return "guess:" + g }
        return nil
    }
}
