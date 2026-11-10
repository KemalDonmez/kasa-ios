import SwiftUI

struct ToastAction {
    let title: String
    let run: @MainActor () -> Void
}

struct ToastMessage: Identifiable {
    let id = UUID()
    let text: String
    let isError: Bool
    let action: ToastAction?
}

/// Bildirimler ve "işleniyor" katmanı. Veri nesnesinden ayrı tutulur ki
/// bir bildirim gösterildiğinde listeler yeniden hesaplanmasın.
@MainActor
final class Toaster: ObservableObject {
    static let shared = Toaster()

    @Published var toast: ToastMessage?
    @Published var busy: String?

    func show(_ text: String, isError: Bool = false, action: ToastAction? = nil) {
        let t = ToastMessage(text: text, isError: isError, action: action)
        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) { toast = t }
        if isError { Haptics.error() }
        let delay: UInt64 = action == nil ? 2_000_000_000 : 4_500_000_000
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            guard let self, self.toast?.id == t.id else { return }
            withAnimation(.easeOut(duration: 0.2)) { self.toast = nil }
        }
    }

    func dismiss() {
        withAnimation(.easeOut(duration: 0.2)) { toast = nil }
    }
}
