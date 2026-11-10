import SwiftUI
import UIKit

// MARK: - Marka ve simgeler

struct LogoView: View {
    var size: CGFloat = 84

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                .fill(LinearGradient.kasa)
            RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
                .fill(LinearGradient(colors: [.white.opacity(0.28), .clear], startPoint: .top, endPoint: .center))
            Image(systemName: "lock.shield.fill")
                .font(.system(size: size * 0.48, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
        }
        .frame(width: size, height: size)
    }
}

/// Kayıt simgesi: sitenin logosu varsa onu, yoksa servis rengiyle baş harfi gösterir
struct BrandAvatar: View {
    let entry: Entry
    var size: CGFloat = 44
    @State private var icon: UIImage?
    @AppStorage(Prefs.siteIcons) private var siteIcons = true

    init(entry: Entry, size: CGFloat = 44) {
        self.entry = entry
        self.size = size
        _icon = State(initialValue: SiteIconStore.shared.cachedImage(for: entry))
    }

    private var iconKey: String { IconDomain.cacheKey(for: entry) ?? "" }

    var body: some View {
        ZStack {
            if siteIcons, let icon {
                RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                    .fill(Color.white)
                Image(uiImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .padding(size * 0.12)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
                RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5)
            } else {
                RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                    .fill(BrandPalette.gradient(for: entry))
                RoundedRectangle(cornerRadius: size * 0.3, style: .continuous)
                    .fill(LinearGradient(colors: [.white.opacity(0.22), .clear], startPoint: .top, endPoint: .center))
                Text(entry.initial)
                    .font(.system(size: size * 0.44, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .task(id: iconKey) {
            guard siteIcons, !iconKey.isEmpty else { icon = nil; return }
            if let hit = SiteIconStore.shared.cached(key: iconKey) { icon = hit; return }
            icon = nil
            // Yazarken her harfte istek atmamak için kısa bekleme
            try? await Task.sleep(nanoseconds: 700_000_000)
            if Task.isCancelled { return }
            let img = await SiteIconStore.shared.image(for: entry)
            if !Task.isCancelled { withAnimation(.easeOut(duration: 0.2)) { icon = img } }
        }
    }
}

struct IconBadge: View {
    let systemName: String
    var colors: [Color] = [Color.kasaAccent, Color.kasaAccent2]
    var size: CGFloat = 32

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size * 0.46, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
            )
    }
}

// MARK: - Göstergeler

struct StrengthBar: View {
    let password: String
    var showLabel = true

    var body: some View {
        let s = Strength.of(password)
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { i in
                    Capsule()
                        .fill(!password.isEmpty && i <= s.score ? s.color : Color.primary.opacity(0.1))
                        .frame(height: 5)
                }
            }
            if showLabel {
                Text(password.isEmpty ? " " : s.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(s.color)
                    .frame(minWidth: 70, alignment: .trailing)
            }
        }
        .animation(.easeOut(duration: 0.2), value: s.score)
    }
}

struct ScoreRing: View {
    let progress: Double
    var lineWidth: CGFloat = 9
    var color: Color = .white
    var track: Color = .white.opacity(0.22)

    var body: some View {
        ZStack {
            Circle().stroke(track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

struct CountdownRing: View {
    let remaining: Int
    let period: Int

    var body: some View {
        let low = remaining <= 5
        ZStack {
            Circle().stroke(Color.primary.opacity(0.1), lineWidth: 3)
            Circle()
                .trim(from: 0, to: CGFloat(remaining) / CGFloat(max(period, 1)))
                .stroke(low ? Color.kasaDanger : Color.kasaAccent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: remaining)
            Text("\(remaining)")
                .font(.caption2.weight(.bold).monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .frame(width: 34, height: 34)
    }
}

struct Pill: View {
    let text: String
    var icon: String?
    var tint: Color = .white

    var body: some View {
        HStack(spacing: 5) {
            if let icon { Image(systemName: icon).font(.caption2.weight(.bold)) }
            Text(text).font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .foregroundStyle(tint)
        .background(Capsule().fill(tint.opacity(0.16)))
    }
}

// MARK: - Düğme stilleri

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(LinearGradient.kasa))
            .opacity(isEnabled ? 1 : 0.6)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Color.surfaceRaised))
            .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).strokeBorder(Color.hairline))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Basılınca hafifçe küçülen sade stil
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct CircleIconButton: View {
    let systemName: String
    var filled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(filled ? Color.white : Color.primary)
                .frame(width: 42, height: 42)
                .background(
                    Circle().fill(filled ? AnyShapeStyle(LinearGradient.kasa) : AnyShapeStyle(Color.surface))
                )
                .overlay(Circle().strokeBorder(filled ? Color.clear : Color.hairline))
        }
        .buttonStyle(PressableStyle())
    }
}

struct CopyButton: View {
    let text: String
    let message: String
    @State private var done = false

    var body: some View {
        Button {
            Clipboard.copy(text)
            Toaster.shared.show(message)
            withAnimation(.spring(response: 0.25)) { done = true }
            Task {
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                withAnimation { done = false }
            }
        } label: {
            Image(systemName: done ? "checkmark" : "doc.on.doc")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(done ? Color.kasaOK : Color.kasaAccent)
                .frame(width: 38, height: 38)
                .background(Circle().fill(done ? Color.kasaOK.opacity(0.14) : Color.kasaAccent.opacity(0.12)))
        }
        .buttonStyle(.borderless)
        .accessibilityLabel("Kopyala")
    }
}

// MARK: - Alanlar

/// Göster/gizle düğmeli şifre alanı
struct SecureInput: View {
    let placeholder: String
    @Binding var text: String
    var monospaced = false
    @State private var visible = false

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if visible {
                    TextField(placeholder, text: $text)
                } else {
                    SecureField(placeholder, text: $text)
                }
            }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .font(monospaced ? .system(.body, design: .monospaced) : .body)
            Button {
                visible.toggle()
            } label: {
                Image(systemName: visible ? "eye.slash" : "eye").foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(visible ? "Gizle" : "Göster")
        }
    }
}

struct AuthField<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .padding(.horizontal, 16)
            .frame(minHeight: 54)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.surface))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.hairline))
    }
}

struct SearchField: View {
    @Binding var text: String
    var placeholder = "Şifrelerde ara"
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField(placeholder, text: $text)
                .focused($focused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .submitLabel(.search)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Color.surface))
        .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous)
            .strokeBorder(focused ? Color.kasaAccent.opacity(0.6) : Color.hairline, lineWidth: focused ? 1.5 : 1))
    }
}

struct SectionHeader<Trailing: View>: View {
    let title: String
    let trailing: Trailing

    init(_ title: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.trailing = trailing()
    }

    var body: some View {
        HStack {
            Text(title).font(.title3.weight(.bold))
            Spacer()
            trailing
        }
        .padding(.horizontal, 4)
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(_ title: String) {
        self.title = title
        self.trailing = EmptyView()
    }
}

// MARK: - Katmanlar

struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 10 * sin(animatableData * .pi * 4), y: 0))
    }
}

struct ToastView: View {
    let toast: ToastMessage

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: toast.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundStyle(toast.isError ? Color.white : Color.kasaOK)
            Text(toast.text)
                .font(.subheadline.weight(.semibold))
                .lineLimit(3)
            if let action = toast.action {
                Button(action.title) { action.run() }
                    .font(.subheadline.weight(.heavy))
                    .foregroundStyle(toast.isError ? Color.white : Color.kasaAccent)
            }
        }
        .foregroundStyle(toast.isError ? Color.white : Color.primary)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            Capsule().fill(toast.isError ? AnyShapeStyle(Color.kasaDanger) : AnyShapeStyle(Material.regularMaterial))
        )
        .overlay(Capsule().strokeBorder(Color.hairline))
        .shadow(color: .black.opacity(0.16), radius: 14, x: 0, y: 6)
        .padding(.horizontal, 16)
    }
}

struct BusyOverlay: View {
    let message: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.28).ignoresSafeArea()
            HStack(spacing: 14) {
                ProgressView()
                Text(message).font(.headline)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Material.regularMaterial))
        }
    }
}

/// Uygulama değiştiricide içeriği gizleyen kapak
struct PrivacyCover: View {
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            LogoView(size: 76)
        }
    }
}
