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
    @ObservedObject private var toaster = Toaster.shared
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(Prefs.theme) private var theme = 0
    @AppStorage(Prefs.palette) private var paletteRaw = "gece"

    var body: some View {
        ZStack {
            Group {
                switch store.phase {
                case .loading:
                    Color.appBackground.ignoresSafeArea()
                case .setup:
                    SetupView()
                case .locked:
                    LockView()
                case .unlocked:
                    MainTabView()
                }
            }
            .id(paletteRaw)
            .transition(.opacity)

            if scenePhase != .active && store.phase == .unlocked {
                PrivacyCover().transition(.opacity)
            }

            if let message = toaster.busy {
                BusyOverlay(message: message).transition(.opacity)
            }

            VStack {
                if let toast = toaster.toast {
                    ToastView(toast: toast)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onTapGesture { if toast.action == nil { toaster.dismiss() } }
                }
                Spacer()
            }
            .padding(.top, 4)
        }
        .animation(.easeInOut(duration: 0.22), value: store.phase)
        .tint(.kasaAccent)
        .preferredColorScheme(theme == 1 ? .dark : theme == 2 ? .light : nil)
        .onChange(of: scenePhase) { newPhase in
            store.scenePhaseChanged(newPhase)
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject private var store: VaultStore

    var body: some View {
        TabView(selection: $store.selectedTab) {
            HomeView()
                .tabItem { Label("Şifreler", systemImage: "key.horizontal.fill") }
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
