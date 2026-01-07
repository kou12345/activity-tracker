import Foundation

class UserSettings: ObservableObject {
    static let shared = UserSettings()

    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
        }
    }

    @Published var idleThresholdMinutes: Int {
        didSet {
            UserDefaults.standard.set(idleThresholdMinutes, forKey: "idleThresholdMinutes")
        }
    }

    @Published var excludedBundleIds: Set<String> {
        didSet {
            UserDefaults.standard.set(Array(excludedBundleIds), forKey: "excludedBundleIds")
        }
    }

    @Published var showTimeInMenuBar: Bool {
        didSet {
            UserDefaults.standard.set(showTimeInMenuBar, forKey: "showTimeInMenuBar")
        }
    }

    @Published var useDecimalTime: Bool {
        didSet {
            UserDefaults.standard.set(useDecimalTime, forKey: "useDecimalTime")
        }
    }

    var idleThresholdSeconds: Int {
        idleThresholdMinutes * 60
    }

    private init() {
        self.launchAtLogin = UserDefaults.standard.bool(forKey: "launchAtLogin")

        let savedIdleThreshold = UserDefaults.standard.integer(forKey: "idleThresholdMinutes")
        self.idleThresholdMinutes = savedIdleThreshold > 0 ? savedIdleThreshold : 5

        if let savedExcluded = UserDefaults.standard.array(forKey: "excludedBundleIds") as? [String] {
            self.excludedBundleIds = Set(savedExcluded)
        } else {
            self.excludedBundleIds = []
        }

        self.showTimeInMenuBar = UserDefaults.standard.object(forKey: "showTimeInMenuBar") as? Bool ?? true
        self.useDecimalTime = UserDefaults.standard.bool(forKey: "useDecimalTime")
    }

    func isAppExcluded(_ bundleId: String) -> Bool {
        excludedBundleIds.contains(bundleId)
    }

    func toggleAppExclusion(_ bundleId: String) {
        if excludedBundleIds.contains(bundleId) {
            excludedBundleIds.remove(bundleId)
        } else {
            excludedBundleIds.insert(bundleId)
        }
    }
}

enum ExportFormat: String, CaseIterable, Identifiable {
    case csv = "CSV"
    case json = "JSON"

    var id: String { rawValue }

    var fileExtension: String {
        rawValue.lowercased()
    }
}
