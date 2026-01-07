import Foundation

struct FocusSession: Identifiable, Codable {
    var id: Int64?
    let bundleId: String
    let appName: String
    let startTime: Date
    var endTime: Date?
    var durationSeconds: Int

    init(id: Int64? = nil, bundleId: String, appName: String, startTime: Date, endTime: Date? = nil, durationSeconds: Int = 0) {
        self.id = id
        self.bundleId = bundleId
        self.appName = appName
        self.startTime = startTime
        self.endTime = endTime
        self.durationSeconds = durationSeconds
    }

    var formattedDuration: String {
        let hours = durationSeconds / 3600
        let minutes = (durationSeconds % 3600) / 60

        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        } else {
            return String(format: "%dm", minutes)
        }
    }
}

struct FocusMetrics {
    let appSwitchCount: Int
    let focusSessions: [FocusSession]
    let idleTimeSeconds: Int
    let averageSessionDuration: Int
    let longestSession: FocusSession?

    var totalFocusTime: Int {
        focusSessions.reduce(0) { $0 + $1.durationSeconds }
    }

    var formattedAverageSession: String {
        let minutes = averageSessionDuration / 60
        return "\(minutes)m"
    }

    var formattedIdleTime: String {
        let hours = idleTimeSeconds / 3600
        let minutes = (idleTimeSeconds % 3600) / 60

        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        } else {
            return String(format: "%dm", minutes)
        }
    }
}

struct IdleEvent: Identifiable, Codable {
    var id: Int64?
    let startTime: Date
    var endTime: Date?
    var durationSeconds: Int

    init(id: Int64? = nil, startTime: Date, endTime: Date? = nil, durationSeconds: Int = 0) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.durationSeconds = durationSeconds
    }
}
