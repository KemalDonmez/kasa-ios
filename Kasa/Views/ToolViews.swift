import SwiftUI

// MARK: - Şifre üretici

struct GeneratorView: View {
    @AppStorage(Prefs.genLength) private var length = 20
    @AppStorage(Prefs.genUpper) private var upper = true
    @AppStorage(Prefs.genLower) private var lower = true
    @AppStorage(Prefs.genDigits) private var digits = true
    @AppStorage(Prefs.genSymbols) private var symbols = true
    @AppStorage(Prefs.genNoAmbig) private var noAmbig = true
    @State private var generated = ""
    @State private var spin = 0.0

    private var options: GenOptions {
        GenOptions(length: length, upper: upper, lower: lower, digits: digits, symbols: symbols, noAmbig: noAmbig)
    }

    private var colored: Text {
        generated.reduce(Text("")) { acc, ch in
            let s = String(ch)
            if ch.isNumber { return acc + Text(s).foregroundColor(Color(hex: 0x4D9BFF)) }
            if ch.isLetter { return acc + Text(s) }
            return acc + Text(s).foregroundColor(Color(hex: 0xFF5C93))
        }
    }

    var body: some View {
        let s = Strength.of(generated)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Güçlü ve rastgele şifreler").font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                        Text("Üretici").font(.system(size: 32, weight: .bold))
                    }
                    .padding(.top, 6)

                    VStack(spacing: 18) {
                        colored
                            .font(.system(size: 24, weight: .semibold, design: .monospaced))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, minHeight: 76)
                            .textSelection(.enabled)
                            .padding(.top, 4)
                        StrengthBar(password: generated)
                        HStack {
                            Label("~\(s.bits) bit", systemImage: "function")
                            Spacer()
                            Label("Kırılma: \(Strength.crackTime(bits: s.bits))", systemImage: "hourglass")
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        HStack(spacing: 10) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.35)) { spin += 360 }
                                regenerate()
                                Haptics.tap()
                            } label: {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 18, weight: .semibold))
                                    .rotationEffect(.degrees(spin))
                            }
                            .buttonStyle(SecondaryButtonStyle())
                            .frame(width: 70)
                            Button {
                                Clipboard.copy(generated)
                                Toaster.shared.show("Şifre kopyalandı")
                            } label: { Label("Kopyala", systemImage: "doc.on.doc") }
                            .buttonStyle(PrimaryButtonStyle())
                        }
                    }
                    .card(padding: 20, radius: 24)

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Uzunluk").font(.headline)
                            Spacer()
                            Text("\(length)")
                                .font(.system(.title2, design: .rounded).weight(.bold))
                                .foregroundStyle(LinearGradient.kasa)
                        }
                        Slider(value: Binding(get: { Double(length) }, set: { length = Int($0.rounded()) }), in: 8...64, step: 1)
                            .tint(.kasaAccent)
                        HStack {
                            ForEach([12, 16, 20, 32], id: \.self) { n in
                                Button("\(n)") { length = n; Haptics.tap() }
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(length == n ? Color.white : Color.primary)
                                    .frame(maxWidth: .infinity, minHeight: 34)
                                    .background(Capsule().fill(length == n ? AnyShapeStyle(LinearGradient.kasa) : AnyShapeStyle(Color.primary.opacity(0.06))))
                                    .buttonStyle(PressableStyle())
                            }
                        }
                    }
                    .card()

                    VStack(spacing: 0) {
                        toggleRow("textformat.size.larger", "Büyük harfler", "A–Z", guarded($upper))
                        Divider().padding(.leading, 58)
                        toggleRow("textformat.size.smaller", "Küçük harfler", "a–z", guarded($lower))
                        Divider().padding(.leading, 58)
                        toggleRow("number", "Rakamlar", "0–9", guarded($digits))
                        Divider().padding(.leading, 58)
                        toggleRow("at", "Semboller", "! @ # $ %", guarded($symbols))
                        Divider().padding(.leading, 58)
                        toggleRow("eye.trianglebadge.exclamationmark", "Benzer karakterleri çıkar", "l, 1, O, 0", $noAmbig)
                    }
                    .card(padding: 4)

                    Label("Şifreler cihazınızda, kriptografik olarak güvenli rastgele sayı üreteciyle oluşturulur.", systemImage: "lock.shield")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
            .background(AppBackground())
            .toolbar(.hidden, for: .navigationBar)
            .onAppear { if generated.isEmpty { regenerate() } }
            .onChange(of: length) { _ in regenerate() }
            .onChange(of: upper) { _ in regenerate() }
            .onChange(of: lower) { _ in regenerate() }
            .onChange(of: digits) { _ in regenerate() }
            .onChange(of: symbols) { _ in regenerate() }
            .onChange(of: noAmbig) { _ in regenerate() }
        }
    }

    private func toggleRow(_ icon: String, _ title: String, _ subtitle: String, _ isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.kasaAccent)
                    .frame(width: 32, height: 32)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.kasaAccent.opacity(0.12)))
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.subheadline.weight(.semibold))
                    Text(subtitle).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .tint(.kasaAccent)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    /// En az bir karakter türünün seçili kalmasını sağlar
    private func guarded(_ binding: Binding<Bool>) -> Binding<Bool> {
        Binding(get: { binding.wrappedValue }, set: { newValue in
            let selectedCount = [upper, lower, digits, symbols].filter { $0 }.count
            if !newValue && selectedCount <= 1 {
                Toaster.shared.show("En az bir karakter türü seçili olmalı", isError: true)
                return
            }
            binding.wrappedValue = newValue
        })
    }

    private func regenerate() {
        generated = PasswordGenerator.generate(options)
    }
}

// MARK: - Güvenlik raporu

struct SecurityView: View {
    @EnvironmentObject private var store: VaultStore

    var body: some View {
        let r = store.report
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Şifre sağlığı").font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                        Text("Güvenlik").font(.system(size: 32, weight: .bold))
                    }
                    .padding(.top, 6)

                    scoreCard(r)

                    VStack(spacing: 0) {
                        issueRow("Zayıf şifreler", "Kolay tahmin edilebilir", r.weak, "exclamationmark.triangle.fill",
                                 [Color(hex: 0xFF6B7A), Color(hex: 0xE5364A)])
                        Divider().padding(.leading, 64)
                        issueRow("Tekrar kullanılanlar", "Birden fazla hesapta aynı şifre", r.reused, "arrow.triangle.2.circlepath",
                                 [Color(hex: 0xFFB648), Color(hex: 0xF08A1C)])
                        Divider().padding(.leading, 64)
                        issueRow("Eski şifreler", "1 yıldan uzun süredir değişmedi", r.old, "clock.fill",
                                 [Color(hex: 0x4D9BFF), Color(hex: 0x2A6DF0)])
                    }
                    .card(padding: 4)

                    SectionHeader("Ek koruma")
                    VStack(spacing: 0) {
                        HStack(spacing: 14) {
                            IconBadge(systemName: "number", colors: [Color(hex: 0x8B6CFF), Color(hex: 0x5B3DF5)], size: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("İki adımlı doğrulama").font(.subheadline.weight(.semibold))
                                Text("\(r.with2FA) kayıtta 2FA kodu tanımlı").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(12)
                        Divider().padding(.leading, 66)
                        let stale = store.lastBackup == 0 || Entry.nowMs() - store.lastBackup > 30 * 86_400_000
                        HStack(spacing: 14) {
                            IconBadge(systemName: "externaldrive.fill",
                                      colors: stale ? [Color(hex: 0xFFB648), Color(hex: 0xF08A1C)] : [Color(hex: 0x2FD58A), Color(hex: 0x13A866)],
                                      size: 40)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(store.lastBackup == 0 ? "Henüz yedek alınmadı"
                                     : "Son yedek: \(DateText.relative(Date(timeIntervalSince1970: store.lastBackup / 1000)))")
                                    .font(.subheadline.weight(.semibold))
                                Text("Telefon kaybolursa yedek verilerinizi kurtarır").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Yedekle") { store.selectedTab = .settings }
                                .font(.subheadline.weight(.semibold))
                                .buttonStyle(.bordered)
                                .tint(.kasaAccent)
                        }
                        .padding(12)
                    }
                    .card(padding: 4)

                    Label("Sorunlu bir kayda dokunun, Düzenle › Güçlü şifre üret ile yeni bir şifre oluşturun ve sitedeki şifrenizi de değiştirin.",
                          systemImage: "lightbulb")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
            .background(AppBackground())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: String.self) { id in EntryDetailView(entryID: id) }
        }
    }

    private func scoreCard(_ r: VaultStore.Report) -> some View {
        HStack(spacing: 20) {
            ZStack {
                ScoreRing(progress: Double(r.total == 0 ? 0 : r.score) / 100, lineWidth: 11)
                VStack(spacing: 0) {
                    Text(r.total == 0 ? "–" : "\(r.score)").font(.system(size: 32, weight: .bold, design: .rounded))
                    if r.total > 0 { Text("/100").font(.caption2).opacity(0.75) }
                }
            }
            .frame(width: 104, height: 104)
            VStack(alignment: .leading, spacing: 6) {
                Text(scoreTitle(r)).font(.title3.weight(.bold))
                Text(r.total == 0
                     ? "Şifre ekledikçe sağlık durumu burada görünecek."
                     : "\(r.total) şifre incelendi. " + (r.problemCount > 0 ? "\(r.problemCount) kayıtta iyileştirme önerisi var." : "Sorun bulunamadı."))
                    .font(.subheadline)
                    .opacity(0.85)
            }
            Spacer(minLength: 0)
        }
        .padding(20)
        .foregroundStyle(.white)
        .background(
            ZStack {
                LinearGradient(colors: scoreColors(r), startPoint: .topLeading, endPoint: .bottomTrailing)
                Circle().fill(Color.white.opacity(0.08)).frame(width: 220, height: 220).offset(x: 130, y: -70)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    @ViewBuilder
    private func issueRow(_ title: String, _ subtitle: String, _ list: [Entry], _ icon: String, _ colors: [Color]) -> some View {
        let content = HStack(spacing: 14) {
            IconBadge(systemName: icon, colors: colors, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if list.isEmpty {
                Image(systemName: "checkmark.circle.fill").font(.title3).foregroundStyle(Color.kasaOK)
            } else {
                HStack(spacing: 6) {
                    Text("\(list.count)")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.kasaDanger))
                    Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
                }
            }
        }
        .padding(12)
        .contentShape(Rectangle())

        if list.isEmpty {
            content
        } else {
            NavigationLink {
                IssueListView(title: title, entries: list)
            } label: { content }
            .buttonStyle(PressableStyle())
            .foregroundStyle(.primary)
        }
    }

    private func scoreColors(_ r: VaultStore.Report) -> [Color] {
        if r.total == 0 { return [Color(hex: 0x5B3DF5), Color(hex: 0x3B6CF6)] }
        if r.score >= 80 { return [Color(hex: 0x1FBF75), Color(hex: 0x0E9F8E)] }
        if r.score >= 50 { return [Color(hex: 0xF59E0B), Color(hex: 0xEA6A0A)] }
        return [Color(hex: 0xF04656), Color(hex: 0xC2185B)]
    }

    private func scoreTitle(_ r: VaultStore.Report) -> String {
        if r.total == 0 { return "Henüz şifre yok" }
        if r.score >= 80 { return "Harika durumdasınız" }
        if r.score >= 50 { return "İyileştirilebilir" }
        return "Dikkat gerekiyor"
    }
}

struct IssueListView: View {
    let title: String
    let entries: [Entry]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(entries.enumerated()), id: \.element.id) { item in
                    if item.offset > 0 { Divider().padding(.leading, 70) }
                    NavigationLink(value: item.element.id) {
                        HStack(spacing: 14) {
                            BrandAvatar(entry: item.element)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.element.title).font(.body.weight(.semibold)).lineLimit(1)
                                Text(item.element.subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(PressableStyle())
                    .foregroundStyle(.primary)
                }
            }
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color.surface))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Color.hairline))
            .padding(16)
        }
        .background(AppBackground())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
