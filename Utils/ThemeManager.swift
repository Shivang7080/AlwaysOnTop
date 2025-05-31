import SwiftUI

// Enum for theme modes
enum ThemeMode: String, CaseIterable {
    case light = "Light"
    case dark = "Dark"
    case system = "System"
}

// Struct for accent color definitions
struct Colors {
    static let accentColors: [(name: String, hex: String)] = [
        ("Aurora Blue", "#3B82F6"),
        ("Emerald Glow", "#10B981"),
        ("Crimson Flame", "#EF4444"),
        ("Amethyst Dream", "#8B5CF6"),
        ("Sunset Orange", "#F59E0B"),
        ("Midnight Slate", "#1E293B"),
        ("Rose Quartz", "#F9A8D4"),
        ("Ocean Teal", "#14B8A6"),
        ("Golden Haze", "#FBBF24"),
        ("Neon Coral", "#FF6B6B"),
        ("Sapphire Luxe", "#1E3A8A"),
        ("Velvet Indigo", "#4C1D95"),
        ("Jade Serenity", "#059669"),
        ("Champagne Bliss", "#FDE68A"),
        ("Obsidian Spark", "#0F172A")
    ]
}

// Singleton to manage theme and accent color preferences
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    @AppStorage("selectedAccentColor") private var accentColorStorage: String = Colors.accentColors[0].hex
    @AppStorage("selectedThemeMode") private var selectedThemeModeRaw: String = ThemeMode.system.rawValue

    @Published var selectedAccentColorHex: String = Colors.accentColors[0].hex {
        didSet {
            accentColorStorage = selectedAccentColorHex
        }
    }
    @Published var selectedThemeMode: ThemeMode = .system {
        didSet {
            selectedThemeModeRaw = selectedThemeMode.rawValue
        }
    }

    private init() {
        // Sync @Published properties with @AppStorage values after initialization
        self.selectedAccentColorHex = accentColorStorage
        self.selectedThemeMode = ThemeMode(rawValue: selectedThemeModeRaw) ?? .system
    }

    // Get current accent color as Color
    var accentColor: Color {
        Color(hex: selectedAccentColorHex) ?? Color(hex: Colors.accentColors[0].hex)!
    }

    // Get current theme mode
    var themeMode: ThemeMode {
        selectedThemeMode
    }

    // Set accent color
    func setAccentColor(hex: String) {
        selectedAccentColorHex = hex
    }

    // Set theme mode
    func setThemeMode(_ mode: ThemeMode) {
        selectedThemeMode = mode
    }
}

// Extension to convert hex string to Color
extension Color {
    init?(hex: String) {
        let r, g, b: Double
        let hexString = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hexString)
        var hexNumber: UInt64 = 0

        guard scanner.scanHexInt64(&hexNumber) else { return nil }

        r = Double((hexNumber >> 16) & 0xFF) / 255.0
        g = Double((hexNumber >> 8) & 0xFF) / 255.0
        b = Double(hexNumber & 0xFF) / 255.0

        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
    }
}

// Extension to apply theme mode to ColorScheme
extension ThemeMode {
    var colorScheme: ColorScheme? {
        switch self {
        case .light:
            return .light
        case .dark:
            return .dark
        case .system:
            return nil // Follows system setting
        }
    }
}
