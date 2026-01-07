import Foundation
import AppKit
import Combine

class InputMonitor {
    static let shared = InputMonitor()

    private var keyEventMonitor: Any?
    private var mouseEventMonitor: Any?
    private var scrollEventMonitor: Any?

    private var keystrokeCount: Int = 0
    private var clickCount: Int = 0
    private var scrollAmount: Double = 0

    private var aggregationTimer: Timer?
    private var idleTimer: Timer?
    private var currentIdleEvent: IdleEvent?

    private var lastActivityTime: Date = Date()
    private var isIdle: Bool = false

    private let db = DatabaseManager.shared
    private let settings = UserSettings.shared

    private let aggregationInterval: TimeInterval = 60 // Save every minute

    private init() {}

    func startMonitoring() {
        // Monitor key events
        keyEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] _ in
            self?.recordKeystroke()
        }

        // Monitor mouse clicks
        mouseEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.recordClick()
        }

        // Monitor scroll events
        scrollEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.recordScroll(event)
        }

        // Start aggregation timer
        aggregationTimer = Timer.scheduledTimer(withTimeInterval: aggregationInterval, repeats: true) { [weak self] _ in
            self?.saveAggregatedActivity()
        }

        // Start idle detection timer
        idleTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.checkIdleState()
        }
    }

    func stopMonitoring() {
        if let monitor = keyEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = mouseEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = scrollEventMonitor {
            NSEvent.removeMonitor(monitor)
        }

        aggregationTimer?.invalidate()
        idleTimer?.invalidate()

        // Save any remaining activity
        saveAggregatedActivity()

        // End any ongoing idle event
        endIdleEvent()
    }

    private func recordKeystroke() {
        keystrokeCount += 1
        recordActivity()
    }

    private func recordClick() {
        clickCount += 1
        recordActivity()
    }

    private func recordScroll(_ event: NSEvent) {
        let delta = abs(Double(event.scrollingDeltaY)) + abs(Double(event.scrollingDeltaX))
        scrollAmount += delta
        recordActivity()
    }

    private func recordActivity() {
        lastActivityTime = Date()
        TrackingService.shared.recordActivity()

        // End idle if we were idle
        if isIdle {
            endIdleEvent()
            isIdle = false
        }
    }

    private func saveAggregatedActivity() {
        guard keystrokeCount > 0 || clickCount > 0 || scrollAmount > 0 else { return }

        let activity = InputActivity(
            timestamp: Date(),
            keystrokes: keystrokeCount,
            mouseClicks: clickCount,
            scrollAmount: scrollAmount
        )

        db.insertInputActivity(activity)

        // Reset counters
        keystrokeCount = 0
        clickCount = 0
        scrollAmount = 0
    }

    private func checkIdleState() {
        let now = Date()
        let idleSeconds = now.timeIntervalSince(lastActivityTime)

        if idleSeconds >= Double(settings.idleThresholdSeconds) {
            if !isIdle {
                // Start idle event
                isIdle = true
                startIdleEvent()
            } else {
                // Update idle event duration
                updateIdleEvent()
            }
        }
    }

    private func startIdleEvent() {
        let event = IdleEvent(startTime: lastActivityTime)

        if let insertedId = db.insertIdleEvent(event) {
            currentIdleEvent = IdleEvent(
                id: insertedId,
                startTime: lastActivityTime
            )
        }
    }

    private func updateIdleEvent() {
        guard var event = currentIdleEvent else { return }

        let now = Date()
        event.endTime = now
        event.durationSeconds = Int(now.timeIntervalSince(event.startTime))

        db.updateIdleEvent(event)
        currentIdleEvent = event
    }

    private func endIdleEvent() {
        guard var event = currentIdleEvent else { return }

        let now = Date()
        event.endTime = now
        event.durationSeconds = Int(now.timeIntervalSince(event.startTime))

        db.updateIdleEvent(event)
        currentIdleEvent = nil
    }
}
