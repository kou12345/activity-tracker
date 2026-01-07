import SwiftUI

@main
struct ActivityTrackerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appState)
        }

        WindowGroup("Activity Tracker", id: "main") {
            DetailWindow()
                .environmentObject(appState)
                .frame(minWidth: 900, minHeight: 600)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1000, height: 700)

        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "chart.bar.fill")
                Text(appState.formattedTodayTime)
                    .font(.system(.caption, design: .monospaced))
            }
        }
        .menuBarExtraStyle(.window)
    }
}
