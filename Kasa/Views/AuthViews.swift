import SwiftUI
import UniformTypeIdentifiers
import LocalAuthentication

// MARK: - İlk kurulum

struct SetupView: View {
    @EnvironmentObject private var store: VaultStore
    @State private var wantsMaster = false
    @State private var password = ""
    @State private var confirm = ""
    @State private var hint = ""
    @State private var busy = false
    @State private var error: String?
    @State private var showImporter = false
    @State private var backupData: Data?
    @State private var backupPassword = ""
    @State private var showBackupPassword = false

    private let deviceAvailable = DeviceAuth.isAvailable
    private var needsMaster: Bool { !deviceAvailable || wantsMaster }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 22) {
                    hero
                    features
                    masterSection
                    if let error {
                        Text(error)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(Color.kasaDanger)
                            .multilineTextAlignment(.center)
                    }
                    Button {
                        submit()
                    } label: {
                        HStack(spacing: 10) {
                            if busy {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: deviceAvailable ? DeviceAuth.icon : "lock.fill")
                                Text(deviceAvailable ? "\(DeviceAuth.name) ile başla" : "Başla")
                            }
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(busy)

                    Button {
                        showImporter = true
                    } label: {
                        Label("Yedekten geri yükle", systemImage: "arrow.down.doc")
                            .font(.subheadline.weight(.semibold))
                    }
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 22)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json, .data]) { result in
            if case .success(let url) = result, let data = FileAccess.read(url) {
                backupData = data
                backupPassword = ""
                showBackupPassword = true
            }
        }
        .alert("Yedeğin şifresi", isPresented: $showBackupPassword) {
            SecureField("Şifre", text: $backupPassword)
            Button("Vazgeç", role: .cancel) {}
            Button("Geri yükle") { restore() }
        } message: {
            Text("Bu yedeği alırken kullandığınız şifreyi girin.")
        }
    }

    private var hero: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Color.kasaAccent.opacity(0.45), .clear], center: .center, startRadius: 10, endRadius: 110))
                    .frame(width: 220, height: 220)
                LogoView(size: 96)
            }
            .frame(height: 170)
            Text("\(AppInfo.name)'e hoş geldiniz")
                .font(.system(size: 30, weight: .bold))
                .multilineTextAlignment(.center)
            Text("Tüm şifreleriniz tek bir yerde. \(DeviceAuth.name) ile anında açılır, internet olmadan çalışır.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
    }

    private var features: some View {
        VStack(spacing: 0) {
            featureRow(DeviceAuth.icon, [Color(hex: 0x7C5CFF), Color(hex: 0x5B3DF5)], "\(DeviceAuth.name) ile otomatik giriş", "Uygulamayı açtığınızda şifre sormaz")
            Divider().padding(.leading, 62)
            featureRow("iphone", [Color(hex: 0x2FD58A), Color(hex: 0x13A866)], "Veriler yalnızca bu iPhone'da", "Şifreleriniz hiçbir sunucuya gönderilmez")
            Divider().padding(.leading, 62)
            featureRow("lock.shield.fill", [Color(hex: 0x4D9BFF), Color(hex: 0x2A6DF0)], "AES-256 şifreleme", "Bankaların kullandığı düzeyde koruma")
        }
        .card(padding: 6)
    }

    private func featureRow(_ icon: String, _ colors: [Color], _ title: String, _ subtitle: String) -> some View {
        HStack(spacing: 14) {
            IconBadge(systemName: icon, colors: colors, size: 38)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
    }

    @ViewBuilder
    private var masterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if deviceAvailable {
                Toggle(isOn: $wantsMaster.animation(.easeInOut(duration: 0.2))) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Kurtarma şifresi de belirle").font(.subheadline.weight(.semibold))
                        Text("Önerilir. Telefon değişirse ya da Face ID kullanılamazsa bu şifreyle açarsınız.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(.kasaAccent)
            } else {
                Label("iPhone'unuzda parola tanımlı olmadığı için bir ana şifre belirlemeniz gerekiyor.", systemImage: "info.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if needsMaster {
                VStack(spacing: 10) {
                    AuthField { SecureInput(placeholder: "Şifre (en az 8 karakter)", text: $password) }
                    if !password.isEmpty { StrengthBar(password: password).padding(.horizontal, 4) }
                    AuthField {
                        SecureField("Şifre (tekrar)", text: $confirm)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                    }
                    AuthField { TextField("İpucu (isteğe bağlı)", text: $hint) }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .card()
    }

    private func submit() {
        error = nil
        var master: String?
        let trimmedHint = hint.trimmingCharacters(in: .whitespaces)
        if needsMaster {
            guard password.count >= 8 else { error = "Şifre en az 8 karakter olmalı."; Haptics.error(); return }
            guard password == confirm else { error = "Şifreler eşleşmiyor."; Haptics.error(); return }
            guard Strength.of(password).score >= 2 else { error = "Bu şifre çok kolay tahmin edilir. Daha uzun bir şifre seçin."; Haptics.error(); return }
            if !trimmedHint.isEmpty && trimmedHint.lowercased().contains(password.lowercased()) {
                error = "İpucu şifrenin kendisini içeremez."; return
            }
            master = password
        }
        busy = true
        Task {
            do {
                if deviceAvailable {
                    // Face ID iznini ve çalıştığını en baştan doğrula
                    _ = try await DeviceAuth.authenticate(reason: "Şifrelerinizi Face ID ile korumak için")
                }
                try await store.createVault(masterPassword: master, hint: master == nil ? "" : trimmedHint)
                Toaster.shared.show("Hazırsınız! İlk şifrenizi ekleyin.")
            } catch let e as LAError where e.code == .userCancel || e.code == .appCancel || e.code == .systemCancel {
                // vazgeçildi
            } catch {
                self.error = error.localizedDescription
            }
            busy = false
        }
    }

    private func restore() {
        guard let data = backupData else { return }
        let pw = backupPassword
        Toaster.shared.busy = "Yedek çözülüyor…"
        Task {
            do {
                let n = try await store.restoreBackup(data: data, password: pw)
                Toaster.shared.busy = nil
                Toaster.shared.show("\(n) kayıt geri yüklendi")
            } catch {
                Toaster.shared.busy = nil
                Toaster.shared.show(error.localizedDescription, isError: true)
            }
        }
    }
}

// MARK: - Kilit ekranı

struct LockView: View {
    @EnvironmentObject private var store: VaultStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var password = ""
    @State private var error: String?
    @State private var busy = false
    @State private var attempts: CGFloat = 0
    @State private var showPasswordField = false
    @State private var revealPassword = false
    @State private var showHint = false
    @State private var showForgot = false
    @State private var showResetConfirm = false
    @State private var resetText = ""
    @State private var glow = false
    @FocusState private var focused: Bool

    private var canUseDevice: Bool { store.deviceUnlockEnabled || store.legacyBiometrics }
    private var passwordVisible: Bool { store.hasMaster && (showPasswordField || !canUseDevice) }

    var body: some View {
        ZStack {
            AppBackground()
            VStack(spacing: 20) {
                Spacer(minLength: 30)
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [Color.kasaAccent.opacity(0.5), .clear], center: .center, startRadius: 5, endRadius: 100))
                        .frame(width: 200, height: 200)
                        .scaleEffect(glow ? 1.08 : 0.92)
                        .opacity(glow ? 1 : 0.7)
                    LogoView(size: 92)
                }
                .frame(height: 170)
                VStack(spacing: 6) {
                    Text(AppInfo.name).font(.system(size: 32, weight: .bold))
                    Label("Kilitli", systemImage: "lock.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }

                if canUseDevice {
                    Button {
                        Task { await store.unlockWithDevice() }
                    } label: {
                        VStack(spacing: 10) {
                            ZStack {
                                Circle().fill(Color.surface)
                                Circle().strokeBorder(LinearGradient.kasa, lineWidth: 2)
                                if store.authInProgress {
                                    ProgressView()
                                } else {
                                    Image(systemName: DeviceAuth.icon)
                                        .font(.system(size: 34, weight: .regular))
                                        .foregroundStyle(LinearGradient.kasa)
                                }
                            }
                            .frame(width: 84, height: 84)
                            Text("\(DeviceAuth.name) ile aç").font(.subheadline.weight(.semibold))
                        }
                    }
                    .buttonStyle(PressableStyle())
                    .padding(.top, 12)
                }

                if passwordVisible {
                    VStack(spacing: 12) {
                        AuthField {
                            HStack(spacing: 8) {
                                Group {
                                    if revealPassword {
                                        TextField("Ana şifre", text: $password)
                                    } else {
                                        SecureField("Ana şifre", text: $password)
                                    }
                                }
                                .focused($focused)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                                .submitLabel(.go)
                                .onSubmit { submit() }
                                Button { revealPassword.toggle() } label: {
                                    Image(systemName: revealPassword ? "eye.slash" : "eye").foregroundStyle(.secondary)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        Button { submit() } label: {
                            if busy { ProgressView().tint(.white) } else { Text("Kilidi aç") }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(busy)
                    }
                    .modifier(ShakeEffect(animatableData: attempts))
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                } else if store.hasMaster {
                    Button("Ana şifreyle aç") {
                        withAnimation(.easeInOut(duration: 0.2)) { showPasswordField = true }
                        focused = true
                    }
                    .font(.subheadline.weight(.semibold))
                }

                if !store.hasMaster && !canUseDevice {
                    VStack(spacing: 10) {
                        Label("Bu iPhone'daki anahtar bulunamadı", systemImage: "exclamationmark.triangle.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.kasaWarn)
                        Text("Uygulama farklı bir Apple kimliğiyle yüklendiyse veya telefon sıfırlandıysa bu olabilir. Kasayı sıfırlayıp yedeğinizi geri yükleyin.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .card()
                }

                if let error {
                    Text(error)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.kasaDanger)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                HStack(spacing: 24) {
                    if store.hasMaster && !store.hint.isEmpty && passwordVisible {
                        Button { showHint = true } label: { Label("İpucu", systemImage: "lightbulb") }
                    }
                    if passwordVisible || !canUseDevice {
                        Button(store.hasMaster ? "Şifremi unuttum" : "Kasayı sıfırla") { showForgot = true }
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.subheadline.weight(.semibold))
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 24)
            .frame(maxWidth: 480)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { glow = true }
            if scenePhase == .active { store.autoUnlockIfPossible() }
            if !canUseDevice && store.hasMaster { focused = true }
        }
        .alert("İpucu", isPresented: $showHint) {
            Button("Tamam", role: .cancel) {}
        } message: { Text(store.hint) }
        .alert(store.hasMaster ? "Şifremi unuttum" : "Kasayı sıfırla", isPresented: $showForgot) {
            Button("Vazgeç", role: .cancel) {}
            Button("Kasayı sıfırla", role: .destructive) { resetText = ""; showResetConfirm = true }
        } message: {
            Text("Şifreler kurtarılamaz. Kasayı sıfırlayıp yeniden oluşturabilir, elinizde varsa yedeği geri yükleyebilirsiniz.")
        }
        .alert("Emin misiniz?", isPresented: $showResetConfirm) {
            TextField("SİL", text: $resetText)
            Button("Vazgeç", role: .cancel) {}
            Button("Sıfırla", role: .destructive) {
                if resetText.trimmingCharacters(in: .whitespaces).uppercased(with: Locale(identifier: "tr_TR")) == "SİL" {
                    store.wipe()
                    Toaster.shared.show("Kasa sıfırlandı")
                } else {
                    Toaster.shared.show("Onay metni hatalı, silinmedi", isError: true)
                }
            }
        } message: {
            Text("Bu iPhone'daki tüm kayıtlar silinecek. Onaylamak için SİL yazın.")
        }
    }

    private func submit() {
        let remaining = store.lockoutRemaining
        if remaining > 0 {
            error = "Çok fazla hatalı deneme. \(Int(remaining.rounded(.up))) sn sonra tekrar deneyin."
            Haptics.error()
            return
        }
        guard !password.isEmpty else { focused = true; return }
        busy = true
        error = nil
        let pw = password
        Task {
            do {
                try await store.unlock(password: pw)
            } catch {
                busy = false
                password = ""
                Haptics.error()
                withAnimation(.default) { attempts += 1 }
                let wait = store.lockoutRemaining
                if wait > 0 {
                    self.error = "Hatalı şifre. Güvenlik için \(Int(wait.rounded(.up))) sn beklemelisiniz."
                } else {
                    self.error = store.failCount >= 3 ? "Hatalı şifre (\(store.failCount). deneme)" : "Hatalı şifre"
                }
                focused = true
            }
        }
    }
}

enum FileAccess {
    /// Dosyalar uygulamasından seçilen dosyayı güvenli şekilde okur
    static func read(_ url: URL) -> Data? {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        return try? Data(contentsOf: url)
    }
}
