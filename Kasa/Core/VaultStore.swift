import Foundation
import SwiftUI
import CryptoKit
import Security

enum AppTab: Hashable { case vault, generator, security, settings }

/// Kasanın tüm durumunu yöneten merkezi nesne
@MainActor
final class VaultStore: ObservableObject {
    enum Phase { case loading, setup, locked, unlocked }

    @Published private(set) var phase: Phase = .loading
    @Published private(set) var entries: [Entry] = []
    @Published private(set) var lastBackup: Double = 0
    @Published var selectedTab: AppTab = .vault
    @Published var toast: ToastMessage?
    @Published var busyMessage: String?
    @Published var biometricsEnabled: Bool = UserDefaults.standard.bool(forKey: Prefs.biometrics)

    private var vaultKey: SymmetricKey?
    private var file: VaultFile?
    private var backgroundAt: Date?
    private var bioInProgress = false

    var hint: String { file?.hint ?? "" }
    var hasVault: Bool { file != nil }

    private var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("kasa-vault.json")
    }

    init() {
        Prefs.register()
        biometricsEnabled = UserDefaults.standard.bool(forKey: Prefs.biometrics)
        load()
    }

    // MARK: - Yükleme ve kaydetme

    private func load() {
        if let data = try? Data(contentsOf: fileURL), let f = try? JSONDecoder().decode(VaultFile.self, from: data) {
            file = f
            phase = .locked
        } else {
            phase = .setup
        }
    }

    private func save() throws {
        guard var f = file, let key = vaultKey else { return }
        let payload = try JSONEncoder().encode(VaultData(entries: entries, lastBackup: lastBackup))
        f.data = try KasaCrypto.seal(payload, key: key).base64
        let out = try JSONEncoder().encode(f)
        try out.write(to: fileURL, options: [.atomic, .completeFileProtection])
        file = f
    }

    private func saveOrToast() {
        do { try save() } catch { showToast("Kaydedilemedi: \(error.localizedDescription)", isError: true) }
    }

    private func open(with key: SymmetricKey) throws {
        guard let f = file else { throw KasaError.corrupt }
        if f.data.isEmpty {
            entries = []
            lastBackup = 0
        } else {
            guard let blob = Data(base64Encoded: f.data) else { throw KasaError.corrupt }
            let json = try KasaCrypto.open(blob, key: key)
            let vault = try JSONDecoder().decode(VaultData.self, from: json)
            entries = vault.entries
            lastBackup = vault.lastBackup
        }
        vaultKey = key
        phase = .unlocked
    }

    // MARK: - Kurulum

    func createVault(password: String, hint: String, entries initial: [Entry] = []) async throws {
        let salt = KasaCrypto.randomBytes(16)
        let kek = await KasaCrypto.deriveKeyAsync(password: password, salt: salt, iterations: KasaCrypto.iterations)
        let vk = SymmetricKey(size: .bits256)
        let wrapped = try KasaCrypto.seal(KasaCrypto.keyData(vk), key: kek)
        file = VaultFile(salt: salt.base64, iter: KasaCrypto.iterations, wrappedKey: wrapped.base64, data: "",
                         hint: hint, createdAt: Entry.nowMs())
        vaultKey = vk
        entries = initial
        lastBackup = 0
        try save()
        resetFails()
        selectedTab = .vault
        phase = .unlocked
    }

    // MARK: - Kilit

    var lockoutRemaining: TimeInterval {
        let d = UserDefaults.standard
        let n = d.integer(forKey: Prefs.failCount)
        guard n >= 5 else { return 0 }
        let wait = min(30 * pow(2, Double(n - 5)), 15 * 60)
        let until = d.double(forKey: Prefs.failTime) + wait
        return max(0, until - Date().timeIntervalSince1970)
    }

    var failCount: Int { UserDefaults.standard.integer(forKey: Prefs.failCount) }

    private func registerFail() {
        let d = UserDefaults.standard
        d.set(d.integer(forKey: Prefs.failCount) + 1, forKey: Prefs.failCount)
        d.set(Date().timeIntervalSince1970, forKey: Prefs.failTime)
    }

    private func resetFails() {
        UserDefaults.standard.set(0, forKey: Prefs.failCount)
    }

    func unlock(password: String) async throws {
        guard let f = file, let salt = Data(base64Encoded: f.salt), let wrapped = Data(base64Encoded: f.wrappedKey) else {
            throw KasaError.corrupt
        }
        let kek = await KasaCrypto.deriveKeyAsync(password: password, salt: salt, iterations: f.iter)
        do {
            let raw = try KasaCrypto.open(wrapped, key: kek)
            try open(with: SymmetricKey(data: raw))
            resetFails()
            selectedTab = .vault
        } catch {
            registerFail()
            throw KasaError.wrongPassword
        }
    }

    func unlockWithBiometrics() async {
        guard phase == .locked, biometricsEnabled, !bioInProgress else { return }
        bioInProgress = true
        defer { bioInProgress = false }
        do {
            let ctx = try await BiometricKeychain.authenticate(reason: "Kasanın kilidini açmak için")
            let raw = try BiometricKeychain.load(context: ctx)
            try open(with: SymmetricKey(data: raw))
            resetFails()
            selectedTab = .vault
        } catch KasaError.keychain(let status) {
            // Face ID kayıtları değiştiyse anahtar geçersiz olur; ana şifre ile yeniden açılması gerekir
            if status == errSecItemNotFound || status == errSecAuthFailed {
                setBiometrics(false)
                showToast("Face ID kaydı değişti. Lütfen ana şifreyle açıp yeniden etkinleştirin.", isError: true)
            }
        } catch {
            // Kullanıcı vazgeçtiyse sessizce ana şifre ekranında kalınır
        }
    }

    func lock() {
        vaultKey = nil
        entries = []
        busyMessage = nil
        if file != nil { phase = .locked }
    }

    func verifyMaster(_ password: String) async -> Bool {
        guard let f = file, let salt = Data(base64Encoded: f.salt), let wrapped = Data(base64Encoded: f.wrappedKey) else { return false }
        let kek = await KasaCrypto.deriveKeyAsync(password: password, salt: salt, iterations: f.iter)
        return (try? KasaCrypto.open(wrapped, key: kek)) != nil
    }

    func changeMaster(current: String, new: String) async throws {
        guard await verifyMaster(current) else { throw KasaError.wrongPassword }
        guard var f = file, let vk = vaultKey else { throw KasaError.corrupt }
        let salt = KasaCrypto.randomBytes(16)
        let kek = await KasaCrypto.deriveKeyAsync(password: new, salt: salt, iterations: KasaCrypto.iterations)
        f.salt = salt.base64
        f.iter = KasaCrypto.iterations
        f.wrappedKey = try KasaCrypto.seal(KasaCrypto.keyData(vk), key: kek).base64
        file = f
        try save()
    }

    func setHint(_ hint: String) {
        file?.hint = hint
        saveOrToast()
    }

    func setBiometrics(_ on: Bool) {
        if on {
            guard let vk = vaultKey else { return }
            do {
                try BiometricKeychain.save(KasaCrypto.keyData(vk))
                biometricsEnabled = true
            } catch {
                biometricsEnabled = false
                showToast(error.localizedDescription, isError: true)
            }
        } else {
            BiometricKeychain.delete()
            biometricsEnabled = false
        }
        UserDefaults.standard.set(biometricsEnabled, forKey: Prefs.biometrics)
    }

    func scenePhaseChanged(_ newPhase: ScenePhase) {
        switch newPhase {
        case .background:
            if backgroundAt == nil { backgroundAt = Date() }
            if phase == .unlocked && UserDefaults.standard.integer(forKey: Prefs.autoLock) == 0 { lock() }
        case .active:
            let wasInBackground = backgroundAt != nil
            if let since = backgroundAt, phase == .unlocked {
                let limit = UserDefaults.standard.integer(forKey: Prefs.autoLock)
                if limit >= 0 && Date().timeIntervalSince(since) >= Double(limit) { lock() }
            }
            backgroundAt = nil
            if wasInBackground && phase == .locked && biometricsEnabled {
                Task { await unlockWithBiometrics() }
            }
        default:
            break
        }
    }

    func wipe() {
        try? FileManager.default.removeItem(at: fileURL)
        BiometricKeychain.delete()
        UserDefaults.standard.set(false, forKey: Prefs.biometrics)
        biometricsEnabled = false
        resetFails()
        vaultKey = nil
        file = nil
        entries = []
        lastBackup = 0
        phase = .setup
    }

    // MARK: - Kayıt işlemleri

    func entry(_ id: String) -> Entry? { entries.first { $0.id == id } }

    func upsert(_ e: Entry) {
        var item = e
        let now = Entry.nowMs()
        if let i = entries.firstIndex(where: { $0.id == e.id }) {
            let old = entries[i]
            if old.password != item.password {
                if !old.password.isEmpty {
                    item.history = Array(([PasswordHistoryItem(password: old.password, changedAt: now)] + old.history).prefix(10))
                }
                item.pwChangedAt = now
            }
            item.updatedAt = now
            entries[i] = item
        } else {
            item.createdAt = now
            item.updatedAt = now
            item.pwChangedAt = now
            entries.append(item)
        }
        saveOrToast()
    }

    func toggleFavorite(_ id: String) {
        guard let i = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[i].favorite.toggle()
        saveOrToast()
        Haptics.tap()
    }

    func delete(_ id: String) {
        guard let i = entries.firstIndex(where: { $0.id == id }) else { return }
        let removed = entries.remove(at: i)
        saveOrToast()
        showToast("“\(removed.title)” silindi", action: ToastAction(title: "Geri al") { [weak self] in
            guard let self, self.phase == .unlocked else { return }
            self.entries.insert(removed, at: min(i, self.entries.count))
            self.saveOrToast()
        })
    }

    // MARK: - Yedekleme (web sürümüyle uyumlu)

    func makeBackup(password: String) async throws -> URL {
        guard await verifyMaster(password) else { throw KasaError.wrongPassword }
        let salt = KasaCrypto.randomBytes(16)
        let key = await KasaCrypto.deriveKeyAsync(password: password, salt: salt, iterations: KasaCrypto.iterations)
        let now = Entry.nowMs()
        let payload = try JSONEncoder().encode(BackupPayload(entries: entries, createdAt: now))
        let sealed = try KasaCrypto.sealWebFormat(payload, key: key)
        let record = BackupRecord(app: "kasa", v: 1, kdf: "PBKDF2-SHA256", iter: KasaCrypto.iterations, salt: salt.base64,
                                  hint: hint, iv: sealed.iv.base64, ct: sealed.ct.base64, createdAt: now, updatedAt: now)
        let data = try JSONEncoder().encode(record)
        let url = try ShareHelper.writeTemp(name: "kasa-yedek-\(DateText.stamp()).json", data: data)
        lastBackup = now
        saveOrToast()
        return url
    }

    nonisolated static func readBackup(data: Data, password: String) async throws -> (entries: [Entry], hint: String) {
        guard let rec = try? JSONDecoder().decode(BackupRecord.self, from: data), rec.app == "kasa",
              let salt = Data(base64Encoded: rec.salt), let iv = Data(base64Encoded: rec.iv), let ct = Data(base64Encoded: rec.ct) else {
            throw KasaError.invalidBackup
        }
        let key = await KasaCrypto.deriveKeyAsync(password: password, salt: salt, iterations: rec.iter ?? KasaCrypto.iterations)
        guard let json = try? KasaCrypto.openWebFormat(iv: iv, ct: ct, key: key) else { throw KasaError.wrongPassword }
        guard let payload = try? JSONDecoder().decode(BackupPayload.self, from: json) else { throw KasaError.corrupt }
        return (payload.entries, rec.hint ?? "")
    }

    /// Yedekteki kayıtları mevcut kasayla birleştirir
    func mergeBackup(data: Data, password: String) async throws -> (added: Int, updated: Int) {
        let result = try await VaultStore.readBackup(data: data, password: password)
        var added = 0, updated = 0
        for e in result.entries {
            if let i = entries.firstIndex(where: { $0.id == e.id }) {
                if e.updatedAt > entries[i].updatedAt { entries[i] = e; updated += 1 }
            } else {
                entries.append(e); added += 1
            }
        }
        saveOrToast()
        return (added, updated)
    }

    /// Boş cihazda yedekten yeni kasa oluşturur (ana şifre = yedeğin şifresi)
    func restoreBackup(data: Data, password: String) async throws -> Int {
        let result = try await VaultStore.readBackup(data: data, password: password)
        try await createVault(password: password, hint: result.hint, entries: result.entries)
        return result.entries.count
    }

    // MARK: - CSV

    func importCSV(_ text: String) -> (added: Int, skipped: Int)? {
        let clean = text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text
        let rows = CSV.parse(clean, delimiter: CSV.detectDelimiter(clean))
        guard rows.count >= 2 else { return nil }
        let head = rows[0].map { $0.trimmingCharacters(in: .whitespaces).lowercased(with: Locale(identifier: "tr_TR")) }
        func col(_ names: [String]) -> Int? {
            for n in names { if let i = head.firstIndex(of: n) { return i } }
            return nil
        }
        let cTitle = col(["title", "name", "başlık", "baslik", "ad", "account", "hesap"])
        let cURL = col(["url", "login_uri", "website", "web site", "site", "uri", "web sitesi"])
        let cUser = col(["username", "login_username", "user name", "user", "login", "email", "e-mail", "e-posta", "kullanıcı adı", "kullanici adi"])
        guard let cPass = col(["password", "login_password", "şifre", "sifre", "parola"]) else { return nil }
        let cNotes = col(["notes", "note", "extra", "comments", "notlar", "not"])
        let cTotp = col(["otpauth", "totp", "login_totp", "otp"])
        let cType = col(["type"])
        let cFav = col(["favorite"])

        var seen = Set(entries.map { "\($0.title)\u{1}\($0.username)\u{1}\($0.password)" })
        var added = 0, skipped = 0
        let now = Entry.nowMs()
        for r in rows.dropFirst() {
            func g(_ i: Int?) -> String {
                guard let i, i < r.count else { return "" }
                return r[i].trimmingCharacters(in: .whitespacesAndNewlines)
            }
            let type = g(cType).lowercased()
            if !type.isEmpty && type != "login" { skipped += 1; continue }
            let password = cPass < r.count ? r[cPass] : ""
            let username = g(cUser), url = g(cURL)
            var title = g(cTitle)
            if title.isEmpty { title = URLHelper.host(url) }
            if title.isEmpty { title = username }
            if title.isEmpty || (password.isEmpty && username.isEmpty) { skipped += 1; continue }
            let key = "\(title)\u{1}\(username)\u{1}\(password)"
            if seen.contains(key) { skipped += 1; continue }
            seen.insert(key)
            var totp = g(cTotp)
            if !totp.isEmpty && TOTP.parse(totp) == nil { totp = "" }
            let fav = g(cFav).lowercased()
            entries.append(Entry(title: title, username: username, password: password, url: url, notes: g(cNotes), totp: totp,
                                 category: CategoryGuess.guess(title: title, url: url) ?? .genel,
                                 favorite: fav == "1" || fav == "true",
                                 createdAt: now, updatedAt: now, pwChangedAt: now))
            added += 1
        }
        saveOrToast()
        return (added, skipped)
    }

    func exportCSV() throws -> URL {
        var lines = ["Title,URL,Username,Password,Notes,OTPAuth"]
        for e in entries {
            lines.append([e.title, e.url, e.username, e.password, e.notes, TOTP.uri(for: e)].map(CSV.escape).joined(separator: ","))
        }
        let text = "\u{FEFF}" + lines.joined(separator: "\r\n")
        return try ShareHelper.writeTemp(name: "kasa-sifreler-\(DateText.stamp()).csv", data: Data(text.utf8))
    }

    // MARK: - Güvenlik analizi

    struct Report {
        var total = 0
        var weak: [Entry] = []
        var reused: [Entry] = []
        var old: [Entry] = []
        var problemCount = 0
        var score = 0
        var with2FA = 0
    }

    var report: Report {
        var r = Report()
        let withPw = entries.filter { !$0.password.isEmpty }
        r.total = withPw.count
        var counts: [String: Int] = [:]
        for e in withPw { counts[e.password, default: 0] += 1 }
        let yearMs = 365.0 * 86_400_000
        let now = Entry.nowMs()
        r.weak = withPw.filter { Strength.of($0.password).score <= 1 }
        r.reused = withPw.filter { (counts[$0.password] ?? 0) > 1 }
        r.old = withPw.filter { now - $0.pwChangedAt > yearMs }
        let bad = Set((r.weak + r.reused + r.old).map(\.id))
        r.problemCount = bad.count
        r.score = r.total == 0 ? 0 : Int((Double(r.total - bad.count) / Double(r.total) * 100).rounded())
        r.with2FA = entries.filter { !$0.totp.isEmpty }.count
        return r
    }

    // MARK: - Bildirimler

    func showToast(_ text: String, isError: Bool = false, action: ToastAction? = nil) {
        let t = ToastMessage(text: text, isError: isError, action: action)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { toast = t }
        if isError { Haptics.error() }
        let delay: UInt64 = action == nil ? 2_300_000_000 : 4_500_000_000
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            guard let self, self.toast?.id == t.id else { return }
            withAnimation(.easeOut(duration: 0.25)) { self.toast = nil }
        }
    }
}

struct ToastAction {
    let title: String
    let run: @MainActor () -> Void
}

struct ToastMessage: Identifiable {
    let id = UUID()
    let text: String
    let isError: Bool
    let action: ToastAction?
}
