import Foundation
import AppKit
import Combine

class TrackingService {
    static let shared = TrackingService()

    private var currentApp: AppUsageLog?
    private var currentFocusSession: FocusSession?
    private var trackingTimer: Timer?
    private var isTracking = false
    private var lastActivityTime: Date = Date()

    private let db = DatabaseManager.shared
    private let settings = UserSettings.shared

    private var workspaceObserver: NSObjectProtocol?

    private init() {}

    func startTracking() {
        guard !isTracking else { return }
        isTracking = true

        // Observe app activation
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleAppActivation(notification)
        }

        // Start periodic update timer
        trackingTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateCurrentAppDuration()
        }

        // Initialize with current app
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            startTrackingApp(frontApp)
        }
    }

    func stopTracking() {
        isTracking = false

        if let observer = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }

        trackingTimer?.invalidate()
        trackingTimer = nil

        // Close current session
        endCurrentApp()
        endCurrentFocusSession()
    }

    private func handleAppActivation(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }

        // End current app tracking
        endCurrentApp()

        // Start tracking new app
        startTrackingApp(app)
    }

    private func startTrackingApp(_ app: NSRunningApplication) {
        let bundleId = app.bundleIdentifier ?? "unknown"
        let appName = app.localizedName ?? "Unknown App"

        // Check if app is excluded
        if settings.isAppExcluded(bundleId) {
            currentApp = nil
            return
        }

        let now = Date()

        // Create new app usage log
        let log = AppUsageLog(
            bundleId: bundleId,
            appName: appName,
            startTime: now
        )

        if let insertedId = db.insertAppUsage(log) {
            currentApp = AppUsageLog(
                id: insertedId,
                bundleId: bundleId,
                appName: appName,
                startTime: now
            )
        }

        // Handle focus session
        handleFocusSessionChange(bundleId: bundleId, appName: appName)
    }

    private func endCurrentApp() {
        guard var app = currentApp else { return }

        let now = Date()
        app.endTime = now
        app.activeSeconds = Int(now.timeIntervalSince(app.startTime))

        db.updateAppUsage(app)
        currentApp = nil
    }

    private func updateCurrentAppDuration() {
        guard var app = currentApp else { return }

        let now = Date()
        app.endTime = now
        app.activeSeconds = Int(now.timeIntervalSince(app.startTime))

        db.updateAppUsage(app)
        currentApp = app

        // Update focus session
        updateCurrentFocusSession()

        // Update app state
        Task { @MainActor in
            AppState.shared.updateData()
        }
    }

    // MARK: - Focus Session Management

    private func handleFocusSessionChange(bundleId: String, appName: String) {
        // If same app, continue session
        if let session = currentFocusSession, session.bundleId == bundleId {
            return
        }

        // End previous session
        endCurrentFocusSession()

        // Start new focus session
        let now = Date()
        let session = FocusSession(
            bundleId: bundleId,
            appName: appName,
            startTime: now
        )

        if let insertedId = db.insertFocusSession(session) {
            currentFocusSession = FocusSession(
                id: insertedId,
                bundleId: bundleId,
                appName: appName,
                startTime: now
            )
        }
    }

    private func endCurrentFocusSession() {
        guard var session = currentFocusSession else { return }

        let now = Date()
        session.endTime = now
        session.durationSeconds = Int(now.timeIntervalSince(session.startTime))

        db.updateFocusSession(session)
        currentFocusSession = nil
    }

    private func updateCurrentFocusSession() {
        guard var session = currentFocusSession else { return }

        let now = Date()
        session.endTime = now
        session.durationSeconds = Int(now.timeIntervalSince(session.startTime))

        db.updateFocusSession(session)
        currentFocusSession = session
    }

    // MARK: - Activity Recording

    func recordActivity() {
        lastActivityTime = Date()
    }
}
