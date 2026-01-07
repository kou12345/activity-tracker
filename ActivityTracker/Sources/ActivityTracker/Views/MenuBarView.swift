import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.accentColor)
                Text("今日: \(appState.formattedTodayTime)")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Top Apps
            if appState.topApps.isEmpty {
                Text("まだデータがありません")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(appState.topApps.prefix(5)) { app in
                        AppUsageRow(app: app)
                    }
                }
                .padding(.vertical, 8)
            }

            Divider()

            // Actions
            VStack(alignment: .leading, spacing: 0) {
                MenuButton(title: "詳細を表示...", icon: "arrow.up.forward.square") {
                    openWindow(id: "main")
                    NSApp.activate(ignoringOtherApps: true)
                }

                Divider()
                    .padding(.vertical, 4)

                MenuButton(title: "設定...", icon: "gear") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                }

                MenuButton(title: "終了", icon: "power") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .padding(.vertical, 8)
        }
        .frame(width: 280)
    }
}

struct AppUsageRow: View {
    let app: AppUsageSummary

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(app.color)
                .frame(width: 8, height: 8)

            Text(app.appName)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer()

            Text(app.formattedDuration)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}

struct MenuButton: View {
    let title: String
    let icon: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 16)
                Text(title)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(isHovered ? Color.accentColor.opacity(0.1) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
