import SwiftUI

// MARK: - Klasör simgesi

struct FolderAvatar: View {
    let folder: Folder
    var size: CGFloat = 40

    var body: some View {
        ZStack {
            Circle().fill(LinearGradient(colors: folder.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            Circle().fill(LinearGradient(colors: [Color.white.opacity(0.25), .clear], startPoint: .top, endPoint: .center))
            if folder.icon == "letter" {
                Text(folder.initial)
                    .font(.system(size: size * 0.44, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            } else {
                Image(systemName: folder.icon)
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
    }
}

/// Ana ekrandaki klasör şeridi için kart
struct FolderCard: View {
    let title: String
    let count: Int
    let selected: Bool
    let avatar: AnyView

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            avatar
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text("\(count) şifre").font(.caption).foregroundStyle(selected ? Color.white.opacity(0.8) : Color.secondary)
            }
        }
        .frame(width: 104, alignment: .leading)
        .padding(12)
        .foregroundStyle(selected ? Color.white : Color.primary)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(selected ? AnyShapeStyle(LinearGradient.kasa) : AnyShapeStyle(Color.surface))
        )
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(selected ? Color.clear : Color.hairline))
    }
}

// MARK: - Klasör oluşturma / düzenleme

struct FolderEditTarget: Identifiable {
    let id = UUID()
    let folder: Folder?
}

struct FolderEditView: View {
    @EnvironmentObject private var store: VaultStore
    @Environment(\.dismiss) private var dismiss
    let original: Folder?
    var onCreate: ((Folder) -> Void)?

    @State private var name: String
    @State private var icon: String
    @State private var color: Int
    @State private var confirmDelete = false

    init(original: Folder?, onCreate: ((Folder) -> Void)? = nil) {
        self.original = original
        self.onCreate = onCreate
        _name = State(initialValue: original?.name ?? "")
        _icon = State(initialValue: original?.icon ?? "letter")
        _color = State(initialValue: original?.color ?? 0)
    }

    private var preview: Folder { Folder(name: name.isEmpty ? "?" : name, icon: icon, color: color) }

    private let suggestions = ["Kemal", "Babam", "Annem", "Eşim", "Kardeşim", "Çocuklar", "Aile", "İş"]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(spacing: 12) {
                        FolderAvatar(folder: preview, size: 76)
                        Text(name.isEmpty ? "Yeni klasör" : name).font(.title3.weight(.bold))
                        if let o = original {
                            Text("\(store.count(inFolder: o.id)) şifre").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .listRowBackground(Color.clear)
                }

                Section {
                    TextField("Klasör adı (ör. Kemal, Babam, Ali)", text: $name)
                        .font(.body.weight(.medium))
                    if original == nil {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(suggestions.filter { s in !store.folders.contains { $0.name == s } }, id: \.self) { s in
                                    Button(s) { name = s; Haptics.tap() }
                                        .font(.subheadline.weight(.semibold))
                                        .padding(.horizontal, 12)
                                        .frame(height: 32)
                                        .background(Capsule().fill(Color.primary.opacity(0.06)))
                                        .buttonStyle(.borderless)
                                        .foregroundStyle(.primary)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                    }
                } header: {
                    Text("Ad")
                }

                Section("Renk") {
                    HStack(spacing: 0) {
                        ForEach(Folder.colorChoices.indices, id: \.self) { i in
                            Button {
                                color = i
                                Haptics.tap()
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(LinearGradient(colors: Folder.colorChoices[i].map { Color(hex: $0) },
                                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .frame(width: 32, height: 32)
                                    if color == i {
                                        Image(systemName: "checkmark").font(.caption.weight(.bold)).foregroundStyle(.white)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Simge") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 6), spacing: 10) {
                        ForEach(Folder.iconChoices, id: \.self) { ic in
                            Button {
                                icon = ic
                                Haptics.tap()
                            } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(icon == ic ? AnyShapeStyle(LinearGradient(colors: preview.colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                                                         : AnyShapeStyle(Color.primary.opacity(0.06)))
                                    if ic == "letter" {
                                        Text(name.isEmpty ? "A" : preview.initial).font(.system(size: 17, weight: .bold, design: .rounded))
                                    } else {
                                        Image(systemName: ic).font(.system(size: 16, weight: .semibold))
                                    }
                                }
                                .frame(height: 44)
                                .foregroundStyle(icon == ic ? Color.white : Color.primary)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    .padding(.vertical, 4)
                }

                if let o = original {
                    Section {
                        Toggle(isOn: Binding(get: { store.defaultFolderID == o.id },
                                             set: { store.setDefaultFolder($0 ? o.id : nil) })) {
                            Label("Yeni şifreler bu klasöre eklensin", systemImage: "star.circle.fill")
                        }
                        .tint(.kasaAccent)
                    }
                    Section {
                        Button(role: .destructive) { confirmDelete = true } label: {
                            HStack { Spacer(); Label("Klasörü sil", systemImage: "trash"); Spacer() }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .navigationTitle(original == nil ? "Yeni klasör" : "Klasörü düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Vazgeç") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { save() }
                        .fontWeight(.bold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .confirmationDialog("“\(original?.name ?? "")” klasörü silinsin mi?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Klasörü sil, şifreler kalsın") {
                    if let o = original { store.deleteFolder(o.id, deleteEntries: false) }
                    Toaster.shared.show("Klasör silindi, şifreler klasörsüz bırakıldı")
                    dismiss()
                }
                Button("Klasörü ve içindeki şifreleri sil", role: .destructive) {
                    if let o = original { store.deleteFolder(o.id, deleteEntries: true) }
                    Toaster.shared.show("Klasör ve şifreleri silindi")
                    dismiss()
                }
                Button("Vazgeç", role: .cancel) {}
            } message: {
                Text("İçindeki \(original.map { store.count(inFolder: $0.id) } ?? 0) şifre için ne yapılsın?")
            }
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if var o = original {
            o.name = trimmed
            o.icon = icon
            o.color = color
            store.updateFolder(o)
            Toaster.shared.show("Klasör güncellendi")
        } else {
            let f = store.addFolder(name: trimmed, icon: icon, color: color)
            Toaster.shared.show("“\(f.name)” klasörü oluşturuldu")
            onCreate?(f)
        }
        Haptics.success()
        dismiss()
    }
}

// MARK: - Ayarlar: klasör yönetimi

struct FoldersSettingsView: View {
    @EnvironmentObject private var store: VaultStore
    @State private var editing: FolderEditTarget?

    var body: some View {
        List {
            Section {
                if store.folders.isEmpty {
                    Text("Henüz klasör yok. Şifrelerinizi kişilere göre ayırmak için “Kemal”, “Babam” gibi klasörler oluşturun.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ForEach(store.folders) { f in
                    Button { editing = FolderEditTarget(folder: f) } label: {
                        HStack(spacing: 12) {
                            FolderAvatar(folder: f, size: 36)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(f.name).font(.body.weight(.semibold))
                                Text("\(store.count(inFolder: f.id)) şifre").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if store.defaultFolderID == f.id {
                                Text("Varsayılan")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(Color.kasaAccent)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(Color.kasaAccent.opacity(0.14)))
                            }
                            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(.primary)
                }
                Button { editing = FolderEditTarget(folder: nil) } label: {
                    Label("Yeni klasör", systemImage: "folder.badge.plus").font(.body.weight(.semibold))
                }
            } footer: {
                Text("Varsayılan klasör, yeni eklediğiniz şifrelerin otomatik olarak gireceği klasördür. Bir klasörü açıp düzenleyerek değiştirebilirsiniz.")
            }
            if store.count(inFolder: nil) > 0 && !store.folders.isEmpty {
                Section {
                    Label("Klasörsüz: \(store.count(inFolder: nil)) şifre", systemImage: "tray")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(AppBackground())
        .navigationTitle("Klasörler")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { t in FolderEditView(original: t.folder) }
    }
}
