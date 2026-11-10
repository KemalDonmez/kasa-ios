import SwiftUI

struct LogoView: View {
    var size: CGFloat = 84

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                .fill(LinearGradient.kasa)
            Image(systemName: "lock.shield")
                .font(.system(size: size * 0.5, weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
        .shadow(color: Color.kasaAccent.opacity(0.45), radius: size * 0.22, x: 0, y: size * 0.12)
    }
}

struct AvatarView: View {
    let entry: Entry
    var size: CGFloat = 42

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.29, style: .continuous)
                .fill(entry.category.color.gradient)
            Text(entry.initial)
                .font(.system(size: size * 0.43, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
    }
}

struct StrengthBar: View {
    let password: String
    var showLabel = true

    var body: some View {
        let s = Strength.of(password)
        HStack(spacing: 10) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.tertiarySystemFill))
                    Capsule().fill(s.color)
                        .frame(width: password.isEmpty ? 0 : geo.size.width * s.fraction)
                }
            }
            .frame(height: 6)
            .animation(.easeOut(duration: 0.25), value: password)
            if showLabel {
                Text(password.isEmpty ? " " : s.label)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(s.color)
                    .frame(minWidth: 64, alignment: .trailing)
            }
        }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(LinearGradient.kasa))
            .shadow(color: Color.kasaAccent.opacity(0.35), radius: 12, x: 0, y: 6)
            .opacity(isEnabled ? 1 : 0.6)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(.secondarySystemFill)))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

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
                Image(systemName: visible ? "eye.slash" : "eye")
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(visible ? "Gizle" : "Göster")
        }
    }
}

/// Giriş ekranlarında kullanılan kutulu alan
struct AuthField<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .padding(.horizontal, 16)
            .frame(minHeight: 54)
            .background(RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Color(.secondarySystemGroupedBackground)))
            .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(Color.primary.opacity(0.06)))
    }
}

struct AuthBackground: View {
    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
            RadialGradient(colors: [Color.kasaAccent.opacity(0.28), .clear], center: .top, startRadius: 0, endRadius: 420)
            RadialGradient(colors: [Color.kasaAccent2.opacity(0.16), .clear], center: .bottomTrailing, startRadius: 0, endRadius: 380)
        }
        .ignoresSafeArea()
    }
}

struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 10 * sin(animatableData * .pi * 4), y: 0))
    }
}

struct CountdownRing: View {
    let remaining: Int
    let period: Int

    var body: some View {
        let low = remaining <= 5
        ZStack {
            Circle().stroke(Color(.tertiarySystemFill), lineWidth: 3)
            Circle()
                .trim(from: 0, to: CGFloat(remaining) / CGFloat(max(period, 1)))
                .stroke(low ? Color.kasaDanger : Color.kasaAccent, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: remaining)
            Text("\(remaining)")
                .font(.caption2.weight(.bold).monospacedDigit())
                .foregroundColor(.secondary)
        }
        .frame(width: 34, height: 34)
    }
}

struct ToastView: View {
    let toast: ToastMessage

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: toast.isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .foregroundColor(toast.isError ? .white : .kasaOK)
            Text(toast.text)
                .font(.subheadline.weight(.semibold))
                .lineLimit(3)
            if let action = toast.action {
                Button(action.title) { action.run() }
                    .font(.subheadline.weight(.heavy))
                    .foregroundColor(toast.isError ? .white : .kasaAccent)
            }
        }
        .foregroundColor(toast.isError ? .white : .primary)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            Capsule().fill(toast.isError ? AnyShapeStyle(Color.kasaDanger) : AnyShapeStyle(Material.regularMaterial))
        )
        .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 8)
        .padding(.horizontal, 16)
    }
}

struct BusyOverlay: View {
    let message: String

    var body: some View {
        ZStack {
            Color.black.opacity(0.3).ignoresSafeArea()
            HStack(spacing: 14) {
                ProgressView()
                Text(message).font(.headline)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.regularMaterial))
        }
    }
}

/// Uygulama değiştiricide içeriği gizleyen kapak
struct PrivacyCover: View {
    var body: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
            Color(.systemBackground).opacity(0.6).ignoresSafeArea()
            LogoView(size: 76)
        }
    }
}

struct IconBadge: View {
    let systemName: String
    let color: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(.white)
            .frame(width: 30, height: 30)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(color))
    }
}

struct FilterChip: View {
    let title: String
    let count: Int
    var color: Color?
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let color { Circle().fill(color).frame(width: 8, height: 8) }
                Text(title).font(.subheadline.weight(.semibold))
                Text("\(count)").font(.caption.weight(.semibold)).opacity(0.6)
            }
            .padding(.horizontal, 13)
            .frame(height: 34)
            .foregroundColor(selected ? Color(.systemBackground) : .secondary)
            .background(Capsule().fill(selected ? Color.primary : Color(.secondarySystemGroupedBackground)))
        }
        .buttonStyle(.plain)
    }
}
