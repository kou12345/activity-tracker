import SwiftUI

struct HistoryView: View {
    @State private var selectedDate: Date = Date()
    @State private var selectedMonthData: [DayData] = []
    @State private var dayDetail: DayDetailData?

    private let db = DatabaseManager.shared
    private let calendar = Calendar.current

    var body: some View {
        HStack(spacing: 0) {
            // Calendar
            VStack(spacing: 16) {
                // Month Navigation
                HStack {
                    Button(action: previousMonth) {
                        Image(systemName: "chevron.left")
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text(monthYearString(for: selectedDate))
                        .font(.headline)

                    Spacer()

                    Button(action: nextMonth) {
                        Image(systemName: "chevron.right")
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)

                // Weekday Headers
                HStack(spacing: 0) {
                    ForEach(["日", "月", "火", "水", "木", "金", "土"], id: \.self) { day in
                        Text(day)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }

                // Calendar Grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                    // Empty cells for padding
                    ForEach(0..<firstWeekdayOfMonth(), id: \.self) { _ in
                        Text("")
                            .frame(height: 50)
                    }

                    // Day cells
                    ForEach(selectedMonthData) { day in
                        DayCell(
                            day: day,
                            isSelected: calendar.isDate(day.date, inSameDayAs: selectedDate),
                            isToday: calendar.isDateInToday(day.date)
                        )
                        .onTapGesture {
                            selectedDate = day.date
                            loadDayDetail()
                        }
                    }
                }

                Spacer()
            }
            .padding()
            .frame(width: 350)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Day Detail
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(dayString(for: selectedDate))
                                .font(.title2)
                                .fontWeight(.bold)
                            if let detail = dayDetail {
                                Text("総作業時間: \(formatDuration(detail.totalSeconds))")
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal)

                    if let detail = dayDetail {
                        // Timeline
                        VStack(alignment: .leading, spacing: 12) {
                            Text("タイムライン")
                                .font(.headline)

                            if detail.logs.isEmpty {
                                Text("この日のデータはありません")
                                    .foregroundColor(.secondary)
                                    .padding()
                            } else {
                                ForEach(detail.logs) { log in
                                    TimelineRow(log: log)
                                }
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(12)
                        .padding(.horizontal)

                        // App Summary
                        VStack(alignment: .leading, spacing: 12) {
                            Text("アプリ別")
                                .font(.headline)

                            if detail.appSummaries.isEmpty {
                                Text("データがありません")
                                    .foregroundColor(.secondary)
                            } else {
                                ForEach(detail.appSummaries) { app in
                                    HStack {
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
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(12)
                        .padding(.horizontal)

                        // Input Stats
                        VStack(alignment: .leading, spacing: 12) {
                            Text("入力統計")
                                .font(.headline)

                            HStack(spacing: 24) {
                                VStack {
                                    Text("\(detail.inputSummary.totalKeystrokes)")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                    Text("キーストローク")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                VStack {
                                    Text("\(detail.inputSummary.totalClicks)")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                    Text("クリック")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                VStack {
                                    Text(String(format: "%.0f", detail.inputSummary.totalScroll))
                                        .font(.title3)
                                        .fontWeight(.bold)
                                    Text("スクロール")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    } else {
                        Text("日付を選択してください")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }

                    Spacer()
                }
                .padding(.vertical)
            }
        }
        .onAppear {
            loadMonthData()
            loadDayDetail()
        }
    }

    private func previousMonth() {
        if let newDate = calendar.date(byAdding: .month, value: -1, to: selectedDate) {
            selectedDate = newDate
            loadMonthData()
        }
    }

    private func nextMonth() {
        if let newDate = calendar.date(byAdding: .month, value: 1, to: selectedDate) {
            selectedDate = newDate
            loadMonthData()
        }
    }

    private func firstWeekdayOfMonth() -> Int {
        let components = calendar.dateComponents([.year, .month], from: selectedDate)
        guard let firstDay = calendar.date(from: components) else { return 0 }
        return calendar.component(.weekday, from: firstDay) - 1
    }

    private func loadMonthData() {
        let components = calendar.dateComponents([.year, .month], from: selectedDate)
        guard let monthStart = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: selectedDate) else { return }

        selectedMonthData = range.map { day in
            let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart)!
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: date)!
            let totalSeconds = db.getTotalActiveTime(from: date, to: dayEnd)

            return DayData(date: date, day: day, totalSeconds: totalSeconds)
        }
    }

    private func loadDayDetail() {
        let dayStart = calendar.startOfDay(for: selectedDate)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)!

        let logs = db.getAppUsageLogs(from: dayStart, to: dayEnd)
        let summaries = db.getAppUsageSummaries(from: dayStart, to: dayEnd, limit: 20)
        let inputSummary = db.getInputActivitySummary(from: dayStart, to: dayEnd)
        let totalSeconds = db.getTotalActiveTime(from: dayStart, to: dayEnd)

        dayDetail = DayDetailData(
            date: selectedDate,
            totalSeconds: totalSeconds,
            logs: logs,
            appSummaries: summaries,
            inputSummary: inputSummary
        )
    }

    private func monthYearString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy年 M月"
        return formatter.string(from: date)
    }

    private func dayString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日 (E)"
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: date)
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

struct DayData: Identifiable {
    let date: Date
    let day: Int
    let totalSeconds: Int

    var id: Date { date }

    var hasActivity: Bool { totalSeconds > 0 }

    var activityLevel: Double {
        // Normalize to 8 hours max
        min(1.0, Double(totalSeconds) / (8 * 3600))
    }
}

struct DayDetailData {
    let date: Date
    let totalSeconds: Int
    let logs: [AppUsageLog]
    let appSummaries: [AppUsageSummary]
    let inputSummary: InputActivitySummary
}

struct DayCell: View {
    let day: DayData
    let isSelected: Bool
    let isToday: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text("\(day.day)")
                .font(.system(.body, design: .rounded))
                .fontWeight(isToday ? .bold : .regular)

            if day.hasActivity {
                Circle()
                    .fill(Color.blue.opacity(max(0.3, day.activityLevel)))
                    .frame(width: 8, height: 8)
            } else {
                Circle()
                    .fill(Color.clear)
                    .frame(width: 8, height: 8)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isToday ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }
}

struct TimelineRow: View {
    let log: AppUsageLog

    var body: some View {
        HStack(spacing: 12) {
            Text(formatTime(log.startTime))
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 50)

            Circle()
                .fill(AppColor.forBundleId(log.bundleId))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(log.appName)
                    .lineLimit(1)

                Text(formatDuration(log.activeSeconds))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        } else if minutes > 0 {
            return String(format: "%dm", minutes)
        } else {
            return "\(seconds)s"
        }
    }
}
