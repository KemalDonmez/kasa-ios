import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var store: VaultStore

    var body: some View {
        TabView(selection: $store.selectedTab) {
            VaultListView()
                .tabItem { Label("Kasa", systemImage: "key.fill") }
                .tag(AppTab.vault)
            GeneratorView()
                .tabItem { Label("Üretici", systemImage: "wand.and.stars") }
                .tag(AppTab.generator)
            SecurityView()
                .tabItem { Label("Güvenlik", systemImage: "checkmark.shield.fill") }
                .tag(AppTab.security)
            SettingsView()
                .tabItem { Label("Ayarlar", systemImage: "gearshape.fill") }
                .tag(AppTab.settings)
        }
    }
}

enum VaultFilter: Hashable {
    case all
    case favorites
    case category(EntryCategory)
}

struct EntryGroup: Identifiable {
    let id: String
    var items: [Entry]
}

struct EditTarget: Identifiable {
    let id = UUID()
    let entry: Entry?
}

struct VaultListView: View {
    @EnvironmentObject private var store: VaultStore
    @AppStorage(Prefs.sort) private var sort = "az"
    @State private var query = ""
    @State private var filter: VaultFilter = .all
    @State private var editing: EditTarget?
    @State private var showImporter = false
    @State private var pendingDelete: Entry?

    private var filtered: [Entry] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased(with: Locale(identifier: "tr_TR"))
        var list = store.entries.filter { e in
            switch filter {
            case .all: break
            case .favorites: if !e.favorite { return false }
            case .category(let c): if e.category != c { return false }
            }
            if q.isEmpty { return true }
            return [e.title, e.username, e.url, e.notes].contains { $0.lowercased(with: Locale(identifier: "tr_TR")).contains(q) }
        }
        if sort == "recent" {
            list.sort { $0.updatedAt > $1.updatedAt }
        } else {
            list.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
        return list
    }

    private var groups: [EntryGroup] {
        var result: [EntryGroup] = []
        for e in filtered {
            var k = e.initial
            if k.rangeOfCharacter(from: .letters) == nil { k = "#" }
            if let i = result.firstIndex(where: { $0.id == k }) {
                result[i].items.append(e)
            } else {
                result.append(EntryGroup(id: k, items: [e]))
            }
        }
        return result
    }

    private var presentCategories: [EntryCategory] {
        EntryCategory.allCases.filter { c in store.entries.contains { $0.category == c } }
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.entries.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("Kasa")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { store.lock() } label: { Image(systemName: "lock.fill") }
                        .accessibilityLabel("Kilitle")
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    if !store.entries.isEmpty {
                        Menu {
                            Picker("Sıralama", selection: $sort) {
                                Label("A → Z", systemImage: "textformat").tag("az")
                                Label("Son değiştirilen", systemImage: "clock").tag("recent")
                            }
                        } label: { Image(systemName: "arrow.up.arrow.down") }
                    }
                    Button { editing = EditTarget(entry: nil) } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Yeni kayıt")
                }
            }
            .navigationDestination(for: String.self) { id in
                EntryDetailView(entryID: id)
            }
            .sheet(item: $editing) { target in
                EntryEditView(original: target.entry, defaultCategory: defaultCategory)
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.commaSeparatedText, .plainText, .data]) { result in
                if case .success(let url) = result { importCSV(url) }
            }
            .confirmationDialog("Kayıt silinsin mi?", isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                                titleVisibility: .visible, presenting: pendingDelete) { e in
                Button("“\(e.title)” kaydını sil", role: .destructive) { store.delete(e.id) }
                Button("Vazgeç", role: .cancel) {}
            }
        }
    }

    private var defaultCategory: EntryCategory {
        if case .category(let c) = filter { return c }
        return .genel
    }

    private var list: some View {
        List {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(title: "Tümü", count: store.entries.count, selected: filter == .all) { filter = .all }
                        let favs = store.entries.filter(\.favorite).count
                        if favs > 0 {
                            FilterChip(title: "★ Favoriler", count: favs, selected: filter == .favorites) { filter = .favorites }
                        }
                        ForEach(presentCategories) { c in
                            FilterChip(title: c.name, count: store.entries.filter { $0.category == c }.count, color: c.color,
                                       selected: filter == .category(c)) { filter = .category(c) }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 2)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            if filtered.isEmpty {
                Section {
                    VStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").font(.largeTitle).foregroundColor(.secondary)
                        Text(query.isEmpty ? "Bu filtrede kayıt yok" : "“\(query)” için sonuç bulunamadı")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                    .listRowBackground(Color.clear)
                }
            } else if sort == "az" && query.isEmpty {
                ForEach(groups) { group in
                    Section(group.id) {
                        ForEach(group.items) { e in row(e) }
                    }
                }
            } else {
                Section(query.isEmpty ? "Son değiştirilenler" : "\(filtered.count) sonuç") {
                    ForEach(filtered) { e in row(e) }
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Başlık, kullanıcı adı veya site")
        .autocorrectionDisabled(true)
        .textInputAutocapitalization(.never)
        .overlay(alignment: .bottomTrailing) {
            Button { editing = EditTarget(entry: nil) } label: {
                Image(systemName: "plus")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 60, height: 60)
                    .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(LinearGradient.kasa))
                    .shadow(color: Color.kasaAccent.opacity(0.45), radius: 14, x: 0, y: 8)
            }
            .padding(20)
            .accessibilityLabel("Yeni kayıt")
        }
    }

    private func row(_ e: Entry) -> some View {
        NavigationLink(value: e.id) {
            EntryRow(entry: e)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) { pendingDelete = e } label: { Label("Sil", systemImage: "trash") }
            Button {
                Clipboard.copy(e.password)
                store.showToast("Şifre kopyalandı")
            } label: { Label("Şifre", systemImage: "doc.on.doc") }
            .tint(.kasaAccent)
        }
        .swipeActions(edge: .leading) {
            Button { store.toggleFavorite(e.id) } label: {
                Label(e.favorite ? "Favoriden çıkar" : "Favori", systemImage: e.favorite ? "star.slash" : "star.fill")
            }
            .tint(.kasaWarn)
        }
        .contextMenu {
            if !e.username.isEmpty {
                Button { Clipboard.copy(e.username); store.showToast("Kullanıcı adı kopyalandı") } label: {
                    Label("Kullanıcı adını kopyala", systemImage: "person")
                }
            }
            if !e.password.isEmpty {
                Button { Clipboard.copy(e.password); store.showToast("Şifre kopyalandı") } label: {
                    Label("Şifreyi kopyala", systemImage: "key")
                }
            }
            if let url = URLHelper.openable(e.url) {
                Link(destination: url) { Label("Siteyi aç", systemImage: "safari") }
            }
            Button { editing = EditTarget(entry: e) } label: { Label("Düzenle", systemImage: "pencil") }
            Button(role: .destructive) { pendingDelete = e } label: { Label("Sil", systemImage: "trash") }
        }
    }

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 30, style: .continuous).fill(LinearGradient.kasa)
                    Image(systemName: "checkmark.shield.fill").font(.system(size: 44)).foregroundColor(.white)
                }
                .frame(width: 96, height: 96)
                .shadow(color: Color.kasaAccent.opacity(0.4), radius: 20, x: 0, y: 12)
                .padding(.top, 60)
                Text("Kasanız boş").font(.title2.weight(.bold))
                Text("İlk şifrenizi ekleyin. Tüm kayıtlar bu iPhone'da şifrelenmiş olarak saklanır.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                    .padding(.bottom, 8)
                Button { editing = EditTarget(entry: nil) } label: { Label("İlk kaydı ekle", systemImage: "plus") }
                    .buttonStyle(PrimaryButtonStyle())
                    .frame(maxWidth: 300)
                Button { showImporter = true } label: { Label("Başka uygulamadan aktar (CSV)", systemImage: "square.and.arrow.down") }
                    .buttonStyle(SecondaryButtonStyle())
                    .frame(maxWidth: 300)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func importCSV(_ url: URL) {
        guard let data = FileAccess.read(url),
              let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .windowsCP1254) else {
            store.showToast("Dosya okunamadı", isError: true)
            return
        }
        guard let result = store.importCSV(text) else {
            store.showToast("Dosyada “password” sütunu bulunamadı", isError: true)
            return
        }
        store.showToast("\(result.added) kayıt içe aktarıldı" + (result.skipped > 0 ? ", \(result.skipped) atlandı" : ""))
    }
}

struct EntryRow: View {
    let entry: Entry

    var body: some View {
        HStack(spacing: 12) {
            AvatarView(entry: entry)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(entry.title).font(.body.weight(.semibold)).lineLimit(1)
                    if entry.favorite {
                        Image(systemName: "star.fill").font(.caption2).foregroundColor(.kasaWarn)
                    }
                }
                Text(entry.subtitle).font(.subheadline).foregroundColor(.secondary).lineLimit(1)
            }
            Spacer(minLength: 4)
            if !entry.totp.isEmpty {
                Text("2FA")
                    .font(.system(size: 10.5, weight: .heavy))
                    .foregroundColor(.kasaAccent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.kasaAccent.opacity(0.15)))
            }
        }
        .padding(.vertical, 4)
    }
}
