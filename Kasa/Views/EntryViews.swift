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
            ZStack {
                AppBackground()
                Text("Kayıt bulunamadı").foregroundStyle(.secondary)
            }
        }
    }

    private func content(_ e: Entry) -> some View {
        ScrollView {
            VStack(spacing: 18) {
                hero(e)
                quickActions(e)
                fieldsCard(e)
                if !e.notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Notlar", systemImage: "note.text").font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                        Text(e.notes).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .card()
                }
                if !e.history.isEmpty { historyCard(e) }
                siblingsCard(e)
                VStack(spacing: 4) {
                    Text("Oluşturuldu: \(DateText.full(e.createdDate))")
                    Text("Son düzenleme: \(DateText.full(e.updatedDate))")
                    Text("Şifre son değişiklik: \(DateText.relative(e.pwChangedDate))")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                Button(role: .destructive) { confirmDelete = true } label: {
                    Label("Kaydı sil", systemImage: "trash").font(.headline).foregroundStyle(Color.kasaDanger)
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(PressableStyle())
                .card(padding: 0)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
        .background(AppBackground())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Düzenle") { editing = EditTarget(entry: e) }.fontWeight(.semibold)
            }
        }
        .sheet(item: $editing) { t in
            EntryEditView(original: t.entry, defaultCategory: t.entry?.category ?? t.template?.category ?? .genel, template: t.template)
        }
        .confirmationDialog("“\(e.title)” silinsin mi?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Kaydı sil", role: .destructive) {
                dismiss()
                store.delete(e.id)
            }
            Button("Vazgeç", role: .cancel) {}
        }
    }

    private func hero(_ e: Entry) -> some View {
        ZStack(alignment: .topTrailing) {
            BrandPalette.gradient(for: e)
            Circle().fill(Color.white.opacity(0.1)).frame(width: 240, height: 240).offset(x: 90, y: -110)
            Circle().fill(Color.white.opacity(0.07)).frame(width: 160, height: 160).offset(x: -200, y: 60)
            VStack(spacing: 12) {
                BrandAvatar(entry: e, size: 78)
                    .overlay(RoundedRectangle(cornerRadius: 78 * 0.3, style: .continuous).strokeBorder(Color.white.opacity(0.45), lineWidth: 1.5))
                    .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 5)
                Text(e.title)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    Pill(text: e.category.name, icon: e.category.icon)
                    if !e.host.isEmpty { Pill(text: e.host, icon: "globe") }
                }
            }
            .padding(.vertical, 26)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            Button { store.toggleFavorite(e.id) } label: {
                Image(systemName: e.favorite ? "star.fill" : "star")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.white.opacity(0.2)))
            }
            .buttonStyle(PressableStyle())
            .padding(14)
            .accessibilityLabel(e.favorite ? "Favorilerden çıkar" : "Favorilere ekle")
        }
        .foregroundStyle(.white)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .padding(.top, 4)
    }

    private func quickActions(_ e: Entry) -> some View {
        HStack(spacing: 10) {
            actionButton("person.fill", "Kullanıcı adı", enabled: !e.username.isEmpty) {
                Clipboard.copy(e.username); Toaster.shared.show("Kullanıcı adı kopyalandı")
            }
            actionButton("key.fill", "Şifre", enabled: !e.password.isEmpty) {
                Clipboard.copy(e.password); Toaster.shared.show("Şifre kopyalandı")
            }
            if let url = URLHelper.openable(e.url) {
                Link(destination: url) { actionLabel("safari.fill", "Siteyi aç") }
                    .buttonStyle(PressableStyle())
            } else {
                actionButton("safari.fill", "Siteyi aç", enabled: false) {}
            }
        }
    }

    private func actionButton(_ icon: String, _ title: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) { actionLabel(icon, title) }
            .buttonStyle(PressableStyle())
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.4)
    }

    private func actionLabel(_ icon: String, _ title: String) -> some View {
        VStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(LinearGradient.kasa)
            Text(title).font(.caption.weight(.semibold)).foregroundStyle(.primary).lineLimit(1)
        }
        .frame(maxWidth: .infinity, minHeight: 66)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.surface))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.hairline))
    }

    private func fieldsCard(_ e: Entry) -> some View {
        VStack(spacing: 0) {
            if !e.username.isEmpty {
                fieldRow(icon: "person.fill", label: "Kullanıcı adı") {
                    Text(e.username).textSelection(.enabled)
                } trailing: {
                    CopyButton(text: e.username, message: "Kullanıcı adı kopyalandı")
                }
            }
            if !e.password.isEmpty {
                if !e.username.isEmpty { Divider().padding(.leading, 60) }
                fieldRow(icon: "key.fill", label: "Şifre") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(revealed ? e.password : String(repeating: "•", count: min(e.password.count, 14)))
                            .font(.system(.body, design: .monospaced).weight(.medium))
                            .textSelection(.enabled)
                        StrengthBar(password: e.password)
                    }
                } trailing: {
                    HStack(spacing: 6) {
                        Button { withAnimation(.easeInOut(duration: 0.15)) { revealed.toggle() } } label: {
                            Image(systemName: revealed ? "eye.slash.fill" : "eye.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .frame(width: 38, height: 38)
                                .background(Circle().fill(Color.primary.opacity(0.06)))
                        }
                        .buttonStyle(PressableStyle())
                        CopyButton(text: e.password, message: "Şifre kopyalandı")
                    }
                }
            }
            if let cfg = TOTP.parse(e.totp) {
                Divider().padding(.leading, 60)
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    let code = TOTP.code(cfg, at: ctx.date)
                    fieldRow(icon: "number", label: "Doğrulama kodu (2FA)") {
                        Text(TOTP.formatted(code))
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundStyle(LinearGradient.kasa)
                    } trailing: {
                        HStack(spacing: 8) {
                            CountdownRing(remaining: TOTP.secondsRemaining(cfg, at: ctx.date), period: cfg.period)
                            CopyButton(text: code, message: "Doğrulama kodu kopyalandı")
                        }
                    }
                }
            } else if !e.totp.isEmpty {
                Divider().padding(.leading, 60)
                fieldRow(icon: "number", label: "Doğrulama kodu (2FA)") {
                    Text("Geçersiz anahtar").foregroundStyle(Color.kasaDanger)
                } trailing: { EmptyView() }
            }
            if !e.url.isEmpty {
                Divider().padding(.leading, 60)
                fieldRow(icon: "globe", label: "Web sitesi") {
                    Text(e.url).textSelection(.enabled).lineLimit(2)
                } trailing: {
                    CopyButton(text: e.url, message: "Adres kopyalandı")
                }
            }
            if e.username.isEmpty && e.password.isEmpty && e.url.isEmpty && e.totp.isEmpty {
                Text("Bu kayıtta giriş bilgisi yok.")
                    .foregroundStyle(.secondary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.surface))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color.hairline))
    }

    private func fieldRow<C: View, T: View>(icon: String, label: String,
                                            @ViewBuilder content: () -> C,
                                            @ViewBuilder trailing: () -> T) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.kasaAccent)
                .frame(width: 32, height: 32)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.kasaAccent.opacity(0.12)))
            VStack(alignment: .leading, spacing: 4) {
                Text(label).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                content()
            }
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }

    @ViewBuilder
    private func siblingsCard(_ e: Entry) -> some View {
        let others = store.siblings(of: e)
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(others.isEmpty ? "Bu servis" : "Bu servisteki diğer hesaplar (\(others.count))", systemImage: "person.2.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    editing = EditTarget(entry: nil, template: Entry(title: e.title, url: e.url, category: e.category))
                } label: {
                    Label("Hesap ekle", systemImage: "plus.circle.fill").font(.footnote.weight(.semibold))
                }
                .buttonStyle(.borderless)
            }
            .padding(.bottom, 4)
            ForEach(others) { o in
                NavigationLink(value: o.id) {
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.circle.fill").font(.title3).foregroundStyle(Color.kasaAccent.opacity(0.85))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(o.username.isEmpty ? o.title : o.username).font(.subheadline.weight(.semibold)).lineLimit(1)
                            if !o.username.isEmpty && o.title != e.title {
                                Text(o.title).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                .foregroundStyle(.primary)
            }
        }
        .card()
    }

    private func historyCard(_ e: Entry) -> some View {
        DisclosureGroup {
            VStack(spacing: 10) {
                ForEach(Array(e.history.enumerated()), id: \.offset) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(repeating: "•", count: 10)).font(.system(.body, design: .monospaced))
                            Text("\(DateText.full(Date(timeIntervalSince1970: item.element.changedAt / 1000))) tarihine kadar")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        CopyButton(text: item.element.password, message: "Eski şifre kopyalandı")
                    }
                }
            }
            .padding(.top, 10)
        } label: {
            Label("Önceki şifreler (\(e.history.count))", systemImage: "clock.arrow.circlepath")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .tint(.secondary)
        .card()
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
    @State private var showPassword: Bool
    @State private var showAdvanced: Bool
    @State private var confirmDiscard = false
    @State private var error: String?

    init(original: Entry?, defaultCategory: EntryCategory, template: Entry? = nil) {
        self.original = original
        var base = Entry(category: defaultCategory)
        if let t = template {
            base.title = t.title
            base.url = t.url
            base.category = t.category
        }
        let e = original ?? base
        _title = State(initialValue: e.title)
        _username = State(initialValue: e.username)
        _password = State(initialValue: e.password)
        _url = State(initialValue: e.url)
        _totp = State(initialValue: e.totp)
        _notes = State(initialValue: e.notes)
        _category = State(initialValue: e.category)
        _favorite = State(initialValue: e.favorite)
        _categoryTouched = State(initialValue: original != nil || defaultCategory != .genel || template != nil)
        _showPassword = State(initialValue: original == nil)
        _showAdvanced = State(initialValue: !e.totp.isEmpty)
    }

    private var hasChanges: Bool {
        let e = original ?? Entry()
        return title != e.title || username != e.username || password != e.password || url != e.url
            || totp != e.totp || notes != e.notes || favorite != e.favorite || (original != nil && category != e.category)
    }

    private var preview: Entry {
        Entry(title: title.isEmpty ? (URLHelper.host(url).isEmpty ? "?" : URLHelper.host(url)) : title, url: url, category: category)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        BrandAvatar(entry: preview, size: 54)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(title.isEmpty ? "Yeni şifre" : title).font(.headline).lineLimit(1)
                            Text(category.name).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color.clear)
                }

                Section("Hesap bilgileri") {
                    iconRow("textformat") {
                        TextField("Site veya uygulama adı (ör. Instagram)", text: $title)
                    }
                    if !suggestions.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(suggestions, id: \.title) { sug in
                                    Button { apply(sug) } label: {
                                        HStack(spacing: 6) {
                                            BrandAvatar(entry: Entry(title: sug.title, url: sug.url, category: sug.category), size: 22)
                                            Text(sug.title).font(.subheadline.weight(.semibold))
                                            if let n = sug.count { Text("\(n)").font(.caption.weight(.bold)).foregroundStyle(.secondary) }
                                        }
                                        .padding(.leading, 5)
                                        .padding(.trailing, 11)
                                        .frame(height: 32)
                                        .background(Capsule().fill(Color.primary.opacity(0.06)))
                                    }
                                    .buttonStyle(.borderless)
                                    .foregroundStyle(.primary)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                    }
                    iconRow("person.fill") {
                        TextField("Kullanıcı adı veya e-posta", text: $username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .keyboardType(.emailAddress)
                            .textContentType(.username)
                    }
                    VStack(spacing: 10) {
                        iconRow("key.fill") {
                            HStack(spacing: 10) {
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
                                    Image(systemName: showPassword ? "eye.slash" : "eye").foregroundStyle(.secondary)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        if !password.isEmpty { StrengthBar(password: password).padding(.leading, 44) }
                        Button {
                            password = PasswordGenerator.generate(Prefs.genOptions)
                            showPassword = true
                            Haptics.success()
                        } label: {
                            Label("Güçlü şifre üret", systemImage: "wand.and.stars")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(LinearGradient.kasa))
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(.vertical, 2)
                    iconRow("globe") {
                        TextField("Web sitesi (ör. instagram.com)", text: $url)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .keyboardType(.URL)
                    }
                }

                Section("Kategori") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(EntryCategory.allCases) { c in
                                Button {
                                    category = c
                                    categoryTouched = true
                                    Haptics.tap()
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: c.icon).font(.caption.weight(.semibold))
                                        Text(c.shortName).font(.subheadline.weight(.semibold))
                                    }
                                    .padding(.horizontal, 12)
                                    .frame(height: 36)
                                    .foregroundStyle(category == c ? Color.white : Color.primary)
                                    .background(
                                        Capsule().fill(category == c
                                                       ? AnyShapeStyle(LinearGradient(colors: c.colors, startPoint: .leading, endPoint: .trailing))
                                                       : AnyShapeStyle(Color.primary.opacity(0.06)))
                                    )
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 16)
                    }
                    .listRowInsets(EdgeInsets())
                }

                Section {
                    TextField("Notlar (güvenlik soruları, PIN, ek bilgiler…)", text: $notes, axis: .vertical)
                        .lineLimit(3...10)
                    Toggle(isOn: $favorite) {
                        Label("Favorilere ekle", systemImage: "star.fill")
                    }
                    .tint(.kasaAccent)
                } header: {
                    Text("Diğer")
                }

                Section {
                    DisclosureGroup(isExpanded: $showAdvanced) {
                        TextField("Kurulum anahtarı veya otpauth://", text: $totp)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled(true)
                            .font(.system(.body, design: .monospaced))
                        Text("Bir sitede iki adımlı doğrulamayı açarken gösterilen “kurulum anahtarını” girerseniz 6 haneli kodlar burada üretilir.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } label: {
                        Label("İki adımlı doğrulama (2FA)", systemImage: "number")
                    }
                }

                if let error {
                    Section { Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(Color.kasaDanger) }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle(original == nil ? "Yeni şifre" : "Düzenle")
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
            .onChange(of: url) { newValue in
                guard !categoryTouched, let c = CategoryGuess.guess(title: title, url: newValue) else { return }
                category = c
            }
        }
    }

    private struct Suggestion {
        let title: String
        let url: String
        let category: EntryCategory
        let count: Int?
    }

    /// Yazılan ada göre öneriler: önce kasadaki mevcut servisler, sonra bilinen servisler
    private var suggestions: [Suggestion] {
        let locale = Locale(identifier: "tr_TR")
        let q = title.trimmingCharacters(in: .whitespaces).lowercased(with: locale)
        guard q.count >= 2 else { return [] }
        var result: [Suggestion] = []
        var seen = Set<String>()
        var existing: [String: (Entry, Int)] = [:]
        for e in store.entries where e.id != original?.id {
            let name = ServiceCatalog.match(title: e.title, url: e.url)?.name ?? e.title
            let key = name.lowercased(with: locale)
            if let cur = existing[key] { existing[key] = (cur.0, cur.1 + 1) } else { existing[key] = (e, 1) }
        }
        for (key, value) in existing.sorted(by: { $0.key < $1.key }) where key.hasPrefix(q) && key != q {
            let name = ServiceCatalog.match(title: value.0.title, url: value.0.url)?.name ?? value.0.title
            result.append(Suggestion(title: name, url: value.0.url, category: value.0.category, count: value.1))
            seen.insert(key)
        }
        for s in ServiceCatalog.suggestions(for: q) {
            let key = s.name.lowercased(with: locale)
            if seen.contains(key) || key == q { continue }
            result.append(Suggestion(title: s.name, url: s.domain, category: s.category, count: nil))
            seen.insert(key)
        }
        return Array(result.prefix(8))
    }

    private func apply(_ s: Suggestion) {
        Haptics.tap()
        title = s.title
        if url.trimmingCharacters(in: .whitespaces).isEmpty { url = s.url }
        if !categoryTouched { category = s.category }
    }

    private func iconRow<C: View>(_ icon: String, @ViewBuilder content: () -> C) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.kasaAccent)
                .frame(width: 30, height: 30)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.kasaAccent.opacity(0.12)))
            content()
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
            guard TOTP.parse(key) != nil else { error = "2FA anahtarı geçersiz."; showAdvanced = true; Haptics.error(); return }
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
        Haptics.success()
        Toaster.shared.show(original == nil ? "Şifre kaydedildi" : "Değişiklikler kaydedildi")
        dismiss()
    }
}
