import Foundation
import SwiftUI
import CryptoKit
import Security
import LocalAuthentication

enum AppTab: Hashable { case vault, generator, security, settings }

/// Tüm verileri ve kilit durumunu yöneten merkezi nesne
@MainActor
final class VaultStore: ObservableObject {
    enum Phase { case loading, setup, locked, unlocked }

    struct Report {
        var total = 0
        var weak: [Entry] = []
        var reused: [Entry] = []
        var old: [Entry] = []
        var problemCount = 0
        var score = 0
        var with2FA = 0
    }

    @Published private(set) var phase: Phase = .loading
    @Published private(set) var entries: [Entry] = []
    @Published private(set) var report = Report()
    @Published private(set) var lastBackup: Double = 0
    @Published private(set) var hasMaster = false
    @Published private(set) var deviceUnlockEnabled = false
    @Published private(set) var deviceKeyMissing = false
    @Published private(set) var authInProgress = false
    @Published var selectedTab: AppTab = .vault

    private var vaultKey: SymmetricKey?
    private var file: VaultFile?
    private var backgroundAt: Date?
    private var autoPromptArmed = true
    private var strengthCache: [String: Strength] = [:]
    private let fileURL: URL
    private let ioQueue = DispatchQueue(label: "kasa.vault.io", qos: .userInitiated)

    var hint: String { file?.hint ?? "" }
    var legacyBiometrics: Bool { UserDefaults.standard.bool(forKey: Prefs.legacyBiometrics) }

    init() {
        Prefs.register()
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("kasa-vault.json")
        deviceUnlockEnabled = UserDefaults.standard.bool(forKey: Prefs.deviceUnlock)
        if let data = try? Data(contentsOf: fileURL), let f = try? JSONDecoder().decode(VaultFile.self, from: data) {
            file = f
            hasMaster = f.hasMaster
            phase = .locked
        } else {
            phase = .setup
        }
    }

    // MARK: - Kaydetme

    private func persist() {
        guard var f = file, let key = vaultKey else { return }
        do {
            let payload = try JSONEncoder().encode(VaultData(entries: entries, lastBackup: lastBackup))
            f.data = try KasaCrypto.seal(payload, key: key).base64
            f.v = 2
            file = f
            writeFile(f)
        } catch {
            Toaster.shared.show("Kaydedilemedi: \(error.localizedDescription)", isError: true)
        }
    }

    private func writeFile(_ f: VaultFile) {
        guard let out = try? JSONEncoder().encode(f) else { return }
        let url = fileURL
        ioQueue.async {
            do {
                try out.write(to: url, options: [.atomic, .completeFileProtection])
            } catch {
                Task { @MainActor in Toaster.shared.show("Diske yazılamadı: \(error.localizedDescription)", isError: true) }
            }
        }
    }

    private func entriesChanged(save: Bool = true) {
        recomputeReport()
        if save { persist() }
    }

    private func strength(_ pw: String) -> Strength {
        if let s = strengthCache[pw] { return s }
        let s = Strength.of(pw)
        strengthCache[pw] = s
        return s
    }

    private func recomputeReport() {
        var r = Report()
        let withPw = entries.filter { !$0.password.isEmpty }
        r.total = withPw.count
        var counts: [String: Int] = [:]
        for e in withPw { counts[e.password, default: 0] += 1 }
        let yearMs = 365.0 * 86_400_000
        let now = Entry.nowMs()
        r.weak = withPw.filter { strength($0.password).score <= 1 }
        r.reused = withPw.filter { (counts[$0.password] ?? 0) > 1 }
        r.old = withPw.filter { now - $0.pwChangedAt > yearMs }
        let bad = Set((r.weak + r.reused + r.old).map(\.id))
        r.problemCount = bad.count
        r.score = r.total == 0 ? 0 : Int((Double(r.total - bad.count) / Double(r.total) * 100).rounded())
        r.with2FA = entries.filter { !$0.totp.isEmpty }.count
        report = r
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
        migrateGamesIfNeeded()
        recomputeReport()
        selectedTab = .vault
        phase = .unlocked
    }

    /// Eski "Eğlence & Oyun" kategorisindeki oyun kayıtlarını yeni "Oyun" kategorisine taşır (bir kez)
    private func migrateGamesIfNeeded() {
        let d = UserDefaults.standard
        guard !d.bool(forKey: Prefs.migratedGames) else { return }
        var changed = false
        for i in entries.indices where entries[i].category == .eglence {
            if CategoryGuess.guess(title: entries[i].title, url: entries[i].url) == .oyun {
                entries[i].category = .oyun
                changed = true
            }
        }
        d.set(true, forKey: Prefs.migratedGames)
        if changed { persist() }
    }

    /// Aynı servise ait diğer kayıtlar
    func siblings(of e: Entry) -> [Entry] {
        let key = ServiceKey.of(e)
        return entries.filter { $0.id != e.id && ServiceKey.of($0) == key }
            .sorted { $0.username.localizedCaseInsensitiveCompare($1.username) == .orderedAscending }
    }

    // MARK: - Kurulum

    /// Yeni kasa oluşturur. Cihaz kilidi (Face ID / parola) varsa onunla korunur; ana şifre isteğe bağlıdır.
    func createVault(masterPassword: String?, hint: String, entries initial: [Entry] = []) async throws {
        let useDevice = DeviceAuth.isAvailable
        guard useDevice || (masterPassword?.isEmpty == false) else { throw KasaError.deviceAuthUnavailable }
        let vk = SymmetricKey(size: .bits256)
        var f = VaultFile(data: "", createdAt: Entry.nowMs(), hint: hint)
        if let pw = masterPassword, !pw.isEmpty {
            let salt = KasaCrypto.randomBytes(16)
            let kek = await KasaCrypto.deriveKeyAsync(password: pw, salt: salt, iterations: KasaCrypto.iterations)
            f.salt = salt.base64
            f.iter = KasaCrypto.iterations
            f.wrappedKey = try KasaCrypto.seal(KasaCrypto.keyData(vk), key: kek).base64
        }
        if useDevice {
            try DeviceKeychain.save(KasaCrypto.keyData(vk))
        }
        file = f
        hasMaster = f.hasMaster
        setDeviceUnlockFlag(useDevice)
        deviceKeyMissing = false
        vaultKey = vk
        entries = initial
        lastBackup = 0
        resetFails()
        entriesChanged()
        selectedTab = .vault
        phase = .unlocked
    }

    // MARK: - Kilit açma

    private func setDeviceUnlockFlag(_ on: Bool) {
        deviceUnlockEnabled = on
        UserDefaults.standard.set(on, forKey: Prefs.deviceUnlock)
    }

    /// Kilit ekranı göründüğünde veya uygulama öne geldiğinde Face ID'yi kendiliğinden başlatır
    func autoUnlockIfPossible() {
        guard phase == .locked, autoPromptArmed, !authInProgress else { return }
        guard deviceUnlockEnabled || legacyBiometrics else { return }
        autoPromptArmed = false
        Task { await unlockWithDevice() }
    }

    func unlockWithDevice() async {
        guard phase == .locked, !authInProgress else { return }
        authInProgress = true
        defer { authInProgress = false }
        do {
            let ctx = try await DeviceAuth.authenticate(reason: "Şifrelerinizi açmak için")
            if deviceUnlockEnabled {
                do {
                    let raw = try DeviceKeychain.load(context: ctx)
                    try open(with: SymmetricKey(data: raw))
                    resetFails()
                    return
                } catch KasaError.keychain(let status) where status == errSecItemNotFound {
                    setDeviceUnlockFlag(false)
                    deviceKeyMissing = true
                }
            }
            if legacyBiometrics {
                // Önceki sürümden geçiş: eski Face ID anahtarı
                if let raw = try? LegacyBiometricKeychain.load(context: ctx) {
                    try open(with: SymmetricKey(data: raw))
                    migrateToDeviceKey()
                    return
                }
            }
            if deviceKeyMissing {
                Toaster.shared.show(hasMaster ? "Cihaz anahtarı bulunamadı. Ana şifrenizle açın." : "Cihaz anahtarı bulunamadı. Yedekten geri yükleyin.", isError: true)
            } else if !deviceUnlockEnabled {
                Toaster.shared.show("Face ID ile açma kapalı. Ana şifrenizle açın.", isError: true)
            }
        } catch let error as LAError {
            switch error.code {
            case .notInteractive, .appCancel, .systemCancel:
                autoPromptArmed = true
            default:
                break
            }
        } catch {
            Toaster.shared.show(error.localizedDescription, isError: true)
        }
    }

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
        guard let f = file, let saltStr = f.salt, let salt = Data(base64Encoded: saltStr),
              let wrappedStr = f.wrappedKey, let wrapped = Data(base64Encoded: wrappedStr) else {
            throw KasaError.message("Ana şifre tanımlı değil.")
        }
        let kek = await KasaCrypto.deriveKeyAsync(password: password, salt: salt, iterations: f.iter ?? KasaCrypto.iterations)
        let raw: Data
        do {
            raw = try KasaCrypto.open(wrapped, key: kek)
        } catch {
            registerFail()
            throw KasaError.wrongPassword
        }
        try open(with: SymmetricKey(data: raw))
        resetFails()
        if !deviceUnlockEnabled { migrateToDeviceKey() }
    }

    /// Anahtarı Face ID korumalı cihaz anahtarına taşır; sonraki açılışlar otomatik olur
    private func migrateToDeviceKey() {
        guard let vk = vaultKey, DeviceAuth.isAvailable else { return }
        do {
            try DeviceKeychain.save(KasaCrypto.keyData(vk))
            setDeviceUnlockFlag(true)
            deviceKeyMissing = false
            LegacyBiometricKeychain.delete()
            UserDefaults.standard.set(false, forKey: Prefs.legacyBiometrics)
            persist()
        } catch {
            // Sessizce geç; ana şifre ile açmaya devam edilir
        }
    }

    func lock() {
        vaultKey = nil
        entries = []
        report = Report()
        strengthCache.removeAll()
        Toaster.shared.busy = nil
        if file != nil { phase = .locked }
    }

    func scenePhaseChanged(_ newPhase: ScenePhase) {
        switch newPhase {
        case .background:
            if backgroundAt == nil { backgroundAt = Date() }
            autoPromptArmed = true
            if phase == .unlocked && UserDefaults.standard.integer(forKey: Prefs.autoLock) == 0 { lock() }
        case .active:
            if let since = backgroundAt, phase == .unlocked {
                let limit = UserDefaults.standard.integer(forKey: Prefs.autoLock)
                if limit >= 0 && Date().timeIntervalSince(since) >= Double(limit) { lock() }
            }
            backgroundAt = nil
            autoUnlockIfPossible()
        default:
            break
        }
    }

    // MARK: - Ana şifre (kurtarma şifresi) yönetimi

    func verifyMaster(_ password: String) async -> Bool {
        guard let f = file, let saltStr = f.salt, let salt = Data(base64Encoded: saltStr),
              let wrappedStr = f.wrappedKey, let wrapped = Data(base64Encoded: wrappedStr) else { return false }
        let kek = await KasaCrypto.deriveKeyAsync(password: password, salt: salt, iterations: f.iter ?? KasaCrypto.iterations)
        return (try? KasaCrypto.open(wrapped, key: kek)) != nil
    }

    func setMaster(current: String?, new: String) async throws {
        if hasMaster {
            guard let current, await verifyMaster(current) else { throw KasaError.wrongPassword }
        }
        guard var f = file, let vk = vaultKey else { throw KasaError.corrupt }
        let salt = KasaCrypto.randomBytes(16)
        let kek = await KasaCrypto.deriveKeyAsync(password: new, salt: salt, iterations: KasaCrypto.iterations)
        f.salt = salt.base64
        f.iter = KasaCrypto.iterations
        f.wrappedKey = try KasaCrypto.seal(KasaCrypto.keyData(vk), key: kek).base64
        file = f
        hasMaster = true
        persist()
    }

    func removeMaster(current: String) async throws {
        guard deviceUnlockEnabled else {
            throw KasaError.message("Ana şifreyi kaldırmak için önce Face ID ile açmayı etkinleştirin.")
        }
        guard await verifyMaster(current) else { throw KasaError.wrongPassword }
        guard var f = file else { return }
        f.salt = nil
        f.iter = nil
        f.wrappedKey = nil
        f.hint = ""
        file = f
        hasMaster = false
        persist()
    }

    func setHint(_ hint: String) {
        file?.hint = hint
        persist()
    }

    func setDeviceUnlock(_ on: Bool) async {
        if on {
            guard let vk = vaultKey else { return }
            do {
                _ = try await DeviceAuth.authenticate(reason: "Face ID ile açmayı etkinleştirmek için")
                try DeviceKeychain.save(KasaCrypto.keyData(vk))
                setDeviceUnlockFlag(true)
                deviceKeyMissing = false
                Toaster.shared.show("\(DeviceAuth.name) ile açma etkinleştirildi")
            } catch let error as LAError where error.code == .userCancel {
                // vazgeçildi
            } catch {
                Toaster.shared.show(error.localizedDescription, isError: true)
            }
        } else {
            guard hasMaster else {
                Toaster.shared.show("Kapatmadan önce bir ana şifre belirleyin; aksi halde uygulamayı açamazsınız.", isError: true)
                return
            }
            DeviceKeychain.delete()
            setDeviceUnlockFlag(false)
        }
    }

    func wipe() {
        let url = fileURL
        ioQueue.async { try? FileManager.default.removeItem(at: url) }
        DeviceKeychain.delete()
        LegacyBiometricKeychain.delete()
        UserDefaults.standard.set(false, forKey: Prefs.legacyBiometrics)
        setDeviceUnlockFlag(false)
        resetFails()
        vaultKey = nil
        file = nil
        hasMaster = false
        deviceKeyMissing = false
        entries = []
        report = Report()
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
        entriesChanged()
    }

    func toggleFavorite(_ id: String) {
        guard let i = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[i].favorite.toggle()
        persist()
        Haptics.tap()
    }

    func delete(_ id: String) {
        guard let i = entries.firstIndex(where: { $0.id == id }) else { return }
        let removed = entries.remove(at: i)
        entriesChanged()
        Toaster.shared.show("“\(removed.title)” silindi", action: ToastAction(title: "Geri al") { [weak self] in
            guard let self, self.phase == .unlocked else { return }
            self.entries.insert(removed, at: min(i, self.entries.count))
            self.entriesChanged()
            Toaster.shared.dismiss()
        })
    }

    // MARK: - Yedekleme

    /// Yedek dosyası oluşturur. Ana şifre varsa onu doğrular; yoksa verilen şifre yedek şifresi olur.
    func makeBackup(password: String) async throws -> URL {
        if hasMaster {
            guard await verifyMaster(password) else { throw KasaError.wrongPassword }
        }
        let salt = KasaCrypto.randomBytes(16)
        let key = await KasaCrypto.deriveKeyAsync(password: password, salt: salt, iterations: KasaCrypto.iterations)
        let now = Entry.nowMs()
        let payload = try JSONEncoder().encode(BackupPayload(entries: entries, createdAt: now))
        let sealed = try KasaCrypto.sealWebFormat(payload, key: key)
        let record = BackupRecord(app: "kasa", v: 1, kdf: "PBKDF2-SHA256", iter: KasaCrypto.iterations, salt: salt.base64,
                                  hint: hint, iv: sealed.iv.base64, ct: sealed.ct.base64, createdAt: now, updatedAt: now)
        let data = try JSONEncoder().encode(record)
        let url = try ShareHelper.writeTemp(name: "sifrelerim-yedek-\(DateText.stamp()).json", data: data)
        lastBackup = now
        persist()
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
        entriesChanged()
        return (added, updated)
    }

    /// Boş cihazda yedekten yeni kasa oluşturur (yedeğin şifresi ana şifre olur)
    func restoreBackup(data: Data, password: String) async throws -> Int {
        let result = try await VaultStore.readBackup(data: data, password: password)
        try await createVault(masterPassword: password, hint: result.hint, entries: result.entries)
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
        entriesChanged()
        return (added, skipped)
    }

    func exportCSV() throws -> URL {
        var lines = ["Title,URL,Username,Password,Notes,OTPAuth"]
        for e in entries {
            lines.append([e.title, e.url, e.username, e.password, e.notes, TOTP.uri(for: e)].map(CSV.escape).joined(separator: ","))
        }
        let text = "\u{FEFF}" + lines.joined(separator: "\r\n")
        return try ShareHelper.writeTemp(name: "sifrelerim-\(DateText.stamp()).csv", data: Data(text.utf8))
    }
}
