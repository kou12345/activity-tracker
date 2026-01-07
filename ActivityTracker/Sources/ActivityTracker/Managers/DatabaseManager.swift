import Foundation
import SQLite

class DatabaseManager {
    static let shared = DatabaseManager()

    private var db: Connection?

    // Tables
    private let appUsageLogs = Table("app_usage_logs")
    private let inputActivities = Table("input_activities")
    private let focusSessions = Table("focus_sessions")
    private let idleEvents = Table("idle_events")

    // App Usage Columns
    private let id = Expression<Int64>("id")
    private let bundleId = Expression<String>("bundle_id")
    private let appName = Expression<String>("app_name")
    private let startTime = Expression<Date>("start_time")
    private let endTime = Expression<Date?>("end_time")
    private let activeSeconds = Expression<Int>("active_seconds")

    // Input Activity Columns
    private let timestamp = Expression<Date>("timestamp")
    private let keystrokes = Expression<Int>("keystrokes")
    private let mouseClicks = Expression<Int>("mouse_clicks")
    private let scrollAmount = Expression<Double>("scroll_amount")

    // Focus Session Columns
    private let durationSeconds = Expression<Int>("duration_seconds")

    private init() {
        setupDatabase()
    }

    private func setupDatabase() {
        do {
            let fileManager = FileManager.default
            let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let appDir = appSupport.appendingPathComponent("ActivityTracker", isDirectory: true)

            if !fileManager.fileExists(atPath: appDir.path) {
                try fileManager.createDirectory(at: appDir, withIntermediateDirectories: true)
            }

            let dbPath = appDir.appendingPathComponent("activity_tracker.db").path
            db = try Connection(dbPath)

            createTables()
        } catch {
            print("Database setup error: \(error)")
        }
    }

    private func createTables() {
        guard let db = db else { return }

        do {
            // App Usage Logs
            try db.run(appUsageLogs.create(ifNotExists: true) { t in
                t.column(id, primaryKey: .autoincrement)
                t.column(bundleId)
                t.column(appName)
                t.column(startTime)
                t.column(endTime)
                t.column(activeSeconds, defaultValue: 0)
            })

            try db.run(appUsageLogs.createIndex(startTime, ifNotExists: true))
            try db.run(appUsageLogs.createIndex(bundleId, ifNotExists: true))

            // Input Activities
            try db.run(inputActivities.create(ifNotExists: true) { t in
                t.column(id, primaryKey: .autoincrement)
                t.column(timestamp)
                t.column(keystrokes, defaultValue: 0)
                t.column(mouseClicks, defaultValue: 0)
                t.column(scrollAmount, defaultValue: 0)
            })

            try db.run(inputActivities.createIndex(timestamp, ifNotExists: true))

            // Focus Sessions
            try db.run(focusSessions.create(ifNotExists: true) { t in
                t.column(id, primaryKey: .autoincrement)
                t.column(bundleId)
                t.column(appName)
                t.column(startTime)
                t.column(endTime)
                t.column(durationSeconds, defaultValue: 0)
            })

            try db.run(focusSessions.createIndex(startTime, ifNotExists: true))

            // Idle Events
            try db.run(idleEvents.create(ifNotExists: true) { t in
                t.column(id, primaryKey: .autoincrement)
                t.column(startTime)
                t.column(endTime)
                t.column(durationSeconds, defaultValue: 0)
            })

            try db.run(idleEvents.createIndex(startTime, ifNotExists: true))

        } catch {
            print("Table creation error: \(error)")
        }
    }

    // MARK: - App Usage Operations

    @discardableResult
    func insertAppUsage(_ log: AppUsageLog) -> Int64? {
        guard let db = db else { return nil }

        do {
            let insert = appUsageLogs.insert(
                bundleId <- log.bundleId,
                appName <- log.appName,
                startTime <- log.startTime,
                endTime <- log.endTime,
                activeSeconds <- log.activeSeconds
            )
            return try db.run(insert)
        } catch {
            print("Insert app usage error: \(error)")
            return nil
        }
    }

    func updateAppUsage(_ log: AppUsageLog) {
        guard let db = db, let logId = log.id else { return }

        do {
            let record = appUsageLogs.filter(id == logId)
            try db.run(record.update(
                endTime <- log.endTime,
                activeSeconds <- log.activeSeconds
            ))
        } catch {
            print("Update app usage error: \(error)")
        }
    }

    func getAppUsageLogs(from startDate: Date, to endDate: Date) -> [AppUsageLog] {
        guard let db = db else { return [] }

        do {
            let query = appUsageLogs
                .filter(startTime >= startDate && startTime < endDate)
                .order(startTime.desc)

            return try db.prepare(query).map { row in
                AppUsageLog(
                    id: row[id],
                    bundleId: row[bundleId],
                    appName: row[appName],
                    startTime: row[startTime],
                    endTime: row[endTime],
                    activeSeconds: row[activeSeconds]
                )
            }
        } catch {
            print("Get app usage logs error: \(error)")
            return []
        }
    }

    func getAppUsageSummaries(from startDate: Date, to endDate: Date, limit: Int = 10) -> [AppUsageSummary] {
        guard let db = db else { return [] }

        do {
            let query = """
                SELECT bundle_id, app_name, SUM(active_seconds) as total_seconds, COUNT(*) as session_count
                FROM app_usage_logs
                WHERE start_time >= ? AND start_time < ?
                GROUP BY bundle_id
                ORDER BY total_seconds DESC
                LIMIT ?
            """

            var summaries: [AppUsageSummary] = []
            let stmt = try db.prepare(query)

            for row in try stmt.bind(startDate.timeIntervalSince1970, endDate.timeIntervalSince1970, limit) {
                if let bundleIdValue = row[0] as? String,
                   let appNameValue = row[1] as? String,
                   let totalSeconds = row[2] as? Int64,
                   let sessionCount = row[3] as? Int64 {
                    summaries.append(AppUsageSummary(
                        bundleId: bundleIdValue,
                        appName: appNameValue,
                        totalSeconds: Int(totalSeconds),
                        sessionCount: Int(sessionCount)
                    ))
                }
            }

            return summaries
        } catch {
            print("Get app usage summaries error: \(error)")
            return []
        }
    }

    func getTotalActiveTime(from startDate: Date, to endDate: Date) -> Int {
        guard let db = db else { return 0 }

        do {
            let query = appUsageLogs
                .filter(startTime >= startDate && startTime < endDate)
                .select(activeSeconds.sum)

            if let total = try db.scalar(query) {
                return total
            }
            return 0
        } catch {
            print("Get total active time error: \(error)")
            return 0
        }
    }

    // MARK: - Input Activity Operations

    @discardableResult
    func insertInputActivity(_ activity: InputActivity) -> Int64? {
        guard let db = db else { return nil }

        do {
            let insert = inputActivities.insert(
                timestamp <- activity.timestamp,
                keystrokes <- activity.keystrokes,
                mouseClicks <- activity.mouseClicks,
                scrollAmount <- activity.scrollAmount
            )
            return try db.run(insert)
        } catch {
            print("Insert input activity error: \(error)")
            return nil
        }
    }

    func getInputActivitySummary(from startDate: Date, to endDate: Date) -> InputActivitySummary {
        guard let db = db else {
            return InputActivitySummary(totalKeystrokes: 0, totalClicks: 0, totalScroll: 0, period: DateInterval(start: startDate, end: endDate))
        }

        do {
            let query = inputActivities
                .filter(timestamp >= startDate && timestamp < endDate)
                .select(keystrokes.sum, mouseClicks.sum, scrollAmount.sum)

            if let row = try db.pluck(query) {
                return InputActivitySummary(
                    totalKeystrokes: row[keystrokes.sum] ?? 0,
                    totalClicks: row[mouseClicks.sum] ?? 0,
                    totalScroll: row[scrollAmount.sum] ?? 0,
                    period: DateInterval(start: startDate, end: endDate)
                )
            }
        } catch {
            print("Get input activity summary error: \(error)")
        }

        return InputActivitySummary(totalKeystrokes: 0, totalClicks: 0, totalScroll: 0, period: DateInterval(start: startDate, end: endDate))
    }

    func getHourlyInputActivity(for date: Date) -> [HourlyInputActivity] {
        guard let db = db else { return [] }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)

        var hourlyData: [HourlyInputActivity] = []

        for hour in 0..<24 {
            let hourStart = calendar.date(byAdding: .hour, value: hour, to: startOfDay)!
            let hourEnd = calendar.date(byAdding: .hour, value: hour + 1, to: startOfDay)!

            do {
                let query = inputActivities
                    .filter(timestamp >= hourStart && timestamp < hourEnd)
                    .select(keystrokes.sum, mouseClicks.sum, scrollAmount.sum)

                if let row = try db.pluck(query) {
                    hourlyData.append(HourlyInputActivity(
                        hour: hour,
                        keystrokes: row[keystrokes.sum] ?? 0,
                        mouseClicks: row[mouseClicks.sum] ?? 0,
                        scrollAmount: row[scrollAmount.sum] ?? 0
                    ))
                } else {
                    hourlyData.append(HourlyInputActivity(hour: hour, keystrokes: 0, mouseClicks: 0, scrollAmount: 0))
                }
            } catch {
                hourlyData.append(HourlyInputActivity(hour: hour, keystrokes: 0, mouseClicks: 0, scrollAmount: 0))
            }
        }

        return hourlyData
    }

    // MARK: - Focus Session Operations

    @discardableResult
    func insertFocusSession(_ session: FocusSession) -> Int64? {
        guard let db = db else { return nil }

        do {
            let insert = focusSessions.insert(
                bundleId <- session.bundleId,
                appName <- session.appName,
                startTime <- session.startTime,
                endTime <- session.endTime,
                durationSeconds <- session.durationSeconds
            )
            return try db.run(insert)
        } catch {
            print("Insert focus session error: \(error)")
            return nil
        }
    }

    func updateFocusSession(_ session: FocusSession) {
        guard let db = db, let sessionId = session.id else { return }

        do {
            let record = focusSessions.filter(id == sessionId)
            try db.run(record.update(
                endTime <- session.endTime,
                durationSeconds <- session.durationSeconds
            ))
        } catch {
            print("Update focus session error: \(error)")
        }
    }

    func getFocusSessions(from startDate: Date, to endDate: Date) -> [FocusSession] {
        guard let db = db else { return [] }

        do {
            let query = focusSessions
                .filter(startTime >= startDate && startTime < endDate)
                .order(startTime.desc)

            return try db.prepare(query).map { row in
                FocusSession(
                    id: row[id],
                    bundleId: row[bundleId],
                    appName: row[appName],
                    startTime: row[startTime],
                    endTime: row[endTime],
                    durationSeconds: row[durationSeconds]
                )
            }
        } catch {
            print("Get focus sessions error: \(error)")
            return []
        }
    }

    func getAppSwitchCount(from startDate: Date, to endDate: Date) -> Int {
        guard let db = db else { return 0 }

        do {
            let query = appUsageLogs
                .filter(startTime >= startDate && startTime < endDate)
                .count

            return try db.scalar(query)
        } catch {
            print("Get app switch count error: \(error)")
            return 0
        }
    }

    // MARK: - Idle Event Operations

    @discardableResult
    func insertIdleEvent(_ event: IdleEvent) -> Int64? {
        guard let db = db else { return nil }

        do {
            let insert = idleEvents.insert(
                startTime <- event.startTime,
                endTime <- event.endTime,
                durationSeconds <- event.durationSeconds
            )
            return try db.run(insert)
        } catch {
            print("Insert idle event error: \(error)")
            return nil
        }
    }

    func updateIdleEvent(_ event: IdleEvent) {
        guard let db = db, let eventId = event.id else { return }

        do {
            let record = idleEvents.filter(id == eventId)
            try db.run(record.update(
                endTime <- event.endTime,
                durationSeconds <- event.durationSeconds
            ))
        } catch {
            print("Update idle event error: \(error)")
        }
    }

    func getTotalIdleTime(from startDate: Date, to endDate: Date) -> Int {
        guard let db = db else { return 0 }

        do {
            let query = idleEvents
                .filter(startTime >= startDate && startTime < endDate)
                .select(durationSeconds.sum)

            if let total = try db.scalar(query) {
                return total
            }
            return 0
        } catch {
            print("Get total idle time error: \(error)")
            return 0
        }
    }

    // MARK: - Data Export

    func exportToCSV(from startDate: Date, to endDate: Date) -> String {
        var csv = "App Name,Bundle ID,Start Time,End Time,Active Seconds\n"

        let logs = getAppUsageLogs(from: startDate, to: endDate)
        let dateFormatter = ISO8601DateFormatter()

        for log in logs {
            let endTimeStr = log.endTime.map { dateFormatter.string(from: $0) } ?? ""
            csv += "\"\(log.appName)\",\"\(log.bundleId)\",\"\(dateFormatter.string(from: log.startTime))\",\"\(endTimeStr)\",\(log.activeSeconds)\n"
        }

        return csv
    }

    func exportToJSON(from startDate: Date, to endDate: Date) -> String {
        let logs = getAppUsageLogs(from: startDate, to: endDate)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted

        do {
            let data = try encoder.encode(logs)
            return String(data: data, encoding: .utf8) ?? "[]"
        } catch {
            return "[]"
        }
    }

    // MARK: - Data Cleanup

    func clearAllData() {
        guard let db = db else { return }

        do {
            try db.run(appUsageLogs.delete())
            try db.run(inputActivities.delete())
            try db.run(focusSessions.delete())
            try db.run(idleEvents.delete())
        } catch {
            print("Clear data error: \(error)")
        }
    }

    func clearDataBefore(_ date: Date) {
        guard let db = db else { return }

        do {
            try db.run(appUsageLogs.filter(startTime < date).delete())
            try db.run(inputActivities.filter(timestamp < date).delete())
            try db.run(focusSessions.filter(startTime < date).delete())
            try db.run(idleEvents.filter(startTime < date).delete())
        } catch {
            print("Clear old data error: \(error)")
        }
    }
}
