import SwiftUI

@main
struct KasaApp: App {
    @StateObject private var store = VaultStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var store: VaultStore
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(Prefs.theme) private var theme = 0

    var body: some View {
        ZStack {
            Group {
                switch store.phase {
                case .loading:
                    Color(.systemGroupedBackground).ignoresSafeArea()
                case .setup:
                    SetupView()
                case .locked:
                    LockView()
                case .unlocked:
                    MainTabView()
                }
            }
            .transition(.opacity)

            if scenePhase != .active && store.phase == .unlocked {
                PrivacyCover().transition(.opacity)
            }

            if let message = store.busyMessage {
                BusyOverlay(message: message).transition(.opacity)
            }

            VStack {
                if let toast = store.toast {
                    ToastView(toast: toast)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                Spacer()
            }
            .padding(.top, 6)
            .allowsHitTesting(store.toast?.action != nil)
        }
        .animation(.easeInOut(duration: 0.2), value: store.phase)
        .tint(.kasaAccent)
        .preferredColorScheme(theme == 1 ? .dark : theme == 2 ? .light : nil)
        .onChange(of: scenePhase) { newPhase in
            store.scenePhaseChanged(newPhase)
        }
    }
}
