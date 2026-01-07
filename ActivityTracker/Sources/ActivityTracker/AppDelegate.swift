import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var trackingService: TrackingService?
    private var inputMonitor: InputMonitor?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize database
        _ = DatabaseManager.shared

        // Start tracking services
        trackingService = TrackingService.shared
        trackingService?.startTracking()

        inputMonitor = InputMonitor.shared
        inputMonitor?.startMonitoring()

        // Request accessibility permissions if needed
        requestAccessibilityPermissions()

        // Hide dock icon (menu bar only app)
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationWillTerminate(_ notification: Notification) {
        trackingService?.stopTracking()
        inputMonitor?.stopMonitoring()
    }

    private func requestAccessibilityPermissions() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true]
        let accessibilityEnabled = AXIsProcessTrustedWithOptions(options)

        if !accessibilityEnabled {
            print("Accessibility permissions required for input monitoring")
        }
    }
}
