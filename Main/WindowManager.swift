import Cocoa
import AppKit
import SwiftUI
import KeyboardShortcuts
import ServiceManagement

class WindowManager {
    var runningApps: [NSRunningApplication] = []
    var selectedAppName: String?
    var statusText: String = "Select an app to begin"

    private var selectedApp: NSRunningApplication?
    private var isPinned: Bool = false
    private var statusItem: NSStatusItem?
    private var pinTimer: Timer?
    private var lastAppleScriptTime: Date?
    private var settingsWindow: NSWindow?
    private var appSelectionWindow: NSWindow?
    private var unpinNotificationWindow: NSWindow?
    private var pinNotificationWindow: NSWindow?
    private let pinCheckInterval: TimeInterval = 0.5 // Check pinning every 0.5 seconds
    private let appleScriptThrottleInterval: TimeInterval = 1.0 // Run AppleScript at most once per second
    private let defaults = UserDefaults.standard
    private let themeManager = ThemeManager.shared

    init() {
        print("WindowManager initialized")
        setupStatusBarItem()
        setupAppTerminationObserver()
        updateRunningApps()
        setupKeyboardShortcut()
        restoreLastPinnedApp()
    }

    // Restore last pinned app if persistence is enabled
    private func restoreLastPinnedApp() {
        guard defaults.bool(forKey: "isAppPersistenceEnabled"),
              let bundleID = defaults.string(forKey: "lastPinnedAppBundleID") else {
            print("No persisted app to restore or persistence disabled")
            return
        }

        // Find the app in running applications
        if let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleID }),
           app.activationPolicy == .regular,
           app.bundleIdentifier != NSRunningApplication.current.bundleIdentifier {
            selectedApp = app
            selectedAppName = app.localizedName
            statusText = "Selected: \(selectedAppName ?? "Unknown")"
            print("Restoring persisted app: \(selectedAppName ?? "Unknown") (Bundle ID: \(bundleID))")

            // Attempt to pin the app if Accessibility permissions are granted
            if AXIsProcessTrusted() {
                let axApp = AXUIElementCreateApplication(app.processIdentifier)
                if let window = getAccessibleWindow(from: axApp) {
                    togglePinState(for: window) // Pins the app
                    showPinNotification()
                } else {
                    statusText = "Error: Cannot access window of persisted app"
                    print("Restore failed: Cannot access window")
                }
            } else {
                statusText = "Error: Accessibility permissions required for persisted app"
                print("Restore failed: Accessibility permissions not granted")
            }
        } else {
            // Clear persisted data if the app is not running
            defaults.removeObject(forKey: "lastPinnedAppBundleID")
            print("Persisted app not running or invalid: \(bundleID)")
        }

        updateStatusBarItem()
        updateMenuItems()
    }

    // Setup keyboard shortcut listener
    private func setupKeyboardShortcut() {
        KeyboardShortcuts.onKeyUp(for: .pinAppShortcut) { [weak self] in
            guard let self = self else { return }
            if self.isPinned {
                // Unpin the current app if pinned
                if let app = self.selectedApp, let pid = app.processIdentifier as pid_t?, AXIsProcessTrusted() {
                    let axApp = AXUIElementCreateApplication(pid)
                    if let window = self.getAccessibleWindow(from: axApp) {
                        self.togglePinState(for: window) // Unpins since isPinned is true
                        self.showUnpinNotification() // Show unpin notification
                    } else {
                        self.statusText = "Error: Cannot access window"
                        print("Unpin failed: Error accessing window")
                    }
                }
                self.appSelectionWindow?.close()
                self.appSelectionWindow = nil
            } else if self.appSelectionWindow != nil {
                // Close the selection window if open and no selection made
                self.appSelectionWindow?.close()
                self.appSelectionWindow = nil
                print("App selection window closed via shortcut")
            } else {
                // Show popup to select a new app
                self.showAppSelectionPopup()
            }
        }
        print("Keyboard shortcut listener set up for pinAppShortcut")
    }

    // Show popup for app selection
    private func showAppSelectionPopup() {
        // Close existing app selection window if open
        if let window = appSelectionWindow {
            window.close()
            appSelectionWindow = nil
        }

        // Create new window with title bar but without minimize/close buttons
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 320),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "Select App to Pin"
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear // Transparent to allow glass effect

        // Set up SwiftUI content for app selection
        let contentView = AppSelectionView(
            apps: runningApps,
            onSelect: { [weak self] appName in
                guard let self = self else { return }
                self.appSelected(appName)
                if let appName = appName, let app = self.runningApps.first(where: { $0.localizedName == appName }) {
                    self.selectedApp = app
                    if AXIsProcessTrusted() {
                        let axApp = AXUIElementCreateApplication(app.processIdentifier)
                        if let window = self.getAccessibleWindow(from: axApp) {
                            self.togglePinState(for: window)
                            self.showPinNotification() // Show pin notification
                        } else {
                            self.statusText = "Error: Cannot access window"
                            print("Popup pin failed: Error accessing window")
                        }
                    } else {
                        self.statusText = "Error: Accessibility permissions required"
                        print("Popup pin failed: Accessibility permissions not granted")
                    }
                }
                self.appSelectionWindow?.close()
                self.appSelectionWindow = nil
            }
        )
        .environmentObject(themeManager) // Pass ThemeManager to the view

        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        appSelectionWindow = window

        print("App selection popup opened")
    }

    // Show unpin notification
    private func showUnpinNotification() {
        // Close existing notification window if open
        if let window = unpinNotificationWindow {
            window.close()
            unpinNotificationWindow = nil
        }

        // Create new window for notification
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 80, height: 80),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.level = .screenSaver // High level to ensure visibility
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear // Fully transparent
        window.hasShadow = false // No window shadow to avoid square outline

        // Set up SwiftUI content for notification
        let contentView = UnpinNotificationView()
            .environmentObject(themeManager) // Pass ThemeManager
        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)

        unpinNotificationWindow = window

        // Auto-close after 1.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.unpinNotificationWindow?.close()
            self?.unpinNotificationWindow = nil
            print("Unpin notification closed")
        }

        print("Unpin notification shown")
    }

    // Show pin notification
    private func showPinNotification() {
        // Close existing notification window if open
        if let window = pinNotificationWindow {
            window.close()
            pinNotificationWindow = nil
        }

        // Create new window for notification
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 80, height: 80),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.level = .screenSaver // High level to ensure visibility
        window.isReleasedWhenClosed = false
        window.backgroundColor = .clear // Fully transparent
        window.hasShadow = false // No window shadow to avoid square outline

        // Set up SwiftUI content for notification
        let contentView = PinNotificationView()
            .environmentObject(themeManager) // Pass ThemeManager
        window.contentView = NSHostingView(rootView: contentView)
        window.makeKeyAndOrderFront(nil)

        pinNotificationWindow = window

        // Auto-close after 1.5 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.pinNotificationWindow?.close()
            self?.pinNotificationWindow = nil
            print("Pin notification closed")
        }

        print("Pin notification shown")
    }

    // Update list of running applications
    func updateRunningApps() {
        runningApps = NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular && $0.bundleIdentifier != NSRunningApplication.current.bundleIdentifier }
        if let currentAppName = selectedAppName, !runningApps.contains(where: { $0.localizedName == currentAppName }) {
            selectedApp = nil
            selectedAppName = nil
            isPinned = false
            statusText = "Select an app to begin"
            defaults.removeObject(forKey: "lastPinnedAppBundleID")
            stopPinTimer()
            updateStatusBarItem()
        }
        updateMenuItems()
        print("Updated running apps: \(runningApps.map { $0.localizedName ?? "Unknown" })")
    }

    // Handle app selection
    func appSelected(_ appName: String?) {
        guard let appName = appName, let app = runningApps.first(where: { $0.localizedName == appName }) else {
            selectedApp = nil
            selectedAppName = nil
            isPinned = false
            statusText = "Select an app to begin"
            defaults.removeObject(forKey: "lastPinnedAppBundleID")
            stopPinTimer()
            updateStatusBarItem()
            updateMenuItems()
            print("No app selected or invalid selection")
            return
        }
        selectedApp = app
        selectedAppName = appName
        isPinned = false
        statusText = "Selected: \(appName)"
        stopPinTimer()
        updateStatusBarItem()
        updateMenuItems()
        print("Selected app: \(appName)")
    }

    // Manual toggle for pinning
    func manualTogglePin() {
        guard let app = selectedApp, let pid = app.processIdentifier as pid_t? else {
            statusText = "Error: No app selected"
            print("Manual toggle failed: No app selected")
            updateMenuItems()
            return
        }

        guard AXIsProcessTrusted() else {
            statusText = "Error: Accessibility permissions required"
            print("Manual toggle failed: Accessibility permissions not granted")
            updateMenuItems()
            return
        }

        let axApp = AXUIElementCreateApplication(pid)
        if let window = getAccessibleWindow(from: axApp) {
            togglePinState(for: window)
            if isPinned {
                // Save the bundle identifier when pinning
                if let bundleID = app.bundleIdentifier {
                    defaults.set(bundleID, forKey: "lastPinnedAppBundleID")
                    print("Saved pinned app bundle ID: \(bundleID)")
                }
                showPinNotification() // Show pin notification for manual pin
            } else {
                // Clear persisted data when unpinning
                defaults.removeObject(forKey: "lastPinnedAppBundleID")
                print("Cleared pinned app bundle ID")
                showUnpinNotification() // Show unpin notification for manual unpin
            }
        } else {
            statusText = "Error: Cannot access window"
            print("Manual toggle failed: Error accessing window")
            updateMenuItems()
        }
    }

    // Get accessible window (try focused window, then fall back to main or first window)
    private func getAccessibleWindow(from axApp: AXUIElement) -> AXUIElement? {
        // Try focused window
        var focusedWindow: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &focusedWindow)
        if error == .success, let window = focusedWindow as! AXUIElement? {
            return window
        }
        print("Failed to access focused window, error: \(error)")

        // Try main window
        var mainWindow: CFTypeRef?
        let errorMain = AXUIElementCopyAttributeValue(axApp, kAXMainWindowAttribute as CFString, &mainWindow)
        if errorMain == .success, let window = mainWindow as! AXUIElement? {
            return window
        }
        print("Failed to access main window, error: \(errorMain)")

        // Try first window from windows list
        var windows: CFTypeRef?
        let errorWindows = AXUIElementCopyAttributeValue(axApp, kAXWindowsAttribute as CFString, &windows)
        if errorWindows == .success, let windowList = windows as? [AXUIElement], let firstWindow = windowList.first {
            return firstWindow
        }
        print("Failed to access windows list, error: \(errorWindows)")

        return nil
    }

    // Setup status bar item
    private func setupStatusBarItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem?.button {
            // Use a premium-looking system symbol for the status bar item
            let systemIcon = NSImage(systemSymbolName: "pin.fill", accessibilityDescription: "AlwaysOnTop")
            systemIcon?.isTemplate = true // Allows the icon to respect the system's dark/light mode
            systemIcon?.size = NSSize(width: 18, height: 18) // Set the size of the icon
            button.image = systemIcon
            button.title = "" // Remove the text title
        } else {
            print("Failed to create status bar item button")
        }
        updateMenuItems()
        print("Status bar item setup completed, statusItem: \(String(describing: statusItem))")
    }

    // Update status bar menu items
    private func updateMenuItems() {
        guard let statusItem = statusItem else {
            print("Cannot update menu items: statusItem is nil")
            return
        }
        let menu = NSMenu()

        // App selection submenu
        let selectAppMenuItem = NSMenuItem(title: "Select Application", action: nil, keyEquivalent: "")
        let appMenu = NSMenu()
        let noneItem = NSMenuItem(title: "None", action: #selector(selectApp(_:)), keyEquivalent: "")
        noneItem.target = self
        noneItem.representedObject = nil
        noneItem.state = selectedAppName == nil ? NSControl.StateValue.on : NSControl.StateValue.off
        noneItem.image = NSImage(systemSymbolName: "circle", accessibilityDescription: "No Application Selected")
        appMenu.addItem(noneItem)

        for app in runningApps {
            if let appName = app.localizedName {
                let menuItem = NSMenuItem(title: appName, action: #selector(selectApp(_:)), keyEquivalent: "")
                menuItem.target = self
                menuItem.representedObject = appName
                menuItem.state = appName == selectedAppName ? NSControl.StateValue.on : NSControl.StateValue.off
                menuItem.image = NSImage(systemSymbolName: appName == selectedAppName ? "checkmark.circle.fill" : "circle", accessibilityDescription: "Select Application")
                appMenu.addItem(menuItem)
            }
        }
        selectAppMenuItem.submenu = appMenu
        selectAppMenuItem.image = NSImage(systemSymbolName: "app", accessibilityDescription: "Select Application")
        menu.addItem(selectAppMenuItem)

        // Toggle pin
        let togglePinItem = NSMenuItem(title: "Toggle Window Pin", action: #selector(togglePin(_:)), keyEquivalent: "p")
        togglePinItem.target = self
        togglePinItem.isEnabled = selectedAppName != nil
        togglePinItem.image = NSImage(systemSymbolName: "windowpin", accessibilityDescription: "Toggle Window Pin")
        menu.addItem(togglePinItem)

        // Status text
        let statusMenuItem = NSMenuItem(title: statusText, action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        statusMenuItem.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: "Status")
        menu.addItem(statusMenuItem)

        // Settings
        let settingsMenuItem = NSMenuItem(title: "Preferences", action: #selector(openSettingsWindow), keyEquivalent: ",")
        settingsMenuItem.target = self
        settingsMenuItem.image = NSImage(systemSymbolName: "slider.horizontal.3", accessibilityDescription: "Preferences")
        menu.addItem(settingsMenuItem)

        // Separator
        menu.addItem(.separator())

        // Refresh apps
        let refreshAppsItem = NSMenuItem(title: "Refresh Applications", action: #selector(refreshApps), keyEquivalent: "r")
        refreshAppsItem.target = self
        refreshAppsItem.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: "Refresh Applications")
        menu.addItem(refreshAppsItem)

        // Quit
        let quitItem = NSMenuItem(title: "Quit Application", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.image = NSImage(systemSymbolName: "power", accessibilityDescription: "Quit Application")
        menu.addItem(quitItem)

        statusItem.menu = menu
        print("Menu items updated, menu assigned to statusItem")
    }

    // Open settings window
    @objc private func openSettingsWindow() {
        // Close existing settings window if open
        if let window = settingsWindow {
            window.close()
            settingsWindow = nil
        }

        // Create new window
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "AlwaysOnTop Settings"
        window.level = .normal
        window.isReleasedWhenClosed = false

        // Set up SwiftUI content
        let contentView = SettingsView()
            .environmentObject(themeManager) // Pass ThemeManager
        window.contentView = NSHostingView(rootView: contentView)

        // Show window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window

        print("Settings window opened")
    }

    // Handle app selection from menu
    @objc private func selectApp(_ sender: NSMenuItem) {
        let appName = sender.representedObject as? String
        appSelected(appName)
    }

    // Handle toggle pin from menu
    @objc private func togglePin(_ sender: NSMenuItem) {
        manualTogglePin()
    }

    // Refresh app list
    @objc private func refreshApps() {
        updateRunningApps()
    }

    // Update status bar
    private func updateStatusBarItem() {
        if let button = statusItem?.button {
            button.title = selectedApp != nil ? "\(selectedApp!.localizedName ?? "App") (\(isPinned ? "Pinned" : "Unpinned"))" : ""
            button.image = NSImage(systemSymbolName: isPinned ? "pin.fill" : "pin", accessibilityDescription: "AlwaysOnTop")
        } else {
            print("Cannot update status bar item: button is nil")
        }
    }

    // Execute AppleScript to activate app and raise window
    private func executeAppleScript() {
        // Throttle AppleScript execution
        let now = Date()
        if let lastTime = lastAppleScriptTime, now.timeIntervalSince(lastTime) < appleScriptThrottleInterval {
            return
        }
        lastAppleScriptTime = now

        guard let app = selectedApp, let appName = app.localizedName else {
            print("AppleScript failed: No selected app")
            return
        }
        let scriptSource = """
        tell application "\(appName)"
            activate
            try
                set index of window 1 to 1
            end try
        end tell
        """
        if let appleScript = NSAppleScript(source: scriptSource) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
            if let error = error {
                print("AppleScript error: \(error)")
                statusText = "Warning: Failed to raise window via AppleScript"
            }
        } else {
            print("Failed to create AppleScript")
            statusText = "Warning: Unable to execute AppleScript"
        }
    }

    // Start pin timer to enforce pinned state
    private func startPinTimer(for window: AXUIElement) {
        stopPinTimer()
        pinTimer = Timer.scheduledTimer(withTimeInterval: pinCheckInterval, repeats: true) { [weak self] _ in
            guard let self = self, self.isPinned, let app = self.selectedApp, let pid = app.processIdentifier as pid_t? else { return }
            let axApp = AXUIElementCreateApplication(pid)
            guard let currentWindow = self.getAccessibleWindow(from: axApp) else {
                self.statusText = "Error: Cannot access window"
                print("Pin timer: Cannot access window")
                self.updateMenuItems()
                return
            }
            // Re-apply high window level and raise window
            self.setWindowLevel(currentWindow, level: NSWindow.Level.floating.rawValue)
            // Force app activation via AppleScript
            self.executeAppleScript()
        }
    }

    // Stop pin timer
    private func stopPinTimer() {
        pinTimer?.invalidate()
        pinTimer = nil
    }

    // Toggle pinning state
    private func togglePinState(for window: AXUIElement) {
        let newPinnedState = !isPinned
        if newPinnedState {
            // Pin
            setWindowLevel(window, level: NSWindow.Level.floating.rawValue)
            isPinned = true
            statusText = "Status: Pinned"
            selectedApp?.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
            startPinTimer(for: window)
        } else {
            // Unpin
            setWindowLevel(window, level: NSWindow.Level.normal.rawValue)
            isPinned = false
            statusText = "Status: Unpinned"
            stopPinTimer()
        }
        updateStatusBarItem()
        updateMenuItems()
    }

    // Set window level using Accessibility API with AppleScript fallback
    private func setWindowLevel(_ window: AXUIElement, level: Int) {
        // Use a higher window level to ensure the window stays above all others
        let targetLevel = level == NSWindow.Level.floating.rawValue ? NSWindow.Level.screenSaver.rawValue : NSWindow.Level.normal.rawValue

        // Check if window is already frontmost
        var isFrontmost: CFTypeRef?
        let isFrontmostError = AXUIElementCopyAttributeValue(window, kAXFrontmostAttribute as CFString, &isFrontmost)
        if isFrontmostError == .success, let frontmost = isFrontmost as? Bool, frontmost, targetLevel == NSWindow.Level.screenSaver.rawValue {
            return // Skip if already frontmost and pinning
        }

        // Set main attribute to mark as main window when pinning
        let mainError = AXUIElementSetAttributeValue(window, kAXMainAttribute as CFString, targetLevel == NSWindow.Level.screenSaver.rawValue ? kCFBooleanTrue : kCFBooleanFalse)
        if mainError != .success {
            print("Failed to set main attribute, error: \(mainError)")
            statusText = "Warning: Pinning may not persist for this app"
            updateMenuItems()
        }

        // Explicitly raise the window to the front
        let raiseError = AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        if raiseError != .success {
            print("Failed to raise window, error: \(raiseError)")
            statusText = "Warning: Unable to bring window to front via Accessibility API"
            updateMenuItems()
            // Fallback to AppleScript
            executeAppleScript()
        }

        // Preserve window position and size
        var position: CFTypeRef?
        var size: CFTypeRef?
        let posError = AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &position)
        let sizeError = AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &size)

        if posError != .success || sizeError != .success {
            statusText = "Error: Failed to get window properties"
            print("Set window level failed: posError=\(posError), sizeError=\(sizeError)")
            updateMenuItems()
            return
        }

        // Re-apply position and size to simulate level change
        if let pos = position, let sz = size {
            let setPosError = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, pos)
            let setSizeError = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sz)
            if setPosError != .success || setSizeError != .success {
                statusText = "Warning: Pinning may not persist for this app"
                print("Set window level failed: setPosError=\(setPosError), setSizeError=\(setSizeError)")
                updateMenuItems()
            }
        }
    }

    // Setup observer for app termination
    private func setupAppTerminationObserver() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self,
                  let terminatedApp = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  terminatedApp.processIdentifier == self.selectedApp?.processIdentifier else { return }
            self.selectedApp = nil
            self.selectedAppName = nil
            self.isPinned = false
            self.statusText = "Selected app terminated."
            self.defaults.removeObject(forKey: "lastPinnedAppBundleID")
            self.stopPinTimer()
            self.updateStatusBarItem()
            self.updateMenuItems()
            print("App terminated: \(terminatedApp.localizedName ?? "Unknown")")
        }
    }

    deinit {
        stopPinTimer()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        settingsWindow?.close()
        appSelectionWindow?.close()
        unpinNotificationWindow?.close()
        pinNotificationWindow?.close()
    }
}

// MARK: AppSelectionView
struct AppSelectionView: View {
    let apps: [NSRunningApplication]
    let onSelect: (String?) -> Void
    
    @State private var selectedIndex: Int = 0
    @State private var hoveredApp: String?
    @State private var isAppearing = false
    @State private var searchText = ""
    @EnvironmentObject private var themeManager: ThemeManager
    @FocusState private var isSearchFocused: Bool
    
    private var filteredApps: [NSRunningApplication] {
        if searchText.isEmpty {
            return apps
        }
        return apps.filter { app in
            app.localizedName?.localizedCaseInsensitiveContains(searchText) ?? false
        }
    }
    
    private var gridColumns: [GridItem] {
        let appCount = filteredApps.count
        let maxColumns = 3
        let idealColumns = min(maxColumns, max(1, appCount))
        return Array(repeating: GridItem(.flexible(), spacing: 16), count: idealColumns)
    }
    
    var body: some View {
        ZStack {
            // glassmorphic background
            VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                .ignoresSafeArea()
                .overlay(
                    RadialGradient(
                        gradient: Gradient(colors: [
                            themeManager.accentColor.opacity(0.15),
                            themeManager.accentColor.opacity(0.05),
                            .clear
                        ]),
                        center: .topLeading,
                        startRadius: 50,
                        endRadius: 200
                    )
                )
            
            VStack(spacing: 0) {
                // Header with search
                headerView
                
                // Main content
                if filteredApps.isEmpty {
                    emptyStateView
                } else {
                    appGridView
                }
                
                // Footer with instructions
                footerView
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .opacity(isAppearing ? 1.0 : 0.0)
        .scaleEffect(isAppearing ? 1.0 : 0.95)
        .onAppear {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isAppearing = true
            }
            // Auto-focus search after animation
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                isSearchFocused = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSView.frameDidChangeNotification)) { _ in
            // Handle key events using NSEvent
            NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                guard let key = event.characters else { return event }
                return handleKeyPress(key: key) ? nil : event
            }
        }
        .preferredColorScheme(themeManager.themeMode.colorScheme)
    }
    
    // MARK: - Header View
    private var headerView: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "pin.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(themeManager.accentColor)
                    .accessibilityHidden(true)
                
                Text("Pin Application")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Text("\(filteredApps.count) apps")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
            }
            
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .accessibilityHidden(true)
                
                TextField("Search applications...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, design: .rounded))
                    .focused($isSearchFocused)
                    .onSubmit {
                        if !filteredApps.isEmpty {
                            selectCurrentApp()
                        }
                    }
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSearchFocused ? themeManager.accentColor.opacity(0.5) : .clear, lineWidth: 1)
            )
        }
    }
    
    // MARK: - Empty State View
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            
            VStack(spacing: 12) {
                Image(systemName: searchText.isEmpty ? "app.dashed" : "magnifyingglass")
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(themeManager.accentColor.opacity(0.6))
                    .accessibilityHidden(true)
                
                Text(searchText.isEmpty ? "No Apps Available" : "No Results Found")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(searchText.isEmpty ?
                     "Open some applications to pin them to the top." :
                     "Try adjusting your search terms.")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .padding(24)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(themeManager.accentColor.opacity(0.2), lineWidth: 1)
            )
            
            Spacer()
        }
    }
    
    // MARK: - App Grid View
    private var appGridView: some View {
        ScrollView {
            LazyVGrid(columns: gridColumns, spacing: 16) {
                ForEach(Array(filteredApps.enumerated()), id: \.element.processIdentifier) { index, app in
                    if let appName = app.localizedName {
                        AppItemView(
                            app: app,
                            appName: appName,
                            isSelected: index == selectedIndex,
                            isHovered: hoveredApp == appName,
                            themeManager: themeManager,
                            onTap: {
                                selectedIndex = index
                                selectCurrentApp()
                            },
                            onHover: { isHovered in
                                hoveredApp = isHovered ? appName : nil
                                if isHovered {
                                    selectedIndex = index
                                }
                            }
                        )
                    }
                }
            }
            .padding(.vertical, 16)
        }
        .scrollIndicators(.visible)
    }
    
    // MARK: - Footer View
    private var footerView: some View {
        VStack(spacing: 8) {
            Divider()
                .background(themeManager.accentColor.opacity(0.2))
            
            HStack(spacing: 16) {
                Label("↑↓ Navigate", systemImage: "arrow.up.arrow.down")
                Label("⏎ Select", systemImage: "return")
                Label("⎋ Cancel", systemImage: "escape")
            }
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundColor(.secondary)
            .labelStyle(.titleOnly)
        }
        .padding(.top, 8)
    }
    
    // MARK: - Helper Methods
    private func handleKeyPress(key: String) -> Bool {
        switch key {
        case "\u{2191}": // Up arrow
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedIndex = max(0, selectedIndex - 1)
            }
            return true
            
        case "\u{2193}": // Down arrow
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedIndex = min(filteredApps.count - 1, selectedIndex + 1)
            }
            return true
            
        case "\r", "\n": // Return or Enter
            selectCurrentApp()
            return true
            
        case "\u{1B}": // Escape
            onSelect(nil)
            return true
            
        default:
            return false
        }
    }
    
    private func selectCurrentApp() {
        guard selectedIndex < filteredApps.count else { return }
        let selectedApp = filteredApps[selectedIndex]
        withAnimation(.easeInOut(duration: 0.2)) {
            onSelect(selectedApp.localizedName)
        }
    }
}

// MARK: - Individual App Item View
struct AppItemView: View {
    let app: NSRunningApplication
    let appName: String
    let isSelected: Bool
    let isHovered: Bool
    let themeManager: ThemeManager
    let onTap: () -> Void
    let onHover: (Bool) -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // App icon with enhanced styling
                Group {
                    if let nsImage = app.icon {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFit()
                    } else {
                        Image(systemName: "app.fill")
                            .font(.system(size: 32))
                            .foregroundColor(themeManager.accentColor.opacity(0.7))
                    }
                }
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isSelected ? themeManager.accentColor : .clear,
                            lineWidth: 2
                        )
                )
                .shadow(
                    color: isSelected ? themeManager.accentColor.opacity(0.3) : .black.opacity(0.1),
                    radius: isSelected ? 4 : 2
                )
                
                // App name with better typography
                Text(appName)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 100)
            }
            .padding(16)
            .frame(minWidth: 120, minHeight: 120)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected ? themeManager.accentColor.opacity(0.6) :
                                (isHovered ? themeManager.accentColor.opacity(0.3) : .clear),
                                lineWidth: 1.5
                            )
                    )
            )
            .scaleEffect(isPressed ? 0.95 : (isSelected || isHovered ? 1.02 : 1.0))
            .shadow(
                color: .black.opacity(isSelected ? 0.15 : (isHovered ? 0.08 : 0.03)),
                radius: isSelected ? 8 : (isHovered ? 4 : 2),
                y: isSelected ? 4 : (isHovered ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
        .onHover(perform: onHover)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
        .accessibilityLabel("Pin \(appName)")
        .accessibilityHint("Double-tap to pin this application to stay on top")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

//  unpin notification
struct UnpinNotificationView: View {
    @State private var isAppearing = false
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        ZStack {
            VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                .overlay(
                    LinearGradient(
                        gradient: Gradient(colors: [themeManager.accentColor.opacity(0.1), .white.opacity(0.1)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(themeManager.accentColor.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.1), radius: 2)

            Text("Unpinned")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(themeManager.accentColor.opacity(0.7))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .accessibilityLabel("App unpinned")
        }
        .frame(width: 80, height: 80)
        .offset(y: isAppearing ? 0 : 10)
        .opacity(isAppearing ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.3)) {
                isAppearing = true
            }
            // Fade out before window closes
            withAnimation(.easeInOut(duration: 0.3).delay(1.2)) {
                isAppearing = false
            }
        }
        .preferredColorScheme(themeManager.themeMode.colorScheme)
    }
}

// SwiftUI view for pin notification
struct PinNotificationView: View {
    @State private var isAppearing = false
    @EnvironmentObject private var themeManager: ThemeManager

    var body: some View {
        ZStack {
            VisualEffectView(material: .sidebar, blendingMode: .behindWindow)
                .overlay(
                    LinearGradient(
                        gradient: Gradient(colors: [themeManager.accentColor.opacity(0.1), .white.opacity(0.1)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(themeManager.accentColor.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.1), radius: 2)

            Text("Pinned")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(themeManager.accentColor.opacity(0.7))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .accessibilityLabel("App pinned")
        }
        .frame(width: 80, height: 80)
        .offset(y: isAppearing ? 0 : 10)
        .opacity(isAppearing ? 1.0 : 0.0)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.3)) {
                isAppearing = true
            }
            // Fade out before window closes
            withAnimation(.easeInOut(duration: 0.3).delay(1.2)) {
                isAppearing = false
            }
        }
        .preferredColorScheme(themeManager.themeMode.colorScheme)
    }
}

// Helper view for NSVisualEffectView integration
struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}
