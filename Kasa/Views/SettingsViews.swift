import SwiftUI
import UniformTypeIdentifiers
import LocalAuthentication

struct SettingsView: View {
    @EnvironmentObject private var store: VaultStore
    @AppStorage(Prefs.autoLock) private var autoLock = 60
    @AppStorage(Prefs.clipboard) private var clipboard = 30
    @AppStorage(Prefs.theme) private var theme = 0
    @AppStorage(Prefs.siteIcons) private var siteIcons = true

    enum PasswordPurpose { case exportBackupMaster, exportBackupNew, importBackup, exportCSV }
    enum ImportMode { case backup, csv }

    @State private var passwordPurpose: PasswordPurpose?
    @State private var promptPassword = ""
    @State private var promptPassword2 = ""
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
            Form {
                headerSection
                lockSection
                Section("Düzen") {
                    NavigationLink {
                        FoldersSettingsView()
                    } label: {
                        rowLabel("folder.fill", [Color(hex: 0x6366F1), Color(hex: 0x4338CA)], "Klasörler",
                                 store.folders.isEmpty ? "Şifreleri kişilere göre ayırın" : "\(store.folders.count) klasör")
                    }
                }
                Section("Pano") {
                    Picker(selection: $clipboard) {
                        Text("15 saniye").tag(15)
                        Text("30 saniye").tag(30)
                        Text("1 dakika").tag(60)
                        Text("2 dakika").tag(120)
                        Text("Kapalı").tag(0)
                    } label: {
                        rowLabel("doc.on.clipboard.fill", [Color(hex: 0x2FD58A), Color(hex: 0x13A866)], "Panoyu temizle",
                                 "Kopyalanan şifre bu süre sonra silinir")
                    }
                }
                Section("Görünüm") {
                    Picker("Mod", selection: $theme) {
                        Text("Sistem").tag(0)
                        Text("Koyu").tag(1)
                        Text("Açık").tag(2)
                    }
                    .pickerStyle(.segmented)
                    PalettePicker()
                        .listRowInsets(EdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 0))
                }
                Section {
                    Toggle(isOn: $siteIcons) {
                        rowLabel("photo.on.rectangle.angled", [Color(hex: 0xFF8A50), Color(hex: 0xF25A22)], "Site logoları",
                                 "Instagram, Gmail gibi sitelerin logosunu göster")
                    }
                    .tint(.kasaAccent)
                    if siteIcons {
                        Button {
                            SiteIconStore.shared.clearAll()
                            Toaster.shared.show("Logolar yeniden indirilecek")
                        } label: {
                            rowLabel("arrow.clockwise", [Color(hex: 0x9A9AB0), Color(hex: 0x6E6E86)], "Logoları yenile")
                        }
                        .foregroundStyle(.primary)
                    }
                } footer: {
                    Text("Logo, sitenin kendisinden yalnızca bir kez indirilip bu iPhone'a kaydedilir; sonra internetsiz gösterilir. Şifreleriniz veya kullanıcı adlarınız hiçbir yere gönderilmez. Kapatırsanız uygulama hiç internete çıkmaz.")
                }
                backupSection
                Section {
                    Button(role: .destructive) { confirmWipe = true } label: {
                        rowLabel("trash.fill", [Color(hex: 0xFF6B7A), Color(hex: 0xE5364A)], "Tüm verileri sil")
                            .foregroundStyle(Color.kasaDanger)
                    }
                } header: { Text("Tehlikeli bölge") }
                aboutSection
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle("Ayarlar")
            .alert(passwordTitle, isPresented: Binding(get: { passwordPurpose != nil }, set: { if !$0 { passwordPurpose = nil } })) {
                SecureField(passwordPurpose == .exportBackupNew ? "Yedek şifresi" : "Şifre", text: $promptPassword)
                if passwordPurpose == .exportBackupNew {
                    SecureField("Yedek şifresi (tekrar)", text: $promptPassword2)
                }
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
                    askPassword(.importBackup)
                } else {
                    importCSV(data)
                }
            }
            .confirmationDialog("Şifresiz dışa aktarım", isPresented: $confirmCSV, titleVisibility: .visible) {
                Button("Anladım, devam et", role: .destructive) { startCSVExport() }
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
                            Toaster.shared.show(h.isEmpty ? "İpucu kaldırıldı" : "İpucu kaydedildi")
                        }
                    } message: {
                        Text("Kilit ekranında gösterilir ve şifrelenmez. Şifrenin kendisini yazmayın.")
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
                                Toaster.shared.show("Tüm veriler silindi")
                            } else {
                                Toaster.shared.show("Onay metni hatalı, silinmedi", isError: true)
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
                Text("Tüm şifreleriniz bu iPhone'dan kalıcı olarak silinecek. Bu işlem geri alınamaz.")
            }
        }
    }

    // MARK: Bölümler

    private var headerSection: some View {
        Section {
            HStack(spacing: 16) {
                LogoView(size: 58)
                VStack(alignment: .leading, spacing: 4) {
                    Text(AppInfo.name).font(.title3.weight(.bold))
                    Label("Veriler yalnızca bu iPhone'da", systemImage: "iphone")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    Label("\(store.entries.count) kayıt · AES-256 ile şifreli", systemImage: "lock.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 6)
        }
    }

    private var lockSection: some View {
        Section {
            if DeviceAuth.isAvailable {
                Toggle(isOn: Binding(get: { store.deviceUnlockEnabled }, set: { on in Task { await store.setDeviceUnlock(on) } })) {
                    rowLabel(DeviceAuth.icon, [Color(hex: 0x7C5CFF), Color(hex: 0x5B3DF5)], "\(DeviceAuth.name) ile otomatik aç",
                             "Uygulama açılınca şifre sormaz")
                }
                .tint(.kasaAccent)
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
                rowLabel("timer", [Color(hex: 0x4D9BFF), Color(hex: 0x2A6DF0)], "Otomatik kilit", "Uygulamadan çıktıktan sonra")
            }
            NavigationLink {
                MasterPasswordView()
            } label: {
                rowLabel("key.fill", [Color(hex: 0xFFB648), Color(hex: 0xF08A1C)], "Kurtarma şifresi",
                         store.hasMaster ? "Tanımlı" : "Tanımlı değil · önerilir")
            }
            if store.hasMaster {
                Button {
                    hintText = store.hint
                    showHintEditor = true
                } label: {
                    HStack {
                        rowLabel("lightbulb.fill", [Color(hex: 0x33D1E6), Color(hex: 0x119DB8)], "Şifre ipucu",
                                 store.hint.isEmpty ? "Tanımlı değil" : "Tanımlı")
                        Spacer()
                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                    }
                }
                .foregroundStyle(.primary)
            }
            Button { store.lock() } label: {
                rowLabel("lock.fill", [Color(hex: 0x9A9AB0), Color(hex: 0x6E6E86)], "Şimdi kilitle")
            }
            .foregroundStyle(.primary)
        } header: {
            Text("Kilit ve güvenlik")
        } footer: {
            if !store.hasMaster {
                Text("Kurtarma şifresi, telefon değiştiğinde veya uygulama farklı bir Apple kimliğiyle yeniden yüklendiğinde şifrelerinize erişmenizi sağlar.")
            }
        }
    }

    private var backupSection: some View {
        Section {
            Button {
                askPassword(store.hasMaster ? .exportBackupMaster : .exportBackupNew)
            } label: {
                rowLabel("externaldrive.fill.badge.plus", [Color(hex: 0x2FD58A), Color(hex: 0x13A866)], "Şifreli yedek al",
                         store.lastBackup == 0 ? "Henüz yedek alınmadı"
                         : "Son yedek: \(DateText.relative(Date(timeIntervalSince1970: store.lastBackup / 1000)))")
            }
            Button {
                importMode = .backup
                showImporter = true
            } label: {
                rowLabel("arrow.down.doc.fill", [Color(hex: 0x4D9BFF), Color(hex: 0x2A6DF0)], "Yedekten geri yükle",
                         "Kayıtlar mevcut şifrelerle birleştirilir")
            }
            Button {
                importMode = .csv
                showImporter = true
            } label: {
                rowLabel("tablecells.fill", [Color(hex: 0x8B6CFF), Color(hex: 0x5B3DF5)], "CSV içe aktar",
                         "iCloud Anahtar Zinciri, Chrome, Bitwarden…")
            }
            Button { confirmCSV = true } label: {
                rowLabel("square.and.arrow.up.fill", [Color(hex: 0xFF8A50), Color(hex: 0xF25A22)], "CSV dışa aktar",
                         "Şifresiz · dikkatli kullanın")
            }
        } header: {
            Text("Yedekleme ve aktarım")
        } footer: {
            Text("Yedek dosyası şifrelidir. Paylaşım menüsünden “Dosyalar'a Kaydet” › iCloud Drive'ı seçmeniz önerilir.")
        }
        .foregroundStyle(.primary)
    }

    private var aboutSection: some View {
        Section {
            VStack(spacing: 6) {
                Text("\(AppInfo.name) · Sürüm \(appVersion)").font(.footnote.weight(.semibold))
                Text("İnternet bağlantısı kullanmaz. AES-256-GCM şifreleme, anahtar iPhone'un Anahtar Zinciri'nde.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
        }
    }

    private func rowLabel(_ icon: String, _ colors: [Color], _ title: String, _ subtitle: String? = nil) -> some View {
        HStack(spacing: 12) {
            IconBadge(systemName: icon, colors: colors, size: 32)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                if let subtitle { Text(subtitle).font(.caption).foregroundStyle(.secondary) }
            }
        }
    }

    // MARK: İşlemler

    private func askPassword(_ purpose: PasswordPurpose) {
        promptPassword = ""
        promptPassword2 = ""
        passwordPurpose = purpose
    }

    private var passwordTitle: String {
        switch passwordPurpose {
        case .importBackup: return "Yedeğin şifresi"
        case .exportBackupNew: return "Yedek şifresi belirleyin"
        default: return "Kurtarma şifreniz"
        }
    }

    private var passwordMessage: String {
        switch passwordPurpose {
        case .exportBackupMaster: return "Yedek, kurtarma şifrenizle şifrelenir."
        case .exportBackupNew: return "Bu şifreyi unutmayın; yedeği geri yüklerken gerekecek. En az 8 karakter."
        case .importBackup: return "Bu yedeği alırken kullandığınız şifreyi girin."
        case .exportCSV: return "Güvenliğiniz için kurtarma şifrenizi doğrulayın."
        case .none: return ""
        }
    }

    private func handlePassword() {
        guard let purpose = passwordPurpose else { return }
        let pw = promptPassword
        let pw2 = promptPassword2
        promptPassword = ""
        promptPassword2 = ""
        passwordPurpose = nil
        guard !pw.isEmpty else { return }
        switch purpose {
        case .exportBackupNew:
            guard pw.count >= 8 else { Toaster.shared.show("Yedek şifresi en az 8 karakter olmalı", isError: true); return }
            guard pw == pw2 else { Toaster.shared.show("Şifreler eşleşmiyor", isError: true); return }
            exportBackup(pw)
        case .exportBackupMaster:
            exportBackup(pw)
        case .importBackup:
            guard let data = pendingBackup else { return }
            pendingBackup = nil
            Toaster.shared.busy = "Yedek çözülüyor…"
            Task {
                do {
                    let r = try await store.mergeBackup(data: data, password: pw)
                    Toaster.shared.busy = nil
                    Toaster.shared.show(r.added + r.updated == 0 ? "Yeni kayıt bulunamadı" : "\(r.added) yeni, \(r.updated) güncellenmiş kayıt")
                } catch {
                    Toaster.shared.busy = nil
                    Toaster.shared.show(error.localizedDescription, isError: true)
                }
            }
        case .exportCSV:
            Toaster.shared.busy = "Doğrulanıyor…"
            Task {
                let ok = await store.verifyMaster(pw)
                Toaster.shared.busy = nil
                guard ok else { Toaster.shared.show("Şifre hatalı", isError: true); return }
                shareCSV()
            }
        }
    }

    private func exportBackup(_ pw: String) {
        Toaster.shared.busy = "Yedek hazırlanıyor…"
        Task {
            do {
                let url = try await store.makeBackup(password: pw)
                Toaster.shared.busy = nil
                ShareHelper.share(url: url, deleteAfter: true) { done in
                    if done { Toaster.shared.show("Yedek kaydedildi") }
                }
            } catch {
                Toaster.shared.busy = nil
                Toaster.shared.show(error.localizedDescription, isError: true)
            }
        }
    }

    private func startCSVExport() {
        if store.hasMaster {
            askPassword(.exportCSV)
            return
        }
        Task {
            do {
                _ = try await DeviceAuth.authenticate(reason: "Şifreleri dışa aktarmak için")
                shareCSV()
            } catch let e as LAError where e.code == .userCancel {
                // vazgeçildi
            } catch {
                Toaster.shared.show(error.localizedDescription, isError: true)
            }
        }
    }

    private func shareCSV() {
        do {
            let url = try store.exportCSV()
            ShareHelper.share(url: url, deleteAfter: true)
        } catch {
            Toaster.shared.show(error.localizedDescription, isError: true)
        }
    }

    private func importCSV(_ data: Data) {
        guard let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .windowsCP1254) else {
            Toaster.shared.show("Dosya okunamadı", isError: true)
            return
        }
        guard let r = store.importCSV(text) else {
            Toaster.shared.show("Dosyada “password” sütunu bulunamadı", isError: true)
            return
        }
        Toaster.shared.show("\(r.added) kayıt içe aktarıldı" + (r.skipped > 0 ? ", \(r.skipped) atlandı" : "") + ". CSV dosyasını silmeyi unutmayın.")
    }
}

// MARK: - Renk teması seçici

struct PalettePicker: View {
    @AppStorage(Prefs.palette) private var paletteRaw = "gece"

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Renk teması").font(.subheadline.weight(.semibold)).padding(.horizontal, 16)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 14) {
                    ForEach(Palette.allCases) { p in
                        Button {
                            Haptics.tap()
                            Theme.set(p)
                        } label: {
                            VStack(spacing: 6) {
                                ZStack {
                                    Circle()
                                        .fill(LinearGradient(colors: p.gradientColors, startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .frame(width: 46, height: 46)
                                    if paletteRaw == p.rawValue {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundStyle(.white)
                                    }
                                }
                                .overlay(Circle().strokeBorder(paletteRaw == p.rawValue ? Color.primary.opacity(0.5) : Color.clear, lineWidth: 2).padding(-4))
                                Text(p.name)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(paletteRaw == p.rawValue ? Color.primary : Color.secondary)
                            }
                            .frame(width: 66)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }
        }
    }
}

// MARK: - Kurtarma şifresi

struct MasterPasswordView: View {
    @EnvironmentObject private var store: VaultStore
    @Environment(\.dismiss) private var dismiss
    @State private var current = ""
    @State private var new1 = ""
    @State private var new2 = ""
    @State private var busy = false
    @State private var error: String?
    @State private var confirmRemove = false

    var body: some View {
        Form {
            Section {
                HStack(alignment: .top, spacing: 14) {
                    IconBadge(systemName: "key.fill", colors: [Color(hex: 0xFFB648), Color(hex: 0xF08A1C)], size: 40)
                    Text(store.hasMaster
                         ? "Kurtarma şifreniz tanımlı. Face ID kullanılamadığında veya telefon değiştiğinde bu şifreyle açabilirsiniz."
                         : "Face ID ile açma her gün için yeterli. Kurtarma şifresi; telefon değiştiğinde, sıfırlandığında veya uygulama başka bir Apple kimliğiyle yüklendiğinde şifrelerinize erişmenizi sağlar.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            if store.hasMaster {
                Section("Mevcut şifre") {
                    SecureInput(placeholder: "Mevcut kurtarma şifresi", text: $current)
                }
            }

            Section {
                SecureInput(placeholder: "Yeni şifre (en az 8 karakter)", text: $new1)
                SecureField("Yeni şifre (tekrar)", text: $new2)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                if !new1.isEmpty { StrengthBar(password: new1) }
            } header: {
                Text(store.hasMaster ? "Yeni şifre" : "Kurtarma şifresi belirle")
            }

            if let error {
                Section { Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(Color.kasaDanger) }
            }

            Section {
                Button { submit() } label: {
                    HStack {
                        Spacer()
                        if busy { ProgressView() } else { Text(store.hasMaster ? "Şifreyi değiştir" : "Kurtarma şifresini kaydet").fontWeight(.semibold) }
                        Spacer()
                    }
                }
                .disabled(busy)
            }

            if store.hasMaster && store.deviceUnlockEnabled {
                Section {
                    Button(role: .destructive) { confirmRemove = true } label: {
                        HStack { Spacer(); Text("Kurtarma şifresini kaldır"); Spacer() }
                    }
                    .disabled(busy)
                } footer: {
                    Text("Kaldırırsanız uygulama yalnızca \(DeviceAuth.name) / iPhone parolasıyla açılır.")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppBackground())
        .navigationTitle("Kurtarma şifresi")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("Kurtarma şifresi kaldırılsın mı?", isPresented: $confirmRemove, titleVisibility: .visible) {
            Button("Kaldır", role: .destructive) { remove() }
            Button("Vazgeç", role: .cancel) {}
        } message: {
            Text("Mevcut şifrenizi yukarıya girmiş olmanız gerekir.")
        }
    }

    private func submit() {
        error = nil
        if store.hasMaster && current.isEmpty { error = "Mevcut şifreyi girin."; return }
        guard new1.count >= 8 else { error = "Yeni şifre en az 8 karakter olmalı."; return }
        guard new1 == new2 else { error = "Şifreler eşleşmiyor."; return }
        guard Strength.of(new1).score >= 2 else { error = "Bu şifre çok kolay tahmin edilir. Daha uzun bir şifre seçin."; return }
        busy = true
        Task {
            do {
                try await store.setMaster(current: store.hasMaster ? current : nil, new: new1)
                busy = false
                Toaster.shared.show("Kurtarma şifresi kaydedildi")
                dismiss()
            } catch {
                busy = false
                self.error = error.localizedDescription
                Haptics.error()
            }
        }
    }

    private func remove() {
        error = nil
        guard !current.isEmpty else { error = "Kaldırmak için mevcut şifreyi girin."; return }
        busy = true
        Task {
            do {
                try await store.removeMaster(current: current)
                busy = false
                Toaster.shared.show("Kurtarma şifresi kaldırıldı")
                dismiss()
            } catch {
                busy = false
                self.error = error.localizedDescription
            }
        }
    }
}
