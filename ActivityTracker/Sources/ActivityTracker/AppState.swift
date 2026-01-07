import SwiftUI
import Combine

@MainActor
class AppState: ObservableObject {
    static let shared = AppState()

    @Published var todayTotalSeconds: Int = 0
    @Published var topApps: [AppUsageSummary] = []
    @Published var selectedTab: DetailTab = .dashboard
    @Published var selectedReportPeriod: ReportPeriod = .daily

    private var cancellables = Set<AnyCancellable>()
    private var updateTimer: Timer?

    var formattedTodayTime: String {
        formatDuration(seconds: todayTotalSeconds)
    }

    private init() {
        startPeriodicUpdate()
    }

    private func startPeriodicUpdate() {
        updateData()

        // Update every 30 seconds
        updateTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateData()
            }
        }
    }

    func updateData() {
        let db = DatabaseManager.shared
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

        todayTotalSeconds = db.getTotalActiveTime(from: today, to: tomorrow)
        topApps = db.getAppUsageSummaries(from: today, to: tomorrow, limit: 10)
    }

    func formatDuration(seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60

        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        } else {
            return String(format: "%dm", minutes)
        }
    }
}

enum DetailTab: String, CaseIterable, Identifiable {
    case dashboard = "ダッシュボード"
    case apps = "アプリ別"
    case focus = "集中度"
    case reports = "レポート"
    case history = "履歴"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "gauge"
        case .apps: return "app.badge"
        case .focus: return "brain.head.profile"
        case .reports: return "doc.text.magnifyingglass"
        case .history: return "calendar"
        }
    }
}

enum ReportPeriod: String, CaseIterable, Identifiable {
    case daily = "日次"
    case weekly = "週次"
    case monthly = "月次"

    var id: String { rawValue }
}
