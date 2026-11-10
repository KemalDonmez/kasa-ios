import SwiftUI

// MARK: - Filtre ve sıralama

enum VaultFilter: Hashable {
    case all
    case favorites
    case twoFA
    case weak
    case category(EntryCategory)

    var title: String {
        switch self {
        case .all: return "Tümü"
        case .favorites: return "Favoriler"
        case .twoFA: return "2FA"
        case .weak: return "Zayıf"
        case .category(let c): return c.shortName
        }
    }
}

enum SortMode: String, CaseIterable, Identifiable {
    case az, za, created, updated, category

    var id: String { rawValue }

    var title: String {
        switch self {
        case .az: return "A → Z"
        case .za: return "Z → A"
        case .created: return "Son eklenen"
        case .updated: return "Son değişen"
        case .category: return "Türe göre"
        }
    }

    var icon: String {
        switch self {
        case .az: return "arrow.down"
        case .za: return "arrow.up"
        case .created: return "plus.circle"
        case .updated: return "clock.arrow.circlepath"
        case .category: return "square.grid.2x2"
        }
    }

    init(stored: String) {
        if stored == "recent" { self = .updated } else { self = SortMode(rawValue: stored) ?? .az }
    }
}

struct EditTarget: Identifiable {
    let id = UUID()
    let entry: Entry?
    var template: Entry? = nil
}

/// Aynı servise ait birden fazla hesap (ör. 3 Gmail hesabı)
struct ServiceGroup: Identifiable {
    let key: String
    let name: String
    let entries: [Entry]
    var id: String { "g:" + key }
    var lead: Entry { entries[0] }
}

enum ListItem: Identifiable {
    case single(Entry)
    case group(ServiceGroup)

    var id: String {
        switch self {
        case .single(let e): return e.id
        case .group(let g): return g.id
        }
    }

    var sortName: String {
        switch self {
        case .single(let e): return e.title
        case .group(let g): return g.name
        }
    }

    var initial: String {
        switch self {
        case .single(let e): return e.initial
        case .group(let g):
            guard let f = g.name.trimmingCharacters(in: .whitespaces).first else { return "#" }
            return String(f).uppercased(with: Locale(identifier: "tr_TR"))
        }
    }
}

struct ListSection: Identifiable {
    let id: String
    let title: String
    var icon: String?
    var items: [ListItem]
}

// MARK: - Ana ekran

struct HomeView: View {
    @EnvironmentObject private var store: VaultStore
    @AppStorage(Prefs.sort) private var sortRaw = "az"
    @State private var query = ""
    @State private var filter: VaultFilter = .all
    @State private var editing: EditTarget?
    @State private var showImporter = false
    @State private var pendingDelete: Entry?
    @State private var path: [String] = []
    @State private var expanded: Set<String> = []

    private var sort: SortMode { SortMode(stored: sortRaw) }
    private var isBrowsing: Bool { query.isEmpty && filter == .all }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if store.entries.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle(AppInfo.name)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { store.lock() } label: {
                        Image(systemName: "lock.fill").font(.system(size: 15, weight: .semibold))
                    }
                    .accessibilityLabel("Kilitle")
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { editing = EditTarget(entry: nil) } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(LinearGradient.kasa))
                    }
                    .accessibilityLabel("Yeni şifre")
                }
            }
            .navigationDestination(for: String.self) { id in
                EntryDetailView(entryID: id)
            }
            .sheet(item: $editing) { target in
                EntryEditView(original: target.entry, defaultCategory: defaultCategory, template: target.template)
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

    // MARK: Liste

    private var list: some View {
        let entries = filteredEntries()
        let sections = buildSections(entries)
        let favs = isBrowsing ? store.entries.filter(\.favorite).sorted { $0.updatedAt > $1.updatedAt } : []
        return List {
            if isBrowsing {
                Section {
                    SummaryCard(report: store.report, total: store.entries.count) { store.selectedTab = .security }
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }

            Section {
                controls(resultCount: entries.count)
                    .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }

            if !favs.isEmpty {
                Section {
                    FavoritesStrip(entries: Array(favs.prefix(15))) { id in path.append(id) }
                        .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } header: {
                    sectionHeader("Hızlı erişim", icon: "star.fill")
                }
            }

            if sections.isEmpty {
                Section {
                    VStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").font(.system(size: 34)).foregroundStyle(.tertiary)
                        Text(query.isEmpty ? "Bu filtrede kayıt yok" : "“\(query)” için sonuç bulunamadı")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                    .listRowBackground(Color.clear)
                }
            } else {
                ForEach(sections) { section in
                    Section {
                        ForEach(section.items) { item in
                            switch item {
                            case .single(let e):
                                row(e)
                            case .group(let g):
                                groupRow(g)
                            }
                        }
                    } header: {
                        sectionHeader(section.title, icon: section.icon)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppBackground())
        .scrollDismissesKeyboard(.immediately)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Ada göre ara")
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled(true)
    }

    private func sectionHeader(_ title: String, icon: String?) -> some View {
        HStack(spacing: 6) {
            if let icon { Image(systemName: icon).font(.caption.weight(.bold)) }
            Text(title)
        }
        .font(.subheadline.weight(.bold))
        .foregroundStyle(.secondary)
        .textCase(nil)
    }

    private func groupRow(_ g: ServiceGroup) -> some View {
        DisclosureGroup(isExpanded: Binding(
            get: { expanded.contains(g.key) },
            set: { open in
                withAnimation(.easeInOut(duration: 0.2)) {
                    if open { expanded.insert(g.key) } else { expanded.remove(g.key) }
                }
            })) {
            ForEach(g.entries) { e in row(e, inGroup: true) }
            Button {
                editing = EditTarget(entry: nil, template: Entry(title: g.name, url: g.lead.url, category: g.lead.category))
            } label: {
                Label("\(g.name) için hesap ekle", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.kasaAccent)
            }
            .listRowBackground(Color.surface)
        } label: {
            GroupRowView(group: g)
        }
        .listRowBackground(Color.surface)
    }

    private func row(_ e: Entry, inGroup: Bool = false) -> some View {
        NavigationLink(value: e.id) {
            EntryRowView(entry: e, inGroup: inGroup).equatable()
        }
        .listRowBackground(Color.surface)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) { pendingDelete = e } label: { Label("Sil", systemImage: "trash") }
            if !e.username.isEmpty {
                Button {
                    Clipboard.copy(e.username)
                    Toaster.shared.show("Kullanıcı adı kopyalandı")
                } label: { Label("Kullanıcı", systemImage: "person.fill") }
                .tint(Color(hex: 0x64748B))
            }
        }
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button { store.toggleFavorite(e.id) } label: {
                Label(e.favorite ? "Çıkar" : "Favori", systemImage: e.favorite ? "star.slash.fill" : "star.fill")
            }
            .tint(.kasaWarn)
        }
        .contextMenu {
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
    }

    // MARK: Filtre ve sıralama kontrolleri

    private func controls(resultCount: Int) -> some View {
        let counts = filterCounts()
        let weakCount = store.report.weak.count
        return VStack(alignment: .leading, spacing: 10) {
            chipScroller {
                ForEach(SortMode.allCases) { m in
                    Chip(title: m.title, icon: m.icon, selected: sort == m) {
                        Haptics.tap()
                        withAnimation(.easeInOut(duration: 0.2)) { sortRaw = m.rawValue }
                    }
                }
            }
            chipScroller {
                Chip(title: "Tümü", count: store.entries.count, selected: filter == .all) { setFilter(.all) }
                if counts.fav > 0 {
                    Chip(title: "Favoriler", icon: "star.fill", count: counts.fav, selected: filter == .favorites,
                         tint: .kasaWarn) { setFilter(.favorites) }
                }
                if counts.twoFA > 0 {
                    Chip(title: "2FA", icon: "number", count: counts.twoFA, selected: filter == .twoFA) { setFilter(.twoFA) }
                }
                if weakCount > 0 {
                    Chip(title: "Zayıf", icon: "exclamationmark.triangle.fill", count: weakCount,
                         selected: filter == .weak, tint: .kasaDanger) { setFilter(.weak) }
                }
                ForEach(EntryCategory.allCases) { c in
                    if let n = counts.categories[c] {
                        Chip(title: c.shortName, icon: c.icon, count: n, selected: filter == .category(c), tint: c.color) {
                            setFilter(.category(c))
                        }
                    }
                }
            }
            if !isBrowsing {
                Text("\(resultCount) sonuç")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
            }
        }
        .padding(.vertical, 2)
    }

    private func chipScroller<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) { content() }
                .padding(.horizontal, 20)
                .padding(.vertical, 1)
        }
    }

    private func setFilter(_ f: VaultFilter) {
        Haptics.tap()
        withAnimation(.easeInOut(duration: 0.2)) { filter = (filter == f && f != .all) ? .all : f }
    }

    private func filterCounts() -> (fav: Int, twoFA: Int, categories: [EntryCategory: Int]) {
        var fav = 0, twoFA = 0
        var cats: [EntryCategory: Int] = [:]
        for e in store.entries {
            if e.favorite { fav += 1 }
            if !e.totp.isEmpty { twoFA += 1 }
            cats[e.category, default: 0] += 1
        }
        return (fav, twoFA, cats)
    }

    // MARK: Veri

    private func filteredEntries() -> [Entry] {
        let locale = Locale(identifier: "tr_TR")
        let q = query.trimmingCharacters(in: .whitespaces).lowercased(with: locale)
        let weakIDs: Set<String> = filter == .weak ? Set(store.report.weak.map(\.id)) : []
        return store.entries.filter { e in
            switch filter {
            case .all: break
            case .favorites: if !e.favorite { return false }
            case .twoFA: if e.totp.isEmpty { return false }
            case .weak: if !weakIDs.contains(e.id) { return false }
            case .category(let c): if e.category != c { return false }
            }
            if q.isEmpty { return true }
            // Öncelik başlıkta (ada göre); kullanıcı adı ve sitede de aranır
            return e.title.lowercased(with: locale).contains(q)
                || e.username.lowercased(with: locale).contains(q)
                || e.url.lowercased(with: locale).contains(q)
        }
    }

    /// Aynı servise ait kayıtları tek grupta toplar
    private func groupedItems(_ list: [Entry]) -> [ListItem] {
        var order: [String] = []
        var buckets: [String: [Entry]] = [:]
        for e in list {
            let k = ServiceKey.of(e)
            if buckets[k] == nil { order.append(k) }
            buckets[k, default: []].append(e)
        }
        return order.map { (k: String) -> ListItem in
            let items = buckets[k] ?? []
            if items.count == 1 { return .single(items[0]) }
            let sorted = items.sorted {
                ($0.username.isEmpty ? $0.title : $0.username).localizedCaseInsensitiveCompare($1.username.isEmpty ? $1.title : $1.username) == .orderedAscending
            }
            return .group(ServiceGroup(key: k, name: ServiceKey.displayName(for: sorted), entries: sorted))
        }
    }

    private func buildSections(_ list: [Entry]) -> [ListSection] {
        guard !list.isEmpty else { return [] }
        let byName: (ListItem, ListItem) -> Bool = { $0.sortName.localizedCaseInsensitiveCompare($1.sortName) == .orderedAscending }

        if !query.isEmpty {
            let locale = Locale(identifier: "tr_TR")
            let q = query.trimmingCharacters(in: .whitespaces).lowercased(with: locale)
            let sorted = list.sorted { a, b in
                let ap = a.title.lowercased(with: locale).hasPrefix(q)
                let bp = b.title.lowercased(with: locale).hasPrefix(q)
                if ap != bp { return ap }
                return a.title.localizedCaseInsensitiveCompare(b.title) == .orderedAscending
            }
            return [ListSection(id: "results", title: "Sonuçlar", icon: "magnifyingglass", items: sorted.map { .single($0) })]
        }

        switch sort {
        case .az, .za:
            let items = groupedItems(list)
            let sorted = sort == .az ? items.sorted(by: byName) : items.sorted { byName($1, $0) }
            var result: [ListSection] = []
            for item in sorted {
                var k = item.initial
                if k.rangeOfCharacter(from: .letters) == nil { k = "#" }
                if let last = result.indices.last, result[last].id == k {
                    result[last].items.append(item)
                } else {
                    result.append(ListSection(id: k, title: k, icon: nil, items: [item]))
                }
            }
            return result
        case .created, .updated:
            let useCreated = sort == .created
            let sorted = list.sorted { (useCreated ? $0.createdAt : $0.updatedAt) > (useCreated ? $1.createdAt : $1.updatedAt) }
            let cal = Calendar.current
            let now = Date()
            var result: [ListSection] = []
            for e in sorted {
                let date = useCreated ? e.createdDate : e.updatedDate
                let b = DateBucket.of(date, now: now, calendar: cal)
                let id = "b\(b.rank)"
                if let last = result.indices.last, result[last].id == id {
                    result[last].items.append(.single(e))
                } else {
                    result.append(ListSection(id: id, title: b.title, icon: "calendar", items: [.single(e)]))
                }
            }
            return result
        case .category:
            var result: [ListSection] = []
            for c in EntryCategory.allCases {
                let inCat = list.filter { $0.category == c }
                if inCat.isEmpty { continue }
                let items = groupedItems(inCat).sorted(by: byName)
                result.append(ListSection(id: c.rawValue, title: c.name, icon: c.icon, items: items))
            }
            return result
        }
    }

    private var defaultCategory: EntryCategory {
        if case .category(let c) = filter { return c }
        return .genel
    }

    // MARK: Boş durum

    private var emptyState: some View {
        ScrollView {
            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .fill(RadialGradient(colors: [Color.kasaAccent.opacity(0.35), .clear], center: .center, startRadius: 5, endRadius: 110))
                        .frame(width: 220, height: 220)
                    IconBadge(systemName: "key.horizontal.fill", colors: Theme.palette.gradientColors, size: 96)
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
            .padding(.horizontal, 20)
            .padding(.top, 10)
        }
        .background(AppBackground())
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

enum DateBucket {
    static func of(_ d: Date, now: Date, calendar cal: Calendar) -> (rank: Int, title: String) {
        if cal.isDateInToday(d) { return (0, "Bugün") }
        if cal.isDateInYesterday(d) { return (1, "Dün") }
        let days = cal.dateComponents([.day], from: d, to: now).day ?? 0
        if days < 7 { return (2, "Bu hafta") }
        if days < 31 { return (3, "Bu ay") }
        if days < 365 { return (4, "Bu yıl") }
        return (5, "Daha eski")
    }
}

// MARK: - Satır ve kartlar

/// Liste satırı. Equatable olduğu için yalnızca kayıt değiştiğinde yeniden çizilir.
struct EntryRowView: View, Equatable {
    let entry: Entry
    var inGroup = false

    static func == (lhs: EntryRowView, rhs: EntryRowView) -> Bool { lhs.entry == rhs.entry && lhs.inGroup == rhs.inGroup }

    private var mainText: String {
        inGroup && !entry.username.isEmpty ? entry.username : entry.title
    }

    private var subText: String {
        if inGroup {
            if !entry.username.isEmpty && entry.title != mainText { return entry.title }
            return entry.host.isEmpty ? entry.category.name : entry.host
        }
        return entry.subtitle
    }

    var body: some View {
        HStack(spacing: 13) {
            if inGroup {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Color.kasaAccent.opacity(0.85))
                    .frame(width: 34)
            } else {
                BrandAvatar(entry: entry)
            }
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(mainText).font(.body.weight(.semibold)).lineLimit(1)
                    if entry.favorite {
                        Image(systemName: "star.fill").font(.system(size: 10)).foregroundStyle(Color.kasaWarn)
                    }
                    if !entry.totp.isEmpty {
                        Text("2FA")
                            .font(.system(size: 9.5, weight: .heavy))
                            .foregroundStyle(Color.kasaAccent)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.kasaAccent.opacity(0.14)))
                    }
                }
                Text(subText).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 4)
            if !entry.password.isEmpty {
                CopyButton(text: entry.password, message: "\(entry.title) şifresi kopyalandı")
            }
        }
        .padding(.vertical, 3)
    }
}

struct GroupRowView: View {
    let group: ServiceGroup

    var body: some View {
        HStack(spacing: 13) {
            BrandAvatar(entry: group.lead)
            VStack(alignment: .leading, spacing: 3) {
                Text(group.name).font(.body.weight(.semibold)).lineLimit(1)
                Text("\(group.entries.count) hesap").font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Text("\(group.entries.count)")
                .font(.caption.weight(.heavy))
                .foregroundStyle(.white)
                .frame(minWidth: 24, minHeight: 24)
                .padding(.horizontal, 4)
                .background(Capsule().fill(LinearGradient.kasa))
        }
        .padding(.vertical, 3)
    }
}

struct Chip: View {
    let title: String
    var icon: String?
    var count: Int?
    let selected: Bool
    var tint: Color?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(selected ? Color.white : (tint ?? Color.secondary))
                }
                Text(title).font(.subheadline.weight(.semibold))
                if let count {
                    Text("\(count)").font(.caption.weight(.bold)).opacity(0.65)
                }
            }
            .padding(.horizontal, 13)
            .frame(height: 34)
            .foregroundStyle(selected ? Color.white : Color.primary)
            .background(
                Capsule().fill(selected ? AnyShapeStyle(LinearGradient.kasa) : AnyShapeStyle(Color.surface))
            )
            .overlay(Capsule().strokeBorder(selected ? Color.clear : Color.hairline))
        }
        .buttonStyle(.borderless)
    }
}

struct SummaryCard: View {
    let report: VaultStore.Report
    let total: Int
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Güvenlik puanı", systemImage: "checkmark.shield.fill")
                        .font(.subheadline.weight(.semibold))
                        .opacity(0.9)
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(report.total == 0 ? "–" : "\(report.score)")
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                        Text("/100").font(.headline).opacity(0.7)
                    }
                    HStack(spacing: 6) {
                        Pill(text: "\(total) kayıt", icon: "key.fill")
                        if report.weak.count > 0 { Pill(text: "\(report.weak.count) zayıf", icon: "exclamationmark.triangle.fill") }
                        if report.reused.count > 0 { Pill(text: "\(report.reused.count) tekrar", icon: "arrow.triangle.2.circlepath") }
                        if report.weak.isEmpty && report.reused.isEmpty { Pill(text: "\(report.with2FA) 2FA", icon: "number") }
                    }
                }
                Spacer(minLength: 0)
                ZStack {
                    ScoreRing(progress: Double(report.total == 0 ? 0 : report.score) / 100, lineWidth: 10)
                    Image(systemName: report.score >= 80 ? "hand.thumbsup.fill" : "shield.lefthalf.filled")
                        .font(.system(size: 26, weight: .semibold))
                }
                .frame(width: 84, height: 84)
            }
            .padding(20)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .background(CardArt())
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .buttonStyle(PressableStyle())
    }
}

/// Kart arka planı; tek seferde çizilip önbelleğe alınır (kaydırmada akıcılık için)
struct CardArt: View {
    var body: some View {
        ZStack {
            LinearGradient.hero
            Circle().fill(Color.white.opacity(0.08)).frame(width: 240, height: 240).offset(x: 140, y: -90)
            Circle().fill(Color.white.opacity(0.06)).frame(width: 160, height: 160).offset(x: -120, y: 80)
        }
        .drawingGroup()
    }
}

struct FavoritesStrip: View {
    let entries: [Entry]
    let open: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(entries) { e in
                    Button { open(e.id) } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            BrandAvatar(entry: e, size: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(e.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                                Text(e.subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                        }
                        .frame(width: 128, alignment: .leading)
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.surface))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.hairline))
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 2)
        }
    }
}
