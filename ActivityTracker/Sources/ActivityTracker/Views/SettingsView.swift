import SwiftUI
import ServiceManagement

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("一般", systemImage: "gear")
                }

            PrivacySettingsView()
                .tabItem {
                    Label("プライバシー", systemImage: "hand.raised.fill")
                }

            DisplaySettingsView()
                .tabItem {
                    Label("表示", systemImage: "paintbrush.fill")
                }

            DataSettingsView()
                .tabItem {
                    Label("データ", systemImage: "externaldrive.fill")
                }
        }
        .frame(width: 500, height: 400)
    }
}

struct GeneralSettingsView: View {
    @ObservedObject private var settings = UserSettings.shared
    @State private var isLaunchAtLoginEnabled = false

    var body: some View {
        Form {
            Section {
                Toggle("ログイン時に起動", isOn: $settings.launchAtLogin)
                    .onChange(of: settings.launchAtLogin) { _, newValue in
                        setLaunchAtLogin(enabled: newValue)
                    }

                Stepper(value: $settings.idleThresholdMinutes, in: 1...30) {
                    HStack {
                        Text("アイドル判定時間")
                        Spacer()
                        Text("\(settings.idleThresholdMinutes) 分")
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("起動設定")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func setLaunchAtLogin(enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Failed to set launch at login: \(error)")
        }
    }
}

struct PrivacySettingsView: View {
    @ObservedObject private var settings = UserSettings.shared
    @State private var runningApps: [RunningAppInfo] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("除外アプリの設定")
                .font(.headline)

            Text("選択したアプリは追跡されません")
                .font(.caption)
                .foregroundColor(.secondary)

            List {
                ForEach(runningApps) { app in
                    HStack {
                        if let icon = app.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 24, height: 24)
                        }

                        Text(app.name)

                        Spacer()

                        Toggle("", isOn: Binding(
                            get: { settings.excludedBundleIds.contains(app.bundleId) },
                            set: { _ in settings.toggleAppExclusion(app.bundleId) }
                        ))
                        .labelsHidden()
                    }
                }
            }
            .frame(minHeight: 200)

            HStack {
                Button("アプリリストを更新") {
                    loadRunningApps()
                }

                Spacer()

                Text("除外中: \(settings.excludedBundleIds.count) アプリ")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .onAppear {
            loadRunningApps()
        }
    }

    private func loadRunningApps() {
        let workspace = NSWorkspace.shared
        runningApps = workspace.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> RunningAppInfo? in
                guard let bundleId = app.bundleIdentifier,
                      let name = app.localizedName else { return nil }
                return RunningAppInfo(bundleId: bundleId, name: name, icon: app.icon)
            }
            .sorted { $0.name < $1.name }
    }
}

struct RunningAppInfo: Identifiable {
    let bundleId: String
    let name: String
    let icon: NSImage?

    var id: String { bundleId }
}

struct DisplaySettingsView: View {
    @ObservedObject private var settings = UserSettings.shared

    var body: some View {
        Form {
            Section {
                Toggle("メニューバーに時間を表示", isOn: $settings.showTimeInMenuBar)

                Picker("時間形式", selection: $settings.useDecimalTime) {
                    Text("時:分 (例: 2h 30m)").tag(false)
                    Text("小数 (例: 2.5h)").tag(true)
                }
            } header: {
                Text("メニューバー")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct DataSettingsView: View {
    @State private var showExportSheet = false
    @State private var showClearConfirmation = false
    @State private var exportFormat: ExportFormat = .csv
    @State private var exportStartDate = Calendar.current.date(byAdding: .month, value: -1, to: Date())!
    @State private var exportEndDate = Date()

    private let db = DatabaseManager.shared

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("データをエクスポート")
                    Spacer()
                    Button("エクスポート...") {
                        showExportSheet = true
                    }
                }
            } header: {
                Text("エクスポート")
            }

            Section {
                HStack {
                    Text("全てのデータを削除")
                    Spacer()
                    Button("データをクリア", role: .destructive) {
                        showClearConfirmation = true
                    }
                }
            } header: {
                Text("データ管理")
            } footer: {
                Text("この操作は取り消せません。全てのアクティビティデータが削除されます。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .sheet(isPresented: $showExportSheet) {
            ExportSheet(
                startDate: $exportStartDate,
                endDate: $exportEndDate,
                format: $exportFormat,
                onExport: exportData
            )
        }
        .alert("データを削除しますか？", isPresented: $showClearConfirmation) {
            Button("キャンセル", role: .cancel) { }
            Button("削除", role: .destructive) {
                db.clearAllData()
            }
        } message: {
            Text("全てのアクティビティデータが削除されます。この操作は取り消せません。")
        }
    }

    private func exportData() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = exportFormat == .csv ? [.commaSeparatedText] : [.json]
        panel.nameFieldStringValue = "activity_export.\(exportFormat.fileExtension)"

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            let content: String
            if exportFormat == .csv {
                content = db.exportToCSV(from: exportStartDate, to: exportEndDate)
            } else {
                content = db.exportToJSON(from: exportStartDate, to: exportEndDate)
            }

            do {
                try content.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                print("Export error: \(error)")
            }
        }

        showExportSheet = false
    }
}

struct ExportSheet: View {
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var format: ExportFormat
    let onExport: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("データをエクスポート")
                .font(.headline)

            Form {
                DatePicker("開始日", selection: $startDate, displayedComponents: .date)
                DatePicker("終了日", selection: $endDate, displayedComponents: .date)

                Picker("形式", selection: $format) {
                    ForEach(ExportFormat.allCases) { fmt in
                        Text(fmt.rawValue).tag(fmt)
                    }
                }
            }
            .frame(width: 300)

            HStack {
                Button("キャンセル") {
                    dismiss()
                }

                Spacer()

                Button("エクスポート") {
                    onExport()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 400)
    }
}

#Preview {
    SettingsView()
}
