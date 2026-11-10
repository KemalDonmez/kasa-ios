import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @EnvironmentObject private var store: VaultStore
    @AppStorage(Prefs.autoLock) private var autoLock = 60
    @AppStorage(Prefs.clipboard) private var clipboard = 30
    @AppStorage(Prefs.theme) private var theme = 0

    enum PasswordPurpose { case exportBackup, importBackup, exportCSV }
    enum ImportMode { case backup, csv }

    @State private var passwordPurpose: PasswordPurpose?
    @State private var promptPassword = ""
    @State private var importMode: ImportMode = .backup
    @State private var showImporter = false
    @State private var pendingBackup: Data?
    @State private var showHintEditor = false
    @State private var hintText = ""
    @State private var confirmCSV = false
    @State private var confirmWipe = false
    @State private var showWipeText = false
    @State private var wipeText = ""

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var body: some View {
        NavigationStack {
            List {
                securitySection
                appearanceSection
                backupSection
                Section("Tehlikeli bölge") {
                    Button(role: .destructive) { confirmWipe = true } label: {
                        HStack(spacing: 12) {
                            IconBadge(systemName: "trash.fill", color: .kasaDanger)
                            Text("Tüm verileri sil").fontWeight(.semibold)
                        }
                    }
                }
                aboutSection
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Ayarlar")
            .alert(passwordTitle, isPresented: Binding(get: { passwordPurpose != nil }, set: { if !$0 { passwordPurpose = nil } })) {
                SecureField("Ana şifre", text: $promptPassword)
                Button("Vazgeç", role: .cancel) { pendingBackup = nil }
                Button("Devam") { handlePassword() }
            } message: {
                Text(passwordMessage)
            }
            .fileImporter(isPresented: $showImporter,
                          allowedContentTypes: importMode == .backup ? [.json, .data] : [.commaSeparatedText, .plainText, .data]) { result in
                guard case .success(let url) = result, let data = FileAccess.read(url) else { return }
                if importMode == .backup {
                    pendingBackup = data
                    promptPassword = ""
                    passwordPurpose = .importBackup
                } else {
                    importCSV(data)
                }
            }
            .confirmationDialog("Şifresiz dışa aktarım", isPresented: $confirmCSV, titleVisibility: .visible) {
                Button("Anladım, devam et", role: .destructive) {
                    promptPassword = ""
                    passwordPurpose = .exportCSV
                }
                Button("Vazgeç", role: .cancel) {}
            } message: {
                Text("CSV dosyası tüm şifrelerinizi AÇIK METİN olarak içerir. Kimseyle paylaşmayın ve işiniz bitince silin.")
            }
            .background(
                Color.clear
                    .alert("Şifre ipucu", isPresented: $showHintEditor) {
                        TextField("İpucu", text: $hintText)
                        Button("Vazgeç", role: .cancel) {}
                        Button("Kaydet") {
                            let h = String(hintText.trimmingCharacters(in: .whitespaces).prefix(80))
                            store.setHint(h)
                            store.showToast(h.isEmpty ? "İpucu kaldırıldı" : "İpucu kaydedildi")
                        }
                    } message: {
                        Text("Kilit ekranında gösterilir ve şifrelenmez. Şifrenin kendisini yazmayın. Silmek için boş bırakın.")
                    }
            )
            .overlay(
                Color.clear
                    .allowsHitTesting(false)
                    .alert("Onaylayın", isPresented: $showWipeText) {
                        TextField("SİL", text: $wipeText)
                        Button("Vazgeç", role: .cancel) {}
                        Button("Kalıcı olarak sil", role: .destructive) {
                            if wipeText.trimmingCharacters(in: .whitespaces).uppercased(with: Locale(identifier: "tr_TR")) == "SİL" {
                                store.wipe()
                                store.showToast("Tüm veriler silindi")
                            } else {
                                store.showToast("Onay metni hatalı, silinmedi", isError: true)
                            }
                        }
                    } message: {
                        Text("Silmek için SİL yazın.")
                    }
            )
            .confirmationDialog("Tüm veriler silinsin mi?", isPresented: $confirmWipe, titleVisibility: .visible) {
                Button("Devam et", role: .destructive) { wipeText = ""; showWipeText = true }
                Button("Vazgeç", role: .cancel) {}
            } message: {
                Text("Kasadaki tüm kayıtlar bu iPhone'dan kalıcı olarak silinecek. Bu işlem geri alınamaz.")
            }
        }
    }

    // MARK: Bölümler

    private var securitySection: some View {
        Section("Güvenlik") {
            if BiometricKeychain.isAvailable {
                Toggle(isOn: Binding(get: { store.biometricsEnabled }, set: { setBiometrics($0) })) {
                    settingLabel(BiometricKeychain.displayName + " ile aç", BiometricKeychain.iconName, .kasaOK)
                }
            }
            Picker(selection: $autoLock) {
                Text("Hemen").tag(0)
                Text("30 saniye").tag(30)
                Text("1 dakika").tag(60)
                Text("5 dakika").tag(300)
                Text("15 dakika").tag(900)
                Text("1 saat").tag(3600)
                Text("Asla").tag(-1)
            } label: {
                settingLabel("Otomatik kilit", "timer", .kasaAccent, subtitle: "Uygulamadan çıktıktan sonra")
            }
            Picker(selection: $clipboard) {
                Text("15 saniye").tag(15)
                Text("30 saniye").tag(30)
                Text("1 dakika").tag(60)
                Text("2 dakika").tag(120)
                Text("Kapalı").tag(0)
            } label: {
                settingLabel("Panoyu temizle", "doc.on.clipboard", .kasaAccent2, subtitle: "Kopyalanan şifre bu süre sonra silinir")
            }
            NavigationLink {
                ChangeMasterView()
            } label: {
                settingLabel("Ana şifreyi değiştir", "key.fill", .kasaWarn)
            }
            Button {
                hintText = store.hint
                showHintEditor = true
            } label: {
                HStack {
                    settingLabel("Şifre ipucu", "lightbulb.fill", Color(hex: 0x17B5CC), subtitle: store.hint.isEmpty ? "Tanımlı değil" : "Tanımlı")
                    Spacer()
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundColor(Color(.tertiaryLabel))
                }
            }
            .foregroundColor(.primary)
            Button { store.lock() } label: {
                settingLabel("Şimdi kilitle", "lock.fill", Color(hex: 0x7C7C8E))
            }
            .foregroundColor(.primary)
        }
    }

    private var appearanceSection: some View {
        Section("Görünüm") {
            Picker("Tema", selection: $theme) {
                Text("Sistem").tag(0)
                Text("Koyu").tag(1)
                Text("Açık").tag(2)
            }
            .pickerStyle(.segmented)
        }
    }

    private var backupSection: some View {
        Section {
            Button {
                promptPassword = ""
                passwordPurpose = .exportBackup
            } label: {
                settingLabel("Şifreli yedek al", "externaldrive.fill.badge.plus", .kasaOK,
                             subtitle: store.lastBackup == 0 ? "Henüz yedek alınmadı"
                             : "Son yedek: \(DateText.relative(Date(timeIntervalSince1970: store.lastBackup / 1000)))")
            }
            Button {
                importMode = .backup
                showImporter = true
            } label: {
                settingLabel("Yedekten geri yükle", "arrow.down.doc.fill", .kasaAccent2, subtitle: "Kayıtlar mevcut kasayla birleştirilir")
            }
            Button {
                importMode = .csv
                showImporter = true
            } label: {
                settingLabel("CSV içe aktar", "tablecells", .kasaAccent, subtitle: "iCloud Anahtar Zinciri, Chrome, Bitwarden…")
            }
            Button { confirmCSV = true } label: {
                settingLabel("CSV dışa aktar", "square.and.arrow.up", Color(hex: 0xFF7440), subtitle: "Şifresiz – dikkatli kullanın")
            }
        } header: {
            Text("Yedekleme ve aktarım")
        } footer: {
            Text("Şifreli yedek yalnızca ana şifrenizle açılabilir. Paylaşım menüsünden “Dosyalar'a Kaydet” › iCloud Drive'ı seçmeniz önerilir.")
        }
        .foregroundColor(.primary)
    }

    private var aboutSection: some View {
        Section {
            VStack(spacing: 8) {
                LogoView(size: 54)
                Text("Kasa").font(.headline)
                Text("Sürüm \(appVersion)").font(.caption).foregroundColor(.secondary)
                Text("Verileriniz yalnızca bu iPhone'da saklanır ve internete gönderilmez.\nAES-256-GCM şifreleme · PBKDF2-SHA256 (600.000 tur)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .listRowBackground(Color.clear)
        }
    }

    private func settingLabel(_ title: String, _ icon: String, _ color: Color, subtitle: String? = nil) -> some View {
        HStack(spacing: 12) {
            IconBadge(systemName: icon, color: color)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                if let subtitle { Text(subtitle).font(.caption).foregroundColor(.secondary) }
            }
        }
    }

    // MARK: İşlemler

    private var passwordTitle: String {
        switch passwordPurpose {
        case .importBackup: return "Yedeğin şifresi"
        default: return "Ana şifrenizi girin"
        }
    }

    private var passwordMessage: String {
        switch passwordPurpose {
        case .exportBackup: return "Yedek, ana şifrenizle şifrelenir."
        case .importBackup: return "Bu yedeği alırken kullandığınız ana şifreyi girin."
        case .exportCSV: return "Güvenliğiniz için ana şifrenizi doğrulayın."
        case .none: return ""
        }
    }

    private func setBiometrics(_ on: Bool) {
        guard on else { store.setBiometrics(false); return }
        Task {
            do {
                _ = try await BiometricKeychain.authenticate(reason: "Face ID ile açmayı etkinleştirmek için")
                store.setBiometrics(true)
                if store.biometricsEnabled { store.showToast("\(BiometricKeychain.displayName) etkinleştirildi") }
            } catch {
                store.showToast(error.localizedDescription, isError: true)
            }
        }
    }

    private func handlePassword() {
        guard let purpose = passwordPurpose else { return }
        let pw = promptPassword
        promptPassword = ""
        passwordPurpose = nil
        guard !pw.isEmpty else { return }
        switch purpose {
        case .exportBackup:
            store.busyMessage = "Yedek hazırlanıyor…"
            Task {
                do {
                    let url = try await store.makeBackup(password: pw)
                    store.busyMessage = nil
                    ShareHelper.share(url: url, deleteAfter: true) { done in
                        if done { store.showToast("Yedek kaydedildi") }
                    }
                } catch {
                    store.busyMessage = nil
                    store.showToast(error.localizedDescription, isError: true)
                }
            }
        case .importBackup:
            guard let data = pendingBackup else { return }
            pendingBackup = nil
            store.busyMessage = "Yedek çözülüyor…"
            Task {
                do {
                    let r = try await store.mergeBackup(data: data, password: pw)
                    store.busyMessage = nil
                    store.showToast(r.added + r.updated == 0 ? "Yeni kayıt bulunamadı" : "\(r.added) yeni, \(r.updated) güncellenmiş kayıt")
                } catch {
                    store.busyMessage = nil
                    store.showToast(error.localizedDescription, isError: true)
                }
            }
        case .exportCSV:
            store.busyMessage = "Doğrulanıyor…"
            Task {
                let ok = await store.verifyMaster(pw)
                store.busyMessage = nil
                guard ok else { store.showToast("Ana şifre hatalı", isError: true); return }
                do {
                    let url = try store.exportCSV()
                    ShareHelper.share(url: url, deleteAfter: true)
                } catch {
                    store.showToast(error.localizedDescription, isError: true)
                }
            }
        }
    }

    private func importCSV(_ data: Data) {
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .windowsCP1254) else {
            store.showToast("Dosya okunamadı", isError: true)
            return
        }
        guard let r = store.importCSV(text) else {
            store.showToast("Dosyada “password” sütunu bulunamadı", isError: true)
            return
        }
        store.showToast("\(r.added) kayıt içe aktarıldı" + (r.skipped > 0 ? ", \(r.skipped) atlandı" : "") + ". CSV dosyasını silmeyi unutmayın.")
    }
}

// MARK: - Ana şifre değiştirme

struct ChangeMasterView: View {
    @EnvironmentObject private var store: VaultStore
    @Environment(\.dismiss) private var dismiss
    @State private var current = ""
    @State private var new1 = ""
    @State private var new2 = ""
    @State private var busy = false
    @State private var error: String?

    var body: some View {
        Form {
            Section("Mevcut ana şifre") {
                SecureInput(placeholder: "Mevcut ana şifre", text: $current)
            }
            Section {
                SecureInput(placeholder: "Yeni şifre (en az 8 karakter)", text: $new1)
                SecureField("Yeni şifre (tekrar)", text: $new2)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                if !new1.isEmpty { StrengthBar(password: new1) }
            } header: {
                Text("Yeni ana şifre")
            } footer: {
                Text("Kasanız yeni şifreyle yeniden şifrelenir. Daha önce aldığınız yedekler eski şifreyle açılmaya devam eder; değişiklikten sonra yeni bir yedek almanız önerilir.")
            }
            if let error {
                Section { Text(error).foregroundColor(.kasaDanger) }
            }
            Section {
                Button {
                    submit()
                } label: {
                    HStack {
                        Spacer()
                        if busy { ProgressView() } else { Text("Ana şifreyi değiştir").fontWeight(.semibold) }
                        Spacer()
                    }
                }
                .disabled(busy)
            }
        }
        .navigationTitle("Ana şifre")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func submit() {
        error = nil
        guard !current.isEmpty else { error = "Mevcut şifreyi girin."; return }
        guard new1.count >= 8 else { error = "Yeni şifre en az 8 karakter olmalı."; return }
        guard new1 == new2 else { error = "Yeni şifreler eşleşmiyor."; return }
        guard Strength.of(new1).score >= 2 else { error = "Yeni şifre çok zayıf. Daha uzun veya karmaşık bir şifre seçin."; return }
        busy = true
        Task {
            do {
                try await store.changeMaster(current: current, new: new1)
                busy = false
                store.showToast("Ana şifre değiştirildi")
                dismiss()
            } catch {
                busy = false
                self.error = error.localizedDescription
                Haptics.error()
            }
        }
    }
}
