import SwiftUI
import Charts

struct AppsView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedPeriod: TimePeriod = .today
    @State private var appSummaries: [AppUsageSummary] = []
    @State private var selectedApp: AppUsageSummary?

    private let db = DatabaseManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("アプリ別使用時間")
                    .font(.title)
                    .fontWeight(.bold)

                Spacer()

                Picker("期間", selection: $selectedPeriod) {
                    ForEach(TimePeriod.allCases) { period in
                        Text(period.rawValue).tag(period)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 300)
            }
            .padding()

            Divider()

            HStack(spacing: 0) {
                // App List
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(appSummaries) { app in
                            AppListRow(app: app, isSelected: selectedApp?.bundleId == app.bundleId)
                                .onTapGesture {
                                    selectedApp = app
                                }
                        }
                    }
                    .padding()
                }
                .frame(width: 350)
                .background(Color(NSColor.controlBackgroundColor))

                Divider()

                // Detail View
                if let app = selectedApp {
                    AppDetailView(app: app, period: selectedPeriod)
                } else {
                    VStack {
                        Image(systemName: "app.badge")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("アプリを選択してください")
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .onAppear {
            loadData()
        }
        .onChange(of: selectedPeriod) { _ in
            loadData()
        }
    }

    private func loadData() {
        let (startDate, endDate) = selectedPeriod.dateRange
        appSummaries = db.getAppUsageSummaries(from: startDate, to: endDate, limit: 50)

        if selectedApp == nil, let first = appSummaries.first {
            selectedApp = first
        }
    }
}

enum TimePeriod: String, CaseIterable, Identifiable {
    case today = "今日"
    case week = "今週"
    case month = "今月"

    var id: String { rawValue }

    var dateRange: (Date, Date) {
        let calendar = Calendar.current
        let now = Date()

        switch self {
        case .today:
            let start = calendar.startOfDay(for: now)
            let end = calendar.date(byAdding: .day, value: 1, to: start)!
            return (start, end)
        case .week:
            let start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
            let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start)!
            return (start, end)
        case .month:
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
            let end = calendar.date(byAdding: .month, value: 1, to: start)!
            return (start, end)
        }
    }
}

struct AppListRow: View {
    let app: AppUsageSummary
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(app.color)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(app.appName)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text("\(app.sessionCount) セッション")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text(app.formattedDuration)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }
}

struct AppDetailView: View {
    let app: AppUsageSummary
    let period: TimePeriod

    @State private var dailyUsage: [DailyUsageData] = []
    private let db = DatabaseManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack(spacing: 16) {
                    Circle()
                        .fill(app.color)
                        .frame(width: 48, height: 48)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(app.appName)
                            .font(.title2)
                            .fontWeight(.bold)
                        Text(app.bundleId)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }

                // Stats
                HStack(spacing: 24) {
                    StatItem(title: "合計時間", value: app.formattedDuration)
                    StatItem(title: "セッション数", value: "\(app.sessionCount)")
                    StatItem(
                        title: "平均セッション",
                        value: formatAverageSession(totalSeconds: app.totalSeconds, sessionCount: app.sessionCount)
                    )
                }

                // Usage Chart
                VStack(alignment: .leading, spacing: 12) {
                    Text("使用時間の推移")
                        .font(.headline)

                    if #available(macOS 14.0, *) {
                        Chart(dailyUsage) { data in
                            BarMark(
                                x: .value("日付", data.date, unit: .day),
                                y: .value("時間（分）", data.minutes)
                            )
                            .foregroundStyle(app.color.gradient)
                        }
                        .frame(height: 200)
                    } else {
                        Text("チャートはmacOS 14以降で利用可能です")
                            .foregroundColor(.secondary)
                            .frame(height: 200)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)

                Spacer()
            }
            .padding()
        }
        .onAppear {
            loadDailyUsage()
        }
        .onChange(of: app.bundleId) { _ in
            loadDailyUsage()
        }
    }

    private func loadDailyUsage() {
        let calendar = Calendar.current
        let (startDate, endDate) = period.dateRange

        var usage: [DailyUsageData] = []
        var current = startDate

        while current < endDate {
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: current)!
            let logs = db.getAppUsageLogs(from: current, to: dayEnd)
            let appLogs = logs.filter { $0.bundleId == app.bundleId }
            let totalSeconds = appLogs.reduce(0) { $0 + $1.activeSeconds }

            usage.append(DailyUsageData(date: current, minutes: totalSeconds / 60))
            current = dayEnd
        }

        dailyUsage = usage
    }

    private func formatAverageSession(totalSeconds: Int, sessionCount: Int) -> String {
        guard sessionCount > 0 else { return "0m" }
        let avgSeconds = totalSeconds / sessionCount
        let minutes = avgSeconds / 60
        return "\(minutes)m"
    }
}

struct StatItem: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
        }
    }
}

struct DailyUsageData: Identifiable {
    let date: Date
    let minutes: Int
    var id: Date { date }
}
