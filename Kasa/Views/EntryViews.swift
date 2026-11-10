import SwiftUI

// MARK: - Kayıt detayı

struct EntryDetailView: View {
    @EnvironmentObject private var store: VaultStore
    @Environment(\.dismiss) private var dismiss
    let entryID: String
    @State private var revealed = false
    @State private var editing: EditTarget?
    @State private var confirmDelete = false

    var body: some View {
        if let e = store.entry(entryID) {
            content(e)
        } else {
            Text("Kayıt bulunamadı").foregroundColor(.secondary)
        }
    }

    private func content(_ e: Entry) -> some View {
        List {
            Section {
                VStack(spacing: 10) {
                    AvatarView(entry: e, size: 76)
                        .shadow(color: e.category.color.opacity(0.35), radius: 14, x: 0, y: 8)
                    Text(e.title)
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)
                    Text(e.category.name)
                        .font(.caption.weight(.bold))
                        .foregroundColor(e.category.color)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(e.category.color.opacity(0.15)))
                    Button {
                        store.toggleFavorite(e.id)
                    } label: {
                        Label(e.favorite ? "Favorilerde" : "Favorilere ekle", systemImage: e.favorite ? "star.fill" : "star")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(e.favorite ? .kasaWarn : .secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color(.secondarySystemGroupedBackground)))
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            Section {
                if !e.username.isEmpty {
                    field(label: "Kullanıcı adı") {
                        Text(e.username).textSelection(.enabled)
                    } actions: {
                        copyButton(e.username, "Kullanıcı adı kopyalandı")
                    }
                }
                if !e.password.isEmpty {
                    field(label: "Şifre") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(revealed ? e.password : String(repeating: "•", count: min(e.password.count, 14)))
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                            StrengthBar(password: e.password, showLabel: false).frame(width: 100)
                        }
                    } actions: {
                        Button { revealed.toggle() } label: {
                            Image(systemName: revealed ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.borderless)
                        copyButton(e.password, "Şifre kopyalandı")
                    }
                }
                if let cfg = TOTP.parse(e.totp) {
                    TimelineView(.periodic(from: .now, by: 1)) { ctx in
                        let code = TOTP.code(cfg, at: ctx.date)
                        field(label: "Doğrulama kodu (2FA)") {
                            Text(TOTP.formatted(code))
                                .font(.system(size: 28, weight: .bold, design: .monospaced))
                                .foregroundColor(.kasaAccent)
                        } actions: {
                            CountdownRing(remaining: TOTP.secondsRemaining(cfg, at: ctx.date), period: cfg.period)
                            Button {
                                Clipboard.copy(TOTP.code(cfg))
                                store.showToast("Doğrulama kodu kopyalandı")
                            } label: { Image(systemName: "doc.on.doc") }
                            .buttonStyle(.borderless)
                        }
                    }
                } else if !e.totp.isEmpty {
                    field(label: "Doğrulama kodu (2FA)") {
                        Text("Geçersiz anahtar").foregroundColor(.kasaDanger)
                    } actions: { EmptyView() }
                }
                if !e.url.isEmpty {
                    field(label: "Web sitesi") {
                        Text(e.host).textSelection(.enabled)
                    } actions: {
                        if let url = URLHelper.openable(e.url) {
                            Link(destination: url) { Image(systemName: "arrow.up.right.square") }
                                .buttonStyle(.borderless)
                        }
                        copyButton(e.url, "Adres kopyalandı")
                    }
                }
                if e.username.isEmpty && e.password.isEmpty && e.url.isEmpty && e.totp.isEmpty {
                    Text("Bu kayıtta giriş bilgisi yok.").foregroundColor(.secondary)
                }
            }

            if !e.notes.isEmpty {
                Section("Notlar") {
                    Text(e.notes).textSelection(.enabled)
                }
            }

            if !e.history.isEmpty {
                Section {
                    DisclosureGroup("Önceki şifreler (\(e.history.count))") {
                        ForEach(Array(e.history.enumerated()), id: \.offset) { item in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(String(repeating: "•", count: 10)).font(.system(.body, design: .monospaced))
                                    Text("\(DateText.full(Date(timeIntervalSince1970: item.element.changedAt / 1000))) tarihine kadar")
                                        .font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                copyButton(item.element.password, "Eski şifre kopyalandı")
                            }
                        }
                    }
                } header: { Text("Geçmiş") }
            }

            Section {
                Button(role: .destructive) { confirmDelete = true } label: {
                    Label("Kaydı sil", systemImage: "trash").frame(maxWidth: .infinity)
                }
            } footer: {
                VStack(spacing: 3) {
                    Text("Oluşturuldu: \(DateText.full(e.createdDate))")
                    Text("Son düzenleme: \(DateText.full(e.updatedDate))")
                    Text("Şifre son değişiklik: \(DateText.relative(e.pwChangedDate))")
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
            }
        }
        .listStyle(.insetGrouped)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Düzenle") { editing = EditTarget(entry: e) }.fontWeight(.semibold)
            }
        }
        .sheet(item: $editing) { t in
            EntryEditView(original: t.entry, defaultCategory: t.entry?.category ?? .genel)
        }
        .confirmationDialog("“\(e.title)” silinsin mi?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Kaydı sil", role: .destructive) {
                dismiss()
                store.delete(e.id)
            }
            Button("Vazgeç", role: .cancel) {}
        }
    }

    private func field<C: View, A: View>(label: String, @ViewBuilder content: () -> C, @ViewBuilder actions: () -> A) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(label).font(.caption.weight(.semibold)).foregroundColor(.secondary)
                content()
            }
            Spacer(minLength: 8)
            actions()
        }
        .padding(.vertical, 4)
        .font(.body)
        .imageScale(.large)
    }

    private func copyButton(_ text: String, _ message: String) -> some View {
        Button {
            Clipboard.copy(text)
            store.showToast(message)
        } label: { Image(systemName: "doc.on.doc") }
        .buttonStyle(.borderless)
        .accessibilityLabel("Kopyala")
    }
}

// MARK: - Kayıt ekleme / düzenleme

struct EntryEditView: View {
    @EnvironmentObject private var store: VaultStore
    @Environment(\.dismiss) private var dismiss
    let original: Entry?

    @State private var title: String
    @State private var username: String
    @State private var password: String
    @State private var url: String
    @State private var totp: String
    @State private var notes: String
    @State private var category: EntryCategory
    @State private var favorite: Bool
    @State private var categoryTouched: Bool
    @State private var showPassword = false
    @State private var confirmDiscard = false
    @State private var error: String?

    init(original: Entry?, defaultCategory: EntryCategory) {
        self.original = original
        let e = original ?? Entry(category: defaultCategory)
        _title = State(initialValue: e.title)
        _username = State(initialValue: e.username)
        _password = State(initialValue: e.password)
        _url = State(initialValue: e.url)
        _totp = State(initialValue: e.totp)
        _notes = State(initialValue: e.notes)
        _category = State(initialValue: e.category)
        _favorite = State(initialValue: e.favorite)
        _categoryTouched = State(initialValue: original != nil || defaultCategory != .genel)
    }

    private var hasChanges: Bool {
        let e = original ?? Entry()
        return title != e.title || username != e.username || password != e.password || url != e.url
            || totp != e.totp || notes != e.notes || favorite != e.favorite || (original != nil && category != e.category)
    }

    private var categoryBinding: Binding<EntryCategory> {
        Binding(get: { category }, set: { category = $0; categoryTouched = true })
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Giriş bilgileri") {
                    LabeledContent("Başlık") {
                        TextField("ör. Instagram", text: $title)
                            .multilineTextAlignment(.leading)
                    }
                    LabeledContent("Kullanıcı adı") {
                        TextField("E-posta veya kullanıcı adı", text: $username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .keyboardType(.emailAddress)
                            .textContentType(.username)
                    }
                    VStack(spacing: 10) {
                        LabeledContent("Şifre") {
                            HStack(spacing: 12) {
                                Group {
                                    if showPassword {
                                        TextField("Şifre", text: $password)
                                    } else {
                                        SecureField("Şifre", text: $password)
                                    }
                                }
                                .font(.system(.body, design: .monospaced))
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                                .textContentType(.newPassword)
                                Button { showPassword.toggle() } label: {
                                    Image(systemName: showPassword ? "eye.slash" : "eye").foregroundColor(.secondary)
                                }
                                .buttonStyle(.borderless)
                                Button {
                                    password = PasswordGenerator.generate(Prefs.genOptions)
                                    showPassword = true
                                    Haptics.success()
                                } label: {
                                    Image(systemName: "wand.and.stars").foregroundColor(.kasaAccent)
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Güçlü şifre üret")
                            }
                        }
                        if !password.isEmpty { StrengthBar(password: password) }
                    }
                    LabeledContent("Web sitesi") {
                        TextField("ör. instagram.com", text: $url)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .keyboardType(.URL)
                    }
                    Picker("Kategori", selection: categoryBinding) {
                        ForEach(EntryCategory.allCases) { c in
                            Label(c.name, systemImage: c.icon).tag(c)
                        }
                    }
                }

                Section {
                    LabeledContent("2FA anahtarı") {
                        TextField("Kurulum anahtarı veya otpauth://", text: $totp)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled(true)
                    }
                } header: {
                    Text("İki adımlı doğrulama (isteğe bağlı)")
                } footer: {
                    Text("Bir sitede iki adımlı doğrulamayı açarken gösterilen “kurulum anahtarını” girerseniz Kasa 6 haneli kodları sizin için üretir.")
                }

                Section("Notlar") {
                    TextField("Güvenlik soruları, PIN kodu, ek bilgiler…", text: $notes, axis: .vertical)
                        .lineLimit(4...12)
                }

                Section {
                    Toggle(isOn: $favorite) { Label("Favorilere ekle", systemImage: "star.fill") }
                }

                if let error {
                    Section { Text(error).foregroundColor(.kasaDanger) }
                }
            }
            .navigationTitle(original == nil ? "Yeni kayıt" : "Kaydı düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Vazgeç") { if hasChanges { confirmDiscard = true } else { dismiss() } }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { save() }.fontWeight(.bold)
                }
            }
            .interactiveDismissDisabled(hasChanges)
            .confirmationDialog("Değişiklikler kaydedilmedi", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("Kaydetmeden çık", role: .destructive) { dismiss() }
                Button("Düzenlemeye dön", role: .cancel) {}
            }
            .onChange(of: title) { newValue in
                guard !categoryTouched else { return }
                category = CategoryGuess.guess(title: newValue, url: url) ?? .genel
            }
        }
    }

    private func save() {
        var t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let u = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let link = url.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { t = URLHelper.host(link) }
        if t.isEmpty { t = u }
        guard !t.isEmpty else { error = "Lütfen bir başlık girin."; Haptics.error(); return }
        var key = totp.trimmingCharacters(in: .whitespacesAndNewlines)
        if !key.isEmpty {
            if !key.lowercased().hasPrefix("otpauth:") {
                key = key.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "-", with: "").uppercased()
            }
            guard TOTP.parse(key) != nil else { error = "2FA anahtarı geçersiz."; Haptics.error(); return }
        }
        var e = original ?? Entry()
        e.title = t
        e.username = u
        e.password = password
        e.url = link
        e.totp = key
        e.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        e.category = category
        e.favorite = favorite
        store.upsert(e)
        store.showToast(original == nil ? "Kayıt eklendi" : "Değişiklikler kaydedildi")
        dismiss()
    }
}
