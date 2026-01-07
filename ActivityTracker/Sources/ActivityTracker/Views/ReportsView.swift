import SwiftUI
import Charts

struct ReportsView: View {
    @EnvironmentObject var appState: AppState
    @State private var weeklyData: [DailyReportData] = []
    @State private var monthlyData: [DailyReportData] = []
    @State private var previousWeekTotal: Int = 0
    @State private var currentWeekTotal: Int = 0

    private let db = DatabaseManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HStack {
                    Text("レポート")
                        .font(.title)
                        .fontWeight(.bold)

                    Spacer()

                    Picker("期間", selection: $appState.selectedReportPeriod) {
                        ForEach(ReportPeriod.allCases) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 240)
                }
                .padding(.horizontal)

                switch appState.selectedReportPeriod {
                case .daily:
                    DailyReportView()
                case .weekly:
                    WeeklyReportView(
                        weeklyData: weeklyData,
                        currentWeekTotal: currentWeekTotal,
                        previousWeekTotal: previousWeekTotal
                    )
                case .monthly:
                    MonthlyReportView(monthlyData: monthlyData)
                }

                Spacer()
            }
            .padding(.vertical)
        }
        .onAppear {
            loadData()
        }
        .onChange(of: appState.selectedReportPeriod) { _ in
            loadData()
        }
    }

    private func loadData() {
        loadWeeklyData()
        loadMonthlyData()
    }

    private func loadWeeklyData() {
        let calendar = Calendar.current
        let now = Date()

        // Current week
        let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!

        var data: [DailyReportData] = []
        for dayOffset in 0..<7 {
            let dayStart = calendar.date(byAdding: .day, value: dayOffset, to: weekStart)!
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
            let totalSeconds = db.getTotalActiveTime(from: dayStart, to: dayEnd)

            let weekday = calendar.component(.weekday, from: dayStart)
            let weekdayName = calendar.shortWeekdaySymbols[weekday - 1]

            data.append(DailyReportData(
                date: dayStart,
                totalSeconds: totalSeconds,
                label: weekdayName
            ))
        }
        weeklyData = data
        currentWeekTotal = data.reduce(0) { $0 + $1.totalSeconds }

        // Previous week
        let prevWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: weekStart)!
        let prevWeekEnd = weekStart
        previousWeekTotal = db.getTotalActiveTime(from: prevWeekStart, to: prevWeekEnd)
    }

    private func loadMonthlyData() {
        let calendar = Calendar.current
        let now = Date()

        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let range = calendar.range(of: .day, in: .month, for: now)!

        var data: [DailyReportData] = []
        for day in range {
            let dayStart = calendar.date(byAdding: .day, value: day - 1, to: monthStart)!
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!
            let totalSeconds = db.getTotalActiveTime(from: dayStart, to: dayEnd)

            data.append(DailyReportData(
                date: dayStart,
                totalSeconds: totalSeconds,
                label: "\(day)"
            ))
        }
        monthlyData = data
    }
}

struct DailyReportData: Identifiable {
    let date: Date
    let totalSeconds: Int
    let label: String

    var id: Date { date }

    var formattedDuration: String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        } else {
            return String(format: "%dm", minutes)
        }
    }
}

struct DailyReportView: View {
    @State private var totalTime: Int = 0
    @State private var topApps: [AppUsageSummary] = []
    @State private var hourlyActivity: [HourlyActivityData] = []
    @State private var inputSummary: InputActivitySummary?
    @State private var focusSessions: [FocusSession] = []

    private let db = DatabaseManager.shared

    var body: some View {
        VStack(spacing: 20) {
            summaryCards
            hourlyChart
            HStack(spacing: 16) {
                topAppsSection
                inputStatsSection
            }
            .padding(.horizontal)
        }
        .onAppear {
            loadData()
        }
    }

    private var summaryCards: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            ReportCard(title: "総作業時間", value: formatDuration(totalTime), icon: "clock.fill")
            ReportCard(title: "集中セッション", value: "\(focusSessions.count)回", icon: "brain.head.profile")
            ReportCard(
                title: "平均集中時間",
                value: averageFocusTime,
                icon: "timer"
            )
        }
        .padding(.horizontal)
    }

    private var averageFocusTime: String {
        focusSessions.isEmpty ? "0m" : formatDuration(focusSessions.reduce(0) { $0 + $1.durationSeconds } / focusSessions.count)
    }

    private var hourlyChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("時間帯別アクティビティ")
                .font(.headline)

            if #available(macOS 14.0, *) {
                Chart(hourlyActivity) { data in
                    BarMark(
                        x: .value("時間", data.hour),
                        y: .value("レベル", data.activityLevel)
                    )
                    .foregroundStyle(Color.blue.gradient)
                }
                .chartXAxis {
                    AxisMarks(values: [0, 6, 12, 18, 23])
                }
                .frame(height: 200)
            } else {
                SimpleBarChart(data: hourlyActivity)
                    .frame(height: 200)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private var topAppsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("使用アプリ TOP 10")
                .font(.headline)

            if topApps.isEmpty {
                Text("データがありません")
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(topApps.prefix(10).enumerated()), id: \.element.id) { index, app in
                    topAppRow(index: index, app: app)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    private func topAppRow(index: Int, app: AppUsageSummary) -> some View {
        HStack {
            Text("\(index + 1)")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 20)

            Circle()
                .fill(app.color)
                .frame(width: 8, height: 8)

            Text(app.appName)
                .lineLimit(1)

            Spacer()

            Text(app.formattedDuration)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var inputStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("入力統計")
                .font(.headline)

            if let summary = inputSummary {
                VStack(spacing: 16) {
                    InputStatRow(
                        icon: "keyboard.fill",
                        title: "キーストローク",
                        value: "\(summary.totalKeystrokes)"
                    )
                    InputStatRow(
                        icon: "cursorarrow.click.2",
                        title: "クリック",
                        value: "\(summary.totalClicks)"
                    )
                    InputStatRow(
                        icon: "arrow.up.arrow.down",
                        title: "スクロール",
                        value: String(format: "%.0f", summary.totalScroll)
                    )
                }
            } else {
                Text("データがありません")
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    private func loadData() {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today)!

        totalTime = db.getTotalActiveTime(from: today, to: tomorrow)
        topApps = db.getAppUsageSummaries(from: today, to: tomorrow, limit: 10)
        inputSummary = db.getInputActivitySummary(from: today, to: tomorrow)
        focusSessions = db.getFocusSessions(from: today, to: tomorrow)

        let hourlyInput = db.getHourlyInputActivity(for: Date())
        hourlyActivity = hourlyInput.map { activity in
            HourlyActivityData(
                hour: activity.hour,
                activityLevel: Double(activity.keystrokes + activity.mouseClicks) / 100.0
            )
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        } else {
            return String(format: "%dm", minutes)
        }
    }
}

struct WeeklyReportView: View {
    let weeklyData: [DailyReportData]
    let currentWeekTotal: Int
    let previousWeekTotal: Int

    var weekChange: Double {
        guard previousWeekTotal > 0 else { return 0 }
        return Double(currentWeekTotal - previousWeekTotal) / Double(previousWeekTotal) * 100
    }

    var body: some View {
        VStack(spacing: 20) {
            // Summary
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("今週の合計")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatDuration(currentWeekTotal))
                        .font(.title)
                        .fontWeight(.bold)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("前週との比較")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack {
                        Image(systemName: weekChange >= 0 ? "arrow.up" : "arrow.down")
                            .foregroundColor(weekChange >= 0 ? .green : .red)
                        Text(String(format: "%.1f%%", abs(weekChange)))
                            .font(.title3)
                            .fontWeight(.medium)
                    }
                }

                Spacer()
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            .padding(.horizontal)

            // Weekly Chart
            VStack(alignment: .leading, spacing: 12) {
                Text("曜日別作業時間")
                    .font(.headline)

                if #available(macOS 14.0, *) {
                    Chart(weeklyData) { data in
                        BarMark(
                            x: .value("曜日", data.label),
                            y: .value("時間", data.totalSeconds / 60)
                        )
                        .foregroundStyle(Color.blue.gradient)
                    }
                    .chartYAxisLabel("分")
                    .frame(height: 250)
                } else {
                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(weeklyData) { data in
                            VStack {
                                let maxSeconds = weeklyData.map { $0.totalSeconds }.max() ?? 1
                                let height = maxSeconds > 0 ? CGFloat(data.totalSeconds) / CGFloat(maxSeconds) * 200 : 0

                                Rectangle()
                                    .fill(Color.blue)
                                    .frame(width: 40, height: max(1, height))

                                Text(data.label)
                                    .font(.caption)
                            }
                        }
                    }
                    .frame(height: 250)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            .padding(.horizontal)

            // Daily breakdown
            VStack(alignment: .leading, spacing: 12) {
                Text("日別詳細")
                    .font(.headline)

                ForEach(weeklyData) { data in
                    HStack {
                        Text(data.label)
                            .frame(width: 40, alignment: .leading)

                        GeometryReader { geometry in
                            let maxSeconds = weeklyData.map { $0.totalSeconds }.max() ?? 1
                            let width = maxSeconds > 0 ? CGFloat(data.totalSeconds) / CGFloat(maxSeconds) * geometry.size.width : 0

                            ZStack(alignment: .leading) {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))

                                Rectangle()
                                    .fill(Color.blue)
                                    .frame(width: width)
                            }
                            .cornerRadius(4)
                        }
                        .frame(height: 20)

                        Text(data.formattedDuration)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 80, alignment: .trailing)
                    }
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        } else {
            return String(format: "%dm", minutes)
        }
    }
}

struct MonthlyReportView: View {
    let monthlyData: [DailyReportData]

    var monthTotal: Int {
        monthlyData.reduce(0) { $0 + $1.totalSeconds }
    }

    var body: some View {
        VStack(spacing: 20) {
            // Summary
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("今月の合計")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(formatDuration(monthTotal))
                        .font(.title)
                        .fontWeight(.bold)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("1日平均")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    let activeDays = monthlyData.filter { $0.totalSeconds > 0 }.count
                    let avg = activeDays > 0 ? monthTotal / activeDays : 0
                    Text(formatDuration(avg))
                        .font(.title3)
                        .fontWeight(.medium)
                }
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            .padding(.horizontal)

            // Calendar View
            VStack(alignment: .leading, spacing: 12) {
                Text("日別作業時間カレンダー")
                    .font(.headline)

                CalendarHeatmap(data: monthlyData)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
            .padding(.horizontal)

            // Monthly Chart
            VStack(alignment: .leading, spacing: 12) {
                Text("日別推移")
                    .font(.headline)

                if #available(macOS 14.0, *) {
                    Chart(monthlyData) { data in
                        LineMark(
                            x: .value("日", data.date, unit: .day),
                            y: .value("時間", data.totalSeconds / 60)
                        )
                        .foregroundStyle(Color.blue)

                        AreaMark(
                            x: .value("日", data.date, unit: .day),
                            y: .value("時間", data.totalSeconds / 60)
                        )
                        .foregroundStyle(Color.blue.opacity(0.1))
                    }
                    .chartYAxisLabel("分")
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
            .padding(.horizontal)
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        } else {
            return String(format: "%dm", minutes)
        }
    }
}

struct CalendarHeatmap: View {
    let data: [DailyReportData]

    let columns = Array(repeating: GridItem(.fixed(30), spacing: 4), count: 7)

    var maxSeconds: Int {
        data.map { $0.totalSeconds }.max() ?? 1
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            // Weekday headers
            ForEach(["日", "月", "火", "水", "木", "金", "土"], id: \.self) { day in
                Text(day)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Empty cells for first week padding
            let calendar = Calendar.current
            if let firstDate = data.first?.date {
                let weekday = calendar.component(.weekday, from: firstDate)
                ForEach(0..<(weekday - 1), id: \.self) { _ in
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 30, height: 30)
                }
            }

            // Data cells
            ForEach(data) { item in
                let intensity = maxSeconds > 0 ? Double(item.totalSeconds) / Double(maxSeconds) : 0
                Rectangle()
                    .fill(Color.blue.opacity(max(0.1, intensity)))
                    .frame(width: 30, height: 30)
                    .cornerRadius(4)
                    .overlay(
                        Text(item.label)
                            .font(.caption2)
                            .foregroundColor(intensity > 0.5 ? .white : .primary)
                    )
            }
        }
    }
}

struct ReportCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                Spacer()
            }

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct InputStatRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 24)

            Text(title)

            Spacer()

            Text(value)
                .fontWeight(.medium)
        }
    }
}
