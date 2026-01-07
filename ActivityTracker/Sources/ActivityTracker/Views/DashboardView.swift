import SwiftUI
import Charts

struct DashboardView: View {
    @EnvironmentObject var appState: AppState
    @State private var inputSummary: InputActivitySummary?
    @State private var hourlyActivity: [HourlyActivityData] = []
    @State private var focusMetrics: FocusMetrics?

    private let db = DatabaseManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("今日のサマリー")
                            .font(.title)
                            .fontWeight(.bold)
                        Text(Date(), style: .date)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal)

                // Stats Cards
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    StatCard(
                        title: "総作業時間",
                        value: appState.formattedTodayTime,
                        icon: "clock.fill",
                        color: .blue
                    )

                    StatCard(
                        title: "アプリ切替",
                        value: "\(focusMetrics?.appSwitchCount ?? 0)回",
                        icon: "arrow.triangle.swap",
                        color: .orange
                    )

                    StatCard(
                        title: "キーストローク",
                        value: formatNumber(inputSummary?.totalKeystrokes ?? 0),
                        icon: "keyboard.fill",
                        color: .purple
                    )

                    StatCard(
                        title: "クリック",
                        value: formatNumber(inputSummary?.totalClicks ?? 0),
                        icon: "cursorarrow.click.2",
                        color: .green
                    )
                }
                .padding(.horizontal)

                // Charts Row
                HStack(spacing: 16) {
                    // Hourly Activity Chart
                    VStack(alignment: .leading, spacing: 12) {
                        Text("時間帯別アクティビティ")
                            .font(.headline)

                        if #available(macOS 14.0, *) {
                            Chart(hourlyActivity) { data in
                                BarMark(
                                    x: .value("時間", data.hour),
                                    y: .value("アクティビティ", data.activityLevel)
                                )
                                .foregroundStyle(Color.accentColor.gradient)
                            }
                            .chartXAxis {
                                AxisMarks(values: [0, 6, 12, 18, 23]) { value in
                                    AxisValueLabel {
                                        if let hour = value.as(Int.self) {
                                            Text("\(hour)時")
                                        }
                                    }
                                }
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

                    // Top Apps
                    VStack(alignment: .leading, spacing: 12) {
                        Text("使用アプリ TOP 5")
                            .font(.headline)

                        if appState.topApps.isEmpty {
                            Text("データがありません")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(appState.topApps.prefix(5)) { app in
                                    AppProgressRow(app: app, maxSeconds: appState.topApps.first?.totalSeconds ?? 1)
                                }
                            }
                        }

                        Spacer()
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)
                    .frame(minWidth: 300)
                }
                .padding(.horizontal)

                // Focus Sessions
                VStack(alignment: .leading, spacing: 12) {
                    Text("集中セッション")
                        .font(.headline)

                    if let metrics = focusMetrics, !metrics.focusSessions.isEmpty {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            FocusStatCard(
                                title: "セッション数",
                                value: "\(metrics.focusSessions.count)"
                            )
                            FocusStatCard(
                                title: "平均時間",
                                value: metrics.formattedAverageSession
                            )
                            FocusStatCard(
                                title: "アイドル時間",
                                value: metrics.formattedIdleTime
                            )
                        }
                    } else {
                        Text("データがありません")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
                .padding(.horizontal)

                Spacer()
            }
            .padding(.vertical)
        }
        .onAppear {
            loadData()
        }
    }

    private func loadData() {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

        inputSummary = db.getInputActivitySummary(from: today, to: tomorrow)

        let hourlyInput = db.getHourlyInputActivity(for: Date())
        hourlyActivity = hourlyInput.map { activity in
            HourlyActivityData(
                hour: activity.hour,
                activityLevel: Double(activity.keystrokes + activity.mouseClicks) / 100.0
            )
        }

        let sessions = db.getFocusSessions(from: today, to: tomorrow)
        let switchCount = db.getAppSwitchCount(from: today, to: tomorrow)
        let idleTime = db.getTotalIdleTime(from: today, to: tomorrow)
        let avgDuration = sessions.isEmpty ? 0 : sessions.reduce(0) { $0 + $1.durationSeconds } / sessions.count
        let longest = sessions.max { $0.durationSeconds < $1.durationSeconds }

        focusMetrics = FocusMetrics(
            appSwitchCount: switchCount,
            focusSessions: sessions,
            idleTimeSeconds: idleTime,
            averageSessionDuration: avgDuration,
            longestSession: longest
        )
    }

    private func formatNumber(_ number: Int) -> String {
        if number >= 1000 {
            return String(format: "%.1fK", Double(number) / 1000.0)
        }
        return "\(number)"
    }
}

struct HourlyActivityData: Identifiable {
    let hour: Int
    let activityLevel: Double
    var id: Int { hour }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
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

struct AppProgressRow: View {
    let app: AppUsageSummary
    let maxSeconds: Int

    var progress: Double {
        guard maxSeconds > 0 else { return 0 }
        return Double(app.totalSeconds) / Double(maxSeconds)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(Color(app.color))
                    .frame(width: 8, height: 8)
                Text(app.appName)
                    .lineLimit(1)
                Spacer()
                Text(app.formattedDuration)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 4)
                        .cornerRadius(2)

                    Rectangle()
                        .fill(Color(app.color))
                        .frame(width: geometry.size.width * progress, height: 4)
                        .cornerRadius(2)
                }
            }
            .frame(height: 4)
        }
    }
}

struct FocusStatCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
    }
}

struct SimpleBarChart: View {
    let data: [HourlyActivityData]

    var maxValue: Double {
        data.map { $0.activityLevel }.max() ?? 1
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(data) { item in
                VStack {
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(height: max(1, CGFloat(item.activityLevel / maxValue) * 180))
                }
            }
        }
    }
}

#Preview {
    DashboardView()
        .environmentObject(AppState.shared)
}
