import SwiftUI
import KeyboardShortcuts
import LaunchAtLogin

struct SettingsView: View {
    @AppStorage("isAppPersistenceEnabled") private var isAppPersistenceEnabled: Bool = false
    @StateObject private var themeManager = ThemeManager.shared

    var body: some View {
        generalTabView()
            .frame(minWidth: 480, minHeight: 400)
            .background(Color(NSColor.windowBackgroundColor))
            .preferredColorScheme(themeManager.themeMode.colorScheme)
    }

    // MARK: - General Tab
    private func generalTabView() -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                headerSection(title: "General Settings", subtitle: "Customize your AlwaysOnTop experience")
                
                VStack(spacing: 20) {
                    startupSection()
                    shortcutsSection()
                    behaviorSection()
                    appearanceSection()
                }
                
                Spacer(minLength: 20)
            }
            .padding(28)
        }
    }


    // MARK: - Header Section
    private func headerSection(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(themeManager.accentColor)
            
            Text(subtitle)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Startup Section
    private func startupSection() -> some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 16) {
                sectionTitle("Startup", icon: "power")
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Launch at Login")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Text("Automatically start AlwaysOnTop when you log in")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    LaunchAtLogin.Toggle()
                        .scaleEffect(0.8)
                        .accentColor(themeManager.accentColor)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Launch AlwaysOnTop at login")
            }
        }
    }

    // MARK: - Shortcuts Section
    private func shortcutsSection() -> some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 16) {
                sectionTitle("Keyboard Shortcuts", icon: "command")
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Pin Window Shortcut")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.primary)
                            
                            Text("Quickly pin or unpin the active window")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        KeyboardShortcuts.Recorder("", name: .pinAppShortcut)
                            .accentColor(themeManager.accentColor)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Set shortcut for pinning windows")
                }
            }
        }
    }

    // MARK: - Behavior Section
    private func behaviorSection() -> some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 16) {
                sectionTitle("Behavior", icon: "gearshape.2")
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Persist Last Pinned App")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.primary)
                        
                        Text("Remember pinned windows after app restart")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: $isAppPersistenceEnabled)
                        .toggleStyle(SwitchToggleStyle())
                        .scaleEffect(0.8)
                        .accentColor(themeManager.accentColor)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Persist last pinned app after restart")
            }
        }
    }

    // MARK: - Appearance Section
    private func appearanceSection() -> some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 20) {
                sectionTitle("Appearance", icon: "paintbrush")
                
                // Theme Mode
                VStack(alignment: .leading, spacing: 12) {
                    Text("Theme Mode")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 12) {
                        ForEach(ThemeMode.allCases, id: \.rawValue) { mode in
                            themeButton(mode: mode)
                        }
                        Spacer()
                    }
                    .accessibilityLabel("Select theme mode")
                }
                
                Divider()
                    .background(Color.secondary.opacity(0.3))
                
                // Accent Color
                accentColorSection()
            }
        }
    }

    // MARK: - Theme Button
    private func themeButton(mode: ThemeMode) -> some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                themeManager.selectedThemeMode = mode
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: themeIcon(for: mode))
                    .font(.system(size: 12, weight: .medium))
                
                Text(mode.rawValue)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(themeManager.selectedThemeMode == mode ? .white : themeManager.accentColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(themeManager.selectedThemeMode == mode ? themeManager.accentColor : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(themeManager.accentColor.opacity(0.5), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("\(mode.rawValue) theme")
    }

    // MARK: - Accent Color Section
    private func accentColorSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Accent Color")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.primary)
            
            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(36), spacing: 10), count: 6),
                spacing: 10
            ) {
                ForEach(Colors.accentColors, id: \.hex) { color in
                    colorButton(color: color)
                }
            }
        }
    }

    // MARK: - Color Button
    private func colorButton(color: (name: String, hex: String)) -> some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                themeManager.setAccentColor(hex: color.hex)
            }
        }) {
            Circle()
                .fill(Color(hex: color.hex) ?? .blue)
                .frame(width: 28, height: 28)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                        .opacity(themeManager.selectedAccentColorHex == color.hex ? 1 : 0)
                        .scaleEffect(themeManager.selectedAccentColorHex == color.hex ? 1.3 : 1)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: themeManager.selectedAccentColorHex)
                )
                .scaleEffect(themeManager.selectedAccentColorHex == color.hex ? 1.1 : 1)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("Select \(color.name)")
        .accessibilityHint("Tap to set \(color.name) as the accent color")
    }

    // MARK: - Helper Views
    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack {
            content()
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.controlBackgroundColor))
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }

    private func sectionTitle(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(themeManager.accentColor)
            
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.primary)
        }
    }

    // MARK: - Helper Functions
    private func themeIcon(for mode: ThemeMode) -> String {
        switch mode {
        case .light:
            return "sun.max"
        case .dark:
            return "moon"
        default:
            return "circle.lefthalf.filled"
        }
    }

    private func getAppVersion() -> String {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            return version
        }
        return "Unknown"
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
    }
}
