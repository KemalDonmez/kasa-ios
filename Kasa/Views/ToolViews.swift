import SwiftUI

// MARK: - Şifre üretici

struct GeneratorView: View {
    @EnvironmentObject private var store: VaultStore
    @AppStorage(Prefs.genLength) private var length = 20
    @AppStorage(Prefs.genUpper) private var upper = true
    @AppStorage(Prefs.genLower) private var lower = true
    @AppStorage(Prefs.genDigits) private var digits = true
    @AppStorage(Prefs.genSymbols) private var symbols = true
    @AppStorage(Prefs.genNoAmbig) private var noAmbig = true
    @State private var generated = ""

    private var options: GenOptions {
        GenOptions(length: length, upper: upper, lower: lower, digits: digits, symbols: symbols, noAmbig: noAmbig)
    }

    private var colored: Text {
        generated.reduce(Text("")) { acc, ch in
            let s = String(ch)
            if ch.isNumber { return acc + Text(s).foregroundColor(.kasaAccent2) }
            if ch.isLetter { return acc + Text(s) }
            return acc + Text(s).foregroundColor(Color(hex: 0xFF4F96))
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 16) {
                        colored
                            .font(.system(size: 24, weight: .medium, design: .monospaced))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, minHeight: 70)
                            .textSelection(.enabled)
                            .padding(.top, 6)
                        StrengthBar(password: generated)
                        let s = Strength.of(generated)
                        HStack {
                            Text("~\(s.bits) bit entropi")
                            Spacer()
                            Text("Kırılma süresi: \(Strength.crackTime(bits: s.bits))")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                        HStack(spacing: 10) {
                            Button { regenerate() } label: { Label("Yenile", systemImage: "arrow.clockwise") }
                                .buttonStyle(SecondaryButtonStyle())
                            Button {
                                Clipboard.copy(generated)
                                store.showToast("Şifre kopyalandı")
                            } label: { Label("Kopyala", systemImage: "doc.on.doc") }
                                .buttonStyle(PrimaryButtonStyle())
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("Uzunluk") {
                    HStack(spacing: 14) {
                        Slider(value: Binding(get: { Double(length) }, set: { length = Int($0.rounded()) }), in: 8...64, step: 1)
                        Text("\(length)")
                            .font(.system(.title3, design: .monospaced).weight(.bold))
                            .frame(width: 40, alignment: .trailing)
                    }
                }

                Section("Karakterler") {
                    Toggle("Büyük harfler (A–Z)", isOn: guarded($upper))
                    Toggle("Küçük harfler (a–z)", isOn: guarded($lower))
                    Toggle("Rakamlar (0–9)", isOn: guarded($digits))
                    Toggle("Semboller (!@#$…)", isOn: guarded($symbols))
                }

                Section {
                    Toggle("Benzer karakterleri çıkar (l, 1, O, 0)", isOn: $noAmbig)
                } footer: {
                    Text("Şifreler cihazınızda, kriptografik olarak güvenli rastgele sayı üreteciyle oluşturulur.")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Üretici")
            .onAppear { if generated.isEmpty { regenerate() } }
            .onChange(of: length) { _ in regenerate() }
            .onChange(of: upper) { _ in regenerate() }
            .onChange(of: lower) { _ in regenerate() }
            .onChange(of: digits) { _ in regenerate() }
            .onChange(of: symbols) { _ in regenerate() }
            .onChange(of: noAmbig) { _ in regenerate() }
        }
    }

    /// En az bir karakter türünün seçili kalmasını sağlar
    private func guarded(_ binding: Binding<Bool>) -> Binding<Bool> {
        Binding(get: { binding.wrappedValue }, set: { newValue in
            let selectedCount = [upper, lower, digits, symbols].filter { $0 }.count
            if !newValue && selectedCount <= 1 {
                store.showToast("En az bir karakter türü seçili olmalı", isError: true)
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
            List {
                Section {
                    HStack(spacing: 18) {
                        ZStack {
                            Circle().stroke(Color(.tertiarySystemFill), lineWidth: 10)
                            Circle()
                                .trim(from: 0, to: CGFloat(r.total == 0 ? 0 : r.score) / 100)
                                .stroke(scoreColor(r), style: StrokeStyle(lineWidth: 10, lineCap: .round))
                                .rotationEffect(.degrees(-90))
                            VStack(spacing: 0) {
                                Text(r.total == 0 ? "–" : "\(r.score)").font(.system(size: 30, weight: .bold, design: .rounded))
                                if r.total > 0 { Text("/100").font(.caption2).foregroundColor(.secondary) }
                            }
                        }
                        .frame(width: 96, height: 96)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(scoreTitle(r)).font(.title3.weight(.bold))
                            Text(r.total == 0
                                 ? "Kayıt ekledikçe şifrelerinizin sağlığı burada görünecek."
                                 : "\(r.total) şifre incelendi. " + (r.problemCount > 0 ? "\(r.problemCount) kayıtta iyileştirme önerisi var." : "Sorun bulunamadı."))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section {
                    issueRow("Zayıf şifreler", "Kolay tahmin edilebilir", r.weak, "exclamationmark.triangle.fill", .kasaDanger)
                    issueRow("Tekrar kullanılanlar", "Birden fazla hesapta aynı şifre", r.reused, "arrow.triangle.2.circlepath", .kasaWarn)
                    issueRow("Eski şifreler", "1 yıldan uzun süredir değişmedi", r.old, "clock.fill", .kasaAccent2)
                } footer: {
                    Text("Sorunlu bir kayda dokunun, Düzenle › sihirli değnek ile güçlü bir şifre üretin ve sitedeki şifrenizi de değiştirin.")
                }

                Section("Ek koruma") {
                    HStack(spacing: 12) {
                        IconBadge(systemName: "checkmark.shield.fill", color: .kasaAccent)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("İki adımlı doğrulama")
                            Text("\(r.with2FA) kayıtta 2FA kodu tanımlı").font(.caption).foregroundColor(.secondary)
                        }
                    }
                    HStack(spacing: 12) {
                        let stale = store.lastBackup == 0 || Date().timeIntervalSince1970 * 1000 - store.lastBackup > 30 * 86_400_000
                        IconBadge(systemName: "externaldrive.fill", color: stale ? .kasaWarn : .kasaOK)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(store.lastBackup == 0 ? "Henüz yedek alınmadı"
                                 : "Son yedek: \(DateText.relative(Date(timeIntervalSince1970: store.lastBackup / 1000)))")
                            Text("Telefon kaybolursa yedek verilerinizi kurtarır").font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        Button("Yedekle") { store.selectedTab = .settings }
                            .buttonStyle(.bordered)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Güvenlik")
            .navigationDestination(for: String.self) { id in EntryDetailView(entryID: id) }
        }
    }

    @ViewBuilder
    private func issueRow(_ title: String, _ subtitle: String, _ list: [Entry], _ icon: String, _ color: Color) -> some View {
        let content = HStack(spacing: 12) {
            IconBadge(systemName: icon, color: color)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                Text(subtitle).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            if list.isEmpty {
                Image(systemName: "checkmark.circle.fill").foregroundColor(.kasaOK)
            } else {
                Text("\(list.count)")
                    .font(.subheadline.weight(.bold))
                    .foregroundColor(.kasaDanger)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.kasaDanger.opacity(0.14)))
            }
        }
        if list.isEmpty {
            content
        } else {
            NavigationLink {
                List(list) { e in
                    NavigationLink(value: e.id) { EntryRow(entry: e) }
                }
                .navigationTitle(title)
            } label: { content }
        }
    }

    private func scoreColor(_ r: VaultStore.Report) -> Color {
        r.score >= 80 ? .kasaOK : r.score >= 50 ? .kasaWarn : .kasaDanger
    }

    private func scoreTitle(_ r: VaultStore.Report) -> String {
        if r.total == 0 { return "Henüz şifre yok" }
        if r.score >= 80 { return "Harika durumdasınız" }
        if r.score >= 50 { return "İyileştirilebilir" }
        return "Dikkat gerekiyor"
    }
}
