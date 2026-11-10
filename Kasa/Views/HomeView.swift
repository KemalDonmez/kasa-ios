import SwiftUI

enum VaultFilter: Hashable {
    case all
    case favorites
    case category(EntryCategory)

    var title: String {
        switch self {
        case .all: return "Tüm şifreler"
        case .favorites: return "Favoriler"
        case .category(let c): return c.name
        }
    }
}

struct EditTarget: Identifiable {
    let id = UUID()
    let entry: Entry?
}

struct EntryGroup: Identifiable {
    let id: String
    var items: [Entry]
}

struct HomeView: View {
    @EnvironmentObject private var store: VaultStore
    @AppStorage(Prefs.sort) private var sort = "az"
    @State private var query = ""
    @State private var filter: VaultFilter = .all
    @State private var editing: EditTarget?
    @State private var showImporter = false
    @State private var pendingDelete: Entry?

    private var isBrowsing: Bool { query.isEmpty && filter == .all }

    var body: some View {
        let list = filteredEntries()
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    header
                    if store.entries.isEmpty {
                        emptyState
                    } else {
                        SearchField(text: $query)
                        if isBrowsing {
                            summaryCard
                            categoryGrid
                            favoritesStrip
                        } else {
                            filterBar(count: list.count)
                        }
                        entriesSection(list)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 110)
            }
            .scrollDismissesKeyboard(.immediately)
            .background(AppBackground())
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .bottomTrailing) {
                if !store.entries.isEmpty { addButton }
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
            .confirmationDialog("Kayıt silinsin mi?",
                                isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                                titleVisibility: .visible, presenting: pendingDelete) { e in
                Button("“\(e.title)” kaydını sil", role: .destructive) { store.delete(e.id) }
                Button("Vazgeç", role: .cancel) {}
            }
        }
    }

    // MARK: Üst bölüm

    private var greeting: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<12: return "Günaydın"
        case 12..<18: return "İyi günler"
        case 18..<23: return "İyi akşamlar"
        default: return "İyi geceler"
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                Text(AppInfo.name)
                    .font(.system(size: 32, weight: .bold))
            }
            Spacer()
            CircleIconButton(systemName: "lock.fill") { store.lock() }
                .accessibilityLabel("Kilitle")
            CircleIconButton(systemName: "plus", filled: true) { editing = EditTarget(entry: nil) }
                .accessibilityLabel("Yeni şifre")
        }
        .padding(.top, 6)
    }

    private var summaryCard: some View {
        let r = store.report
        return Button {
            store.selectedTab = .security
        } label: {
            ZStack(alignment: .topTrailing) {
                LinearGradient.hero
                Circle().fill(Color.white.opacity(0.08)).frame(width: 220, height: 220).offset(x: 70, y: -90)
                Circle().fill(Color.white.opacity(0.06)).frame(width: 140, height: 140).offset(x: -10, y: 80)
                HStack(spacing: 18) {
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Güvenlik puanı", systemImage: "checkmark.shield.fill")
                            .font(.subheadline.weight(.semibold))
                            .opacity(0.9)
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(r.total == 0 ? "–" : "\(r.score)")
                                .font(.system(size: 46, weight: .bold, design: .rounded))
                            Text("/100").font(.headline).opacity(0.7)
                        }
                        HStack(spacing: 6) {
                            Pill(text: "\(store.entries.count) kayıt", icon: "key.fill")
                            if r.weak.count > 0 { Pill(text: "\(r.weak.count) zayıf", icon: "exclamationmark.triangle.fill") }
                            if r.reused.count > 0 { Pill(text: "\(r.reused.count) tekrar", icon: "arrow.triangle.2.circlepath") }
                            if r.weak.isEmpty && r.reused.isEmpty { Pill(text: "\(r.with2FA) 2FA", icon: "number") }
                        }
                    }
                    Spacer(minLength: 0)
                    ZStack {
                        ScoreRing(progress: Double(r.total == 0 ? 0 : r.score) / 100, lineWidth: 10)
                        Image(systemName: r.score >= 80 ? "hand.thumbsup.fill" : "shield.lefthalf.filled")
                            .font(.system(size: 26, weight: .semibold))
                    }
                    .frame(width: 84, height: 84)
                }
                .padding(20)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            .shadow(color: Color(hex: 0x3B6CF6).opacity(0.35), radius: 18, x: 0, y: 10)
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: Kategoriler

    private struct Tile: Identifiable {
        let id: String
        let title: String
        let icon: String
        let colors: [Color]
        let count: Int
        let filter: VaultFilter
    }

    private var tiles: [Tile] {
        var counts: [EntryCategory: Int] = [:]
        var favs = 0
        for e in store.entries {
            counts[e.category, default: 0] += 1
            if e.favorite { favs += 1 }
        }
        var result: [Tile] = []
        if favs > 0 {
            result.append(Tile(id: "fav", title: "Favoriler", icon: "star.fill",
                               colors: [Color(hex: 0xFFC53D), Color(hex: 0xF59E0B)], count: favs, filter: .favorites))
        }
        for c in EntryCategory.allCases {
            if let n = counts[c] {
                result.append(Tile(id: c.rawValue, title: c.shortName, icon: c.icon, colors: c.colors, count: n, filter: .category(c)))
            }
        }
        return result
    }

    private var categoryGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Kategoriler")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(tiles) { t in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { filter = t.filter }
                    } label: {
                        HStack(spacing: 12) {
                            IconBadge(systemName: t.icon, colors: t.colors, size: 38)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(t.title)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                                Text("\(t.count) kayıt").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        .card(padding: 12, radius: 18)
                    }
                    .buttonStyle(PressableStyle())
                    .foregroundStyle(.primary)
                }
            }
        }
    }

    // MARK: Favoriler şeridi

    @ViewBuilder
    private var favoritesStrip: some View {
        let favs = store.entries.filter(\.favorite).sorted { $0.updatedAt > $1.updatedAt }
        if !favs.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader("Hızlı erişim")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(favs.prefix(12)) { e in
                            NavigationLink(value: e.id) {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack {
                                        BrandAvatar(entry: e, size: 40)
                                        Spacer()
                                        Image(systemName: "star.fill").font(.caption).foregroundStyle(Color.kasaWarn)
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(e.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                                        Text(e.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                    }
                                }
                                .frame(width: 140, alignment: .leading)
                                .card(padding: 14, radius: 18)
                            }
                            .buttonStyle(PressableStyle())
                            .foregroundStyle(.primary)
                            .contextMenu { contextMenu(e) }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 2)
                }
                .padding(.horizontal, -16)
            }
        }
    }

    // MARK: Liste

    private func filterBar(count: Int) -> some View {
        HStack(spacing: 10) {
            if filter != .all {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { filter = .all }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left").font(.caption.weight(.bold))
                        Text(filter.title).font(.subheadline.weight(.semibold))
                        Image(systemName: "xmark").font(.caption2.weight(.bold)).opacity(0.6)
                    }
                    .padding(.horizontal, 12)
                    .frame(height: 34)
                    .foregroundStyle(.white)
                    .background(Capsule().fill(LinearGradient.kasa))
                }
                .buttonStyle(PressableStyle())
            }
            Text("\(count) sonuç").font(.subheadline).foregroundStyle(.secondary)
            Spacer()
        }
    }

    private func filteredEntries() -> [Entry] {
        let locale = Locale(identifier: "tr_TR")
        let q = query.trimmingCharacters(in: .whitespaces).lowercased(with: locale)
        var list = store.entries.filter { e in
            switch filter {
            case .all: break
            case .favorites: if !e.favorite { return false }
            case .category(let c): if e.category != c { return false }
            }
            if q.isEmpty { return true }
            return e.title.lowercased(with: locale).contains(q)
                || e.username.lowercased(with: locale).contains(q)
                || e.url.lowercased(with: locale).contains(q)
                || e.notes.lowercased(with: locale).contains(q)
        }
        if sort == "recent" {
            list.sort { $0.updatedAt > $1.updatedAt }
        } else {
            list.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
        return list
    }

    private func groups(_ list: [Entry]) -> [EntryGroup] {
        guard sort == "az" else { return [EntryGroup(id: "Son değiştirilenler", items: list)] }
        var result: [EntryGroup] = []
        for e in list {
            var k = e.initial
            if k.rangeOfCharacter(from: .letters) == nil { k = "#" }
            if let last = result.indices.last, result[last].id == k {
                result[last].items.append(e)
            } else if let i = result.firstIndex(where: { $0.id == k }) {
                result[i].items.append(e)
            } else {
                result.append(EntryGroup(id: k, items: [e]))
            }
        }
        return result
    }

    @ViewBuilder
    private func entriesSection(_ list: [Entry]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if isBrowsing {
                SectionHeader("Tüm şifreler") { sortMenu }
            }
            if list.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").font(.system(size: 34)).foregroundStyle(.tertiary)
                    Text(query.isEmpty ? "Bu filtrede kayıt yok" : "“\(query)” için sonuç bulunamadı")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ForEach(groups(list)) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        if sort == "az" && query.isEmpty {
                            Text(group.id)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.secondary)
                                .padding(.leading, 6)
                        }
                        VStack(spacing: 0) {
                            ForEach(Array(group.items.enumerated()), id: \.element.id) { item in
                                if item.offset > 0 { Divider().padding(.leading, 70) }
                                row(item.element)
                            }
                        }
                        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.surface))
                        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color.hairline))
                    }
                }
            }
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sıralama", selection: $sort) {
                Label("A → Z", systemImage: "textformat").tag("az")
                Label("Son değiştirilen", systemImage: "clock").tag("recent")
            }
        } label: {
            HStack(spacing: 4) {
                Text(sort == "az" ? "A → Z" : "En yeni")
                Image(systemName: "chevron.down").font(.caption2.weight(.bold))
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.kasaAccent)
        }
    }

    private func row(_ e: Entry) -> some View {
        HStack(spacing: 12) {
            NavigationLink(value: e.id) {
                HStack(spacing: 14) {
                    BrandAvatar(entry: e)
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(e.title).font(.body.weight(.semibold)).lineLimit(1)
                            if e.favorite {
                                Image(systemName: "star.fill").font(.system(size: 10)).foregroundStyle(Color.kasaWarn)
                            }
                            if !e.totp.isEmpty {
                                Text("2FA")
                                    .font(.system(size: 9.5, weight: .heavy))
                                    .foregroundStyle(Color.kasaAccent)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(Capsule().fill(Color.kasaAccent.opacity(0.14)))
                            }
                        }
                        Text(e.subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(PressableStyle())
            .foregroundStyle(.primary)
            if !e.password.isEmpty {
                CopyButton(text: e.password, message: "\(e.title) şifresi kopyalandı")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .contextMenu { contextMenu(e) }
    }

    @ViewBuilder
    private func contextMenu(_ e: Entry) -> some View {
        if !e.username.isEmpty {
            Button { Clipboard.copy(e.username); Toaster.shared.show("Kullanıcı adı kopyalandı") } label: {
                Label("Kullanıcı adını kopyala", systemImage: "person")
            }
        }
        if !e.password.isEmpty {
            Button { Clipboard.copy(e.password); Toaster.shared.show("Şifre kopyalandı") } label: {
                Label("Şifreyi kopyala", systemImage: "key")
            }
        }
        if let url = URLHelper.openable(e.url) {
            Link(destination: url) { Label("Siteyi aç", systemImage: "safari") }
        }
        Button { store.toggleFavorite(e.id) } label: {
            Label(e.favorite ? "Favorilerden çıkar" : "Favorilere ekle", systemImage: e.favorite ? "star.slash" : "star")
        }
        Button { editing = EditTarget(entry: e) } label: { Label("Düzenle", systemImage: "pencil") }
        Button(role: .destructive) { pendingDelete = e } label: { Label("Sil", systemImage: "trash") }
    }

    private var addButton: some View {
        Button { editing = EditTarget(entry: nil) } label: {
            Image(systemName: "plus")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 62, height: 62)
                .background(Circle().fill(LinearGradient.kasa))
                .shadow(color: Color.kasaAccent.opacity(0.45), radius: 14, x: 0, y: 8)
        }
        .buttonStyle(PressableStyle())
        .padding(.trailing, 20)
        .padding(.bottom, 16)
        .accessibilityLabel("Yeni şifre")
    }

    private var defaultCategory: EntryCategory {
        if case .category(let c) = filter { return c }
        return .genel
    }

    // MARK: Boş durum

    private var emptyState: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Color.kasaAccent.opacity(0.35), .clear], center: .center, startRadius: 5, endRadius: 110))
                    .frame(width: 220, height: 220)
                IconBadge(systemName: "key.horizontal.fill", colors: [Color(hex: 0x7C5CFF), Color(hex: 0x3B82F6)], size: 96)
            }
            .frame(height: 180)
            Text("İlk şifrenizi ekleyin").font(.title2.weight(.bold))
            Text("Tüm hesaplarınızın şifrelerini burada saklayın. Hepsi bu iPhone'da, şifrelenmiş olarak durur ve internete gönderilmez.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
            Button { editing = EditTarget(entry: nil) } label: { Label("Şifre ekle", systemImage: "plus") }
                .buttonStyle(PrimaryButtonStyle())
            Button { showImporter = true } label: { Label("Başka uygulamadan aktar (CSV)", systemImage: "square.and.arrow.down") }
                .buttonStyle(SecondaryButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
    }

    private func importCSV(_ url: URL) {
        guard let data = FileAccess.read(url),
              let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .windowsCP1254) else {
            Toaster.shared.show("Dosya okunamadı", isError: true)
            return
        }
        guard let result = store.importCSV(text) else {
            Toaster.shared.show("Dosyada “password” sütunu bulunamadı", isError: true)
            return
        }
        Toaster.shared.show("\(result.added) kayıt içe aktarıldı" + (result.skipped > 0 ? ", \(result.skipped) atlandı" : ""))
    }
}
