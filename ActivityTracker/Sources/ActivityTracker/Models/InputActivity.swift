import Foundation

struct InputActivity: Identifiable, Codable {
    var id: Int64?
    let timestamp: Date
    let keystrokes: Int
    let mouseClicks: Int
    let scrollAmount: Double

    init(id: Int64? = nil, timestamp: Date, keystrokes: Int = 0, mouseClicks: Int = 0, scrollAmount: Double = 0) {
        self.id = id
        self.timestamp = timestamp
        self.keystrokes = keystrokes
        self.mouseClicks = mouseClicks
        self.scrollAmount = scrollAmount
    }
}

struct InputActivitySummary {
    let totalKeystrokes: Int
    let totalClicks: Int
    let totalScroll: Double
    let period: DateInterval

    var averageKeystrokesPerHour: Double {
        let hours = period.duration / 3600
        guard hours > 0 else { return 0 }
        return Double(totalKeystrokes) / hours
    }

    var averageClicksPerHour: Double {
        let hours = period.duration / 3600
        guard hours > 0 else { return 0 }
        return Double(totalClicks) / hours
    }
}

struct HourlyInputActivity: Identifiable {
    let hour: Int
    let keystrokes: Int
    let mouseClicks: Int
    let scrollAmount: Double

    var id: Int { hour }
}
