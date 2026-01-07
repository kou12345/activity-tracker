import SwiftUI
import Charts

struct FocusView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedPeriod: TimePeriod = .today
    @State private var focusSessions: [FocusSession] = []
    @State private var metrics: FocusMetrics?
    @State private var hourlyFocus: [HourlyFocusData] = []

    private let db = DatabaseManager.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                HStack {
                    Text("集中度分析")
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
                .padding(.horizontal)

                // Metrics Cards
                if let metrics = metrics {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        MetricCard(
                            title: "集中セッション",
                            value: "\(metrics.focusSessions.count)",
                            subtitle: "回",
                            icon: "brain.head.profile",
                            color: .purple
                        )

                        MetricCard(
                            title: "平均集中時間",
                            value: metrics.formattedAverageSession,
                            subtitle: "/ セッション",
                            icon: "timer",
                            color: .blue
                        )

                        MetricCard(
                            title: "アプリ切替",
                            value: "\(metrics.appSwitchCount)",
                            subtitle: "回",
                            icon: "arrow.triangle.swap",
                            color: .orange
                        )

                        MetricCard(
                            title: "アイドル時間",
                            value: metrics.formattedIdleTime,
                            subtitle: "",
                            icon: "moon.zzz.fill",
                            color: .gray
                        )
                    }
                    .padding(.horizontal)
                }

                // Focus Timeline
                VStack(alignment: .leading, spacing: 12) {
                    Text("時間帯別集中度")
                        .font(.headline)

                    if #available(macOS 14.0, *) {
                        Chart(hourlyFocus) { data in
                            AreaMark(
                                x: .value("時間", data.hour),
                                y: .value("集中度", data.focusScore)
                            )
                            .foregroundStyle(Color.purple.opacity(0.3).gradient)

                            LineMark(
                                x: .value("時間", data.hour),
                                y: .value("集中度", data.focusScore)
                            )
                            .foregroundStyle(Color.purple)
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
                        .chartYAxis {
                            AxisMarks(position: .leading)
                        }
                        .frame(height: 200)
                    } else {
                        SimpleFocusChart(data: hourlyFocus)
                            .frame(height: 200)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
                .padding(.horizontal)

                // Longest Focus Session
                if let longest = metrics?.longestSession {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("最長集中セッション")
                            .font(.headline)

                        HStack(spacing: 16) {
                            Circle()
                                .fill(AppColor.forBundleId(longest.bundleId))
                                .frame(width: 40, height: 40)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(longest.appName)
                                    .font(.title3)
                                    .fontWeight(.medium)
                                Text(formatSessionTime(longest))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Text(longest.formattedDuration)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.purple)
                        }
                    }
                    .padding()
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }

                // Recent Sessions
                VStack(alignment: .leading, spacing: 12) {
                    Text("最近の集中セッション")
                        .font(.headline)

                    if focusSessions.isEmpty {
                        Text("データがありません")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding()
                    } else {
                        LazyVStack(spacing: 8) {
                            ForEach(focusSessions.prefix(10)) { session in
                                FocusSessionRow(session: session)
                            }
                        }
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
        .onChange(of: selectedPeriod) { _ in
            loadData()
        }
    }

    private func loadData() {
        let (startDate, endDate) = selectedPeriod.dateRange

        focusSessions = db.getFocusSessions(from: startDate, to: endDate)
        let switchCount = db.getAppSwitchCount(from: startDate, to: endDate)
        let idleTime = db.getTotalIdleTime(from: startDate, to: endDate)
        let avgDuration = focusSessions.isEmpty ? 0 : focusSessions.reduce(0) { $0 + $1.durationSeconds } / focusSessions.count
        let longest = focusSessions.max { $0.durationSeconds < $1.durationSeconds }

        metrics = FocusMetrics(
            appSwitchCount: switchCount,
            focusSessions: focusSessions,
            idleTimeSeconds: idleTime,
            averageSessionDuration: avgDuration,
            longestSession: longest
        )

        // Calculate hourly focus
        hourlyFocus = calculateHourlyFocus(sessions: focusSessions, period: selectedPeriod)
    }

    private func calculateHourlyFocus(sessions: [FocusSession], period: TimePeriod) -> [HourlyFocusData] {
        var hourlyData: [Int: Int] = [:]

        for session in sessions {
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: session.startTime)
            hourlyData[hour, default: 0] += session.durationSeconds
        }

        let maxSeconds = hourlyData.values.max() ?? 1

        return (0..<24).map { hour in
            let seconds = hourlyData[hour] ?? 0
            let score = maxSeconds > 0 ? Double(seconds) / Double(maxSeconds) * 100 : 0
            return HourlyFocusData(hour: hour, focusScore: score)
        }
    }

    private func formatSessionTime(_ session: FocusSession) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let start = formatter.string(from: session.startTime)
        let end = session.endTime.map { formatter.string(from: $0) } ?? "進行中"
        return "\(start) - \(end)"
    }
}

struct HourlyFocusData: Identifiable {
    let hour: Int
    let focusScore: Double
    var id: Int { hour }
}

struct MetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }

            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

struct FocusSessionRow: View {
    let session: FocusSession

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(AppColor.forBundleId(session.bundleId))
                .frame(width: 8, height: 8)

            Text(session.appName)
                .lineLimit(1)

            Spacer()

            Text(formatTime(session.startTime))
                .font(.caption)
                .foregroundColor(.secondary)

            Text(session.formattedDuration)
                .font(.system(.caption, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(4)
        }
        .padding(.vertical, 4)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

struct SimpleFocusChart: View {
    let data: [HourlyFocusData]

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                guard !data.isEmpty else { return }

                let width = geometry.size.width
                let height = geometry.size.height
                let stepX = width / CGFloat(data.count - 1)

                let maxScore = data.map { $0.focusScore }.max() ?? 100

                for (index, item) in data.enumerated() {
                    let x = CGFloat(index) * stepX
                    let y = height - (CGFloat(item.focusScore) / CGFloat(maxScore)) * height

                    if index == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(Color.purple, lineWidth: 2)
        }
    }
}
