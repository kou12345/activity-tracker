import Foundation

struct AppUsageLog: Identifiable, Codable {
    var id: Int64?
    let bundleId: String
    let appName: String
    let startTime: Date
    var endTime: Date?
    var activeSeconds: Int

    init(id: Int64? = nil, bundleId: String, appName: String, startTime: Date, endTime: Date? = nil, activeSeconds: Int = 0) {
        self.id = id
        self.bundleId = bundleId
        self.appName = appName
        self.startTime = startTime
        self.endTime = endTime
        self.activeSeconds = activeSeconds
    }
}

struct AppUsageSummary: Identifiable {
    let bundleId: String
    let appName: String
    let totalSeconds: Int
    let sessionCount: Int

    var id: String { bundleId }

    var formattedDuration: String {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60

        if hours > 0 {
            return String(format: "%dh %02dm", hours, minutes)
        } else {
            return String(format: "%dm", minutes)
        }
    }

    var color: AppColor {
        AppColor.forBundleId(bundleId)
    }
}

enum AppColor {
    static func forBundleId(_ bundleId: String) -> NSColor {
        let colors: [NSColor] = [
            .systemGreen,
            .systemBlue,
            .systemPurple,
            .systemOrange,
            .systemPink,
            .systemYellow,
            .systemTeal,
            .systemIndigo
        ]

        let hash = abs(bundleId.hashValue)
        return colors[hash % colors.count]
    }
}

import AppKit
