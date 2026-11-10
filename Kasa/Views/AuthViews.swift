import SwiftUI
import UniformTypeIdentifiers

// MARK: - İlk kurulum

struct SetupView: View {
    @EnvironmentObject private var store: VaultStore
    @State private var password = ""
    @State private var confirm = ""
    @State private var hint = ""
    @State private var busy = false
    @State private var error: String?
    @State private var showWeakAlert = false
    @State private var showImporter = false
    @State private var backupData: Data?
    @State private var backupPassword = ""
    @State private var showBackupPassword = false

    var body: some View {
        ZStack {
            AuthBackground()
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 14) {
                        LogoView(size: 88)
                        Text("Kasa'ya hoş geldiniz")
                            .font(.largeTitle.weight(.bold))
                            .multilineTextAlignment(.center)
                        Text("Tüm şifreleriniz tek bir ana şifreyle korunur. Veriler yalnızca bu iPhone'da, AES-256 ile şifrelenmiş olarak saklanır.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 36)
                    .padding(.bottom, 10)

                    fieldLabel("Ana şifre")
                    AuthField { SecureInput(placeholder: "En az 8 karakter", text: $password) }
                    StrengthBar(password: password)
                    fieldLabel("Ana şifre (tekrar)")
                    AuthField {
                        SecureField("Şifreyi tekrar girin", text: $confirm)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                    }
                    fieldLabel("İpucu (isteğe bağlı)")
                    AuthField { TextField("Şifrenin kendisini yazmayın", text: $hint) }

                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundColor(.kasaWarn)
                        Text("**Önemli:** Ana şifrenizi unutursanız verilerinizi kurtarmanın hiçbir yolu yoktur. Güçlü ama hatırlayabileceğiniz bir şifre seçin.")
                            .font(.footnote)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.kasaWarn.opacity(0.12)))

                    if let error {
                        Text(error).font(.footnote.weight(.semibold)).foregroundColor(.kasaDanger)
                    }

                    Button {
                        submit(force: false)
                    } label: {
                        if busy { ProgressView().tint(.white) } else { Text("Kasayı oluştur") }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(busy)
                    .padding(.top, 4)

                    Button {
                        showImporter = true
                    } label: {
                        Label("Yedekten geri yükle", systemImage: "square.and.arrow.down")
                            .font(.subheadline.weight(.semibold))
                    }
                    .padding(.vertical, 8)
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 30)
                .frame(maxWidth: 480)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .alert("Zayıf ana şifre", isPresented: $showWeakAlert) {
            Button("Değiştir", role: .cancel) {}
            Button("Yine de devam", role: .destructive) { submit(force: true) }
        } message: {
            Text("Bu şifre kolay tahmin edilebilir. Daha uzun bir şifre ya da birkaç kelimeden oluşan bir cümle öneririz.")
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json, .data]) { result in
            if case .success(let url) = result, let data = FileAccess.read(url) {
                backupData = data
                backupPassword = ""
                showBackupPassword = true
            }
        }
        .alert("Yedeğin şifresi", isPresented: $showBackupPassword) {
            SecureField("Ana şifre", text: $backupPassword)
            Button("Vazgeç", role: .cancel) {}
            Button("Geri yükle") { restore() }
        } message: {
            Text("Bu yedeği alırken kullandığınız ana şifreyi girin. Bu şifre yeni kasanızın ana şifresi olur.")
        }
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.footnote.weight(.semibold))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, 4)
            .padding(.bottom, -8)
    }

    private func submit(force: Bool) {
        error = nil
        let trimmedHint = hint.trimmingCharacters(in: .whitespaces)
        guard password.count >= 8 else { error = "Ana şifre en az 8 karakter olmalı."; Haptics.error(); return }
        guard password == confirm else { error = "Şifreler eşleşmiyor."; Haptics.error(); return }
        if !trimmedHint.isEmpty && trimmedHint.lowercased().contains(password.lowercased()) {
            error = "İpucu şifrenin kendisini içeremez."; return
        }
        if !force && Strength.of(password).score < 2 { showWeakAlert = true; return }
        busy = true
        Task {
            do {
                try await store.createVault(password: password, hint: trimmedHint)
                store.showToast("Kasanız hazır")
            } catch {
                self.error = error.localizedDescription
            }
            busy = false
        }
    }

    private func restore() {
        guard let data = backupData else { return }
        let pw = backupPassword
        store.busyMessage = "Yedek çözülüyor…"
        Task {
            do {
                let n = try await store.restoreBackup(data: data, password: pw)
                store.busyMessage = nil
                store.showToast("\(n) kayıt geri yüklendi")
            } catch {
                store.busyMessage = nil
                store.showToast(error.localizedDescription, isError: true)
            }
        }
    }
}

// MARK: - Kilit ekranı

struct LockView: View {
    @EnvironmentObject private var store: VaultStore
    @State private var password = ""
    @State private var error: String?
    @State private var busy = false
    @State private var attempts: CGFloat = 0
    @State private var showHint = false
    @State private var showForgot = false
    @State private var showResetConfirm = false
    @State private var resetText = ""
    @State private var showPassword = false
    @FocusState private var focused: Bool

    var body: some View {
        ZStack {
            AuthBackground()
            VStack(spacing: 18) {
                Spacer()
                LogoView(size: 88)
                VStack(spacing: 6) {
                    Text("Kasa kilitli").font(.largeTitle.weight(.bold))
                    Text("Devam etmek için ana şifrenizi girin.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 8)

                AuthField {
                    HStack(spacing: 8) {
                        Group {
                            if showPassword {
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
                        Button { showPassword.toggle() } label: {
                            Image(systemName: showPassword ? "eye.slash" : "eye").foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .font(.title3)
                }

                Button {
                    submit()
                } label: {
                    if busy { ProgressView().tint(.white) } else { Text("Kilidi aç") }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(busy)

                if store.biometricsEnabled && BiometricKeychain.isAvailable {
                    Button {
                        Task { await store.unlockWithBiometrics() }
                    } label: {
                        Label("\(BiometricKeychain.displayName) ile aç", systemImage: BiometricKeychain.iconName)
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }

                Text(error ?? " ")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.kasaDanger)
                    .multilineTextAlignment(.center)

                Spacer()

                HStack(spacing: 24) {
                    if !store.hint.isEmpty {
                        Button { showHint = true } label: { Label("İpucu", systemImage: "lightbulb") }
                    }
                    Button("Ana şifremi unuttum") { showForgot = true }
                        .foregroundColor(.secondary)
                }
                .font(.subheadline.weight(.semibold))
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 22)
            .frame(maxWidth: 480)
            .modifier(ShakeEffect(animatableData: attempts))
        }
        .task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            if store.biometricsEnabled {
                await store.unlockWithBiometrics()
            } else {
                focused = true
            }
        }
        .alert("İpucu", isPresented: $showHint) {
            Button("Tamam", role: .cancel) {}
        } message: { Text(store.hint) }
        .alert("Ana şifremi unuttum", isPresented: $showForgot) {
            Button("Vazgeç", role: .cancel) {}
            Button("Kasayı sıfırla", role: .destructive) { resetText = ""; showResetConfirm = true }
        } message: {
            Text("Ana şifre hiçbir yerde saklanmaz, bu yüzden kurtarılamaz. Kasayı sıfırlayıp yeniden oluşturabilir, elinizde varsa bir yedeği o yedeğin şifresiyle geri yükleyebilirsiniz.")
        }
        .alert("Emin misiniz?", isPresented: $showResetConfirm) {
            TextField("SİL", text: $resetText)
            Button("Vazgeç", role: .cancel) {}
            Button("Sıfırla", role: .destructive) {
                if resetText.trimmingCharacters(in: .whitespaces).uppercased(with: Locale(identifier: "tr_TR")) == "SİL" {
                    store.wipe()
                    store.showToast("Kasa sıfırlandı")
                } else {
                    store.showToast("Onay metni hatalı, silinmedi", isError: true)
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
                    self.error = store.failCount >= 3 ? "Hatalı ana şifre (\(store.failCount). deneme)" : "Hatalı ana şifre"
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
