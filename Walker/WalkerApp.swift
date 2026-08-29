import SwiftData
import SwiftUI

@main
struct WalkerApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(for: RunRecord.self)
                .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Run", systemImage: "figure.run")
                }
            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
        }
        .tint(.bloodRed)
    }
}
