import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    private var windowManager: WindowManager?
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {
        windowManager = WindowManager()
        requestAccessibilityPermissions()
        print("AppDelegate: WindowManager initialized")
    }
    
    func applicationWillTerminate(_ aNotification: Notification) {
        // Clean up resources if needed
    }
    
    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    private func requestAccessibilityPermissions() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)
        if !accessEnabled {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permissions Required"
            alert.informativeText = "Please enable Accessibility permissions for AlwaysOnTop in System Settings > Privacy & Security > Accessibility."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}
