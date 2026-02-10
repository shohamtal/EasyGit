import SwiftUI

// MARK: - Theme Variant Enum (persisted)

enum ThemeVariant: String, CaseIterable, Codable {
    case dark = "Dark"
    case light = "Light"
    case lightBlue = "Light Blue"
    case glitter = "Glitter"
}

// MARK: - Color Palette

struct ThemePalette {
    let mainBG: Color
    let sidebarBG: Color
    let diffBG: Color
    let panelHeaderBG: Color
    let borderColor: Color

    let primary: Color

    let diffAddText: Color
    let diffAddBG: Color
    let diffRemoveText: Color
    let diffRemoveBG: Color

    let modifiedBadge: Color
    let addedBadge: Color
    let deletedBadge: Color
    let conflictedBadge: Color
    let untrackedBadge: Color

    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color
    let textDimmed: Color

    let subtleBG: Color      // search bars, faint backgrounds
    let hoverBG: Color        // button hover / pressed highlight
    let pressedBG: Color      // button pressed
    let lineNumberColor: Color
    let hunkHeaderBG: Color
    let inputStroke: Color    // text field borders
    let badgeBG: Color        // badge pill backgrounds

    let preferredColorScheme: ColorScheme
}

// MARK: - Palettes

extension ThemePalette {
    static let dark = ThemePalette(
        mainBG: Color(hex: 0x1E1E1E),
        sidebarBG: Color(hex: 0x2D2D2D),
        diffBG: Color(hex: 0x0D1117),
        panelHeaderBG: Color.white.opacity(0.05),
        borderColor: Color(hex: 0x3A3A3A),
        primary: Color(hex: 0x007AFF),
        diffAddText: Color(hex: 0x4ADE80),
        diffAddBG: Color(hex: 0x1E3A2F),
        diffRemoveText: Color(hex: 0xF87171),
        diffRemoveBG: Color(hex: 0x3E1D1D),
        modifiedBadge: Color(hex: 0xEAB308),
        addedBadge: Color(hex: 0x007AFF),
        deletedBadge: Color(hex: 0xEF4444),
        conflictedBadge: Color(hex: 0xF97316),
        untrackedBadge: Color(hex: 0x4ADE80),
        textPrimary: Color.white.opacity(0.9),
        textSecondary: Color.white.opacity(0.7),
        textTertiary: Color.white.opacity(0.5),
        textDimmed: Color.white.opacity(0.3),
        subtleBG: Color.white.opacity(0.05),
        hoverBG: Color.white.opacity(0.08),
        pressedBG: Color.white.opacity(0.1),
        lineNumberColor: Color.white.opacity(0.2),
        hunkHeaderBG: Color.white.opacity(0.03),
        inputStroke: Color.white.opacity(0.1),
        badgeBG: Color.white.opacity(0.1),
        preferredColorScheme: .dark
    )

    static let light = ThemePalette(
        mainBG: Color(hex: 0xFFFFFF),
        sidebarBG: Color(hex: 0xF5F5F5),
        diffBG: Color(hex: 0xFAFBFC),
        panelHeaderBG: Color.black.opacity(0.03),
        borderColor: Color(hex: 0xD1D5DB),
        primary: Color(hex: 0x007AFF),
        diffAddText: Color(hex: 0x166534),
        diffAddBG: Color(hex: 0xDCFCE7),
        diffRemoveText: Color(hex: 0x991B1B),
        diffRemoveBG: Color(hex: 0xFEE2E2),
        modifiedBadge: Color(hex: 0xCA8A04),
        addedBadge: Color(hex: 0x007AFF),
        deletedBadge: Color(hex: 0xDC2626),
        conflictedBadge: Color(hex: 0xEA580C),
        untrackedBadge: Color(hex: 0x16A34A),
        textPrimary: Color(hex: 0x1F2937),
        textSecondary: Color(hex: 0x4B5563),
        textTertiary: Color(hex: 0x9CA3AF),
        textDimmed: Color(hex: 0xD1D5DB),
        subtleBG: Color.black.opacity(0.04),
        hoverBG: Color.black.opacity(0.06),
        pressedBG: Color.black.opacity(0.1),
        lineNumberColor: Color.black.opacity(0.25),
        hunkHeaderBG: Color.black.opacity(0.03),
        inputStroke: Color.black.opacity(0.12),
        badgeBG: Color.black.opacity(0.06),
        preferredColorScheme: .light
    )

    static let lightBlue = ThemePalette(
        mainBG: Color(hex: 0xF0F6FF),
        sidebarBG: Color(hex: 0xE1EDFA),
        diffBG: Color(hex: 0xF5F9FF),
        panelHeaderBG: Color(hex: 0x007AFF).opacity(0.04),
        borderColor: Color(hex: 0xBFD4EF),
        primary: Color(hex: 0x0A66C2),
        diffAddText: Color(hex: 0x166534),
        diffAddBG: Color(hex: 0xD5F5E3),
        diffRemoveText: Color(hex: 0x991B1B),
        diffRemoveBG: Color(hex: 0xFDE8E8),
        modifiedBadge: Color(hex: 0xCA8A04),
        addedBadge: Color(hex: 0x0A66C2),
        deletedBadge: Color(hex: 0xDC2626),
        conflictedBadge: Color(hex: 0xEA580C),
        untrackedBadge: Color(hex: 0x16A34A),
        textPrimary: Color(hex: 0x1A2B47),
        textSecondary: Color(hex: 0x3B5070),
        textTertiary: Color(hex: 0x8AA2C0),
        textDimmed: Color(hex: 0xBFD4EF),
        subtleBG: Color(hex: 0x0A66C2).opacity(0.05),
        hoverBG: Color(hex: 0x0A66C2).opacity(0.08),
        pressedBG: Color(hex: 0x0A66C2).opacity(0.12),
        lineNumberColor: Color(hex: 0x0A66C2).opacity(0.2),
        hunkHeaderBG: Color(hex: 0x0A66C2).opacity(0.04),
        inputStroke: Color(hex: 0x0A66C2).opacity(0.15),
        badgeBG: Color(hex: 0x0A66C2).opacity(0.08),
        preferredColorScheme: .light
    )

    static let glitter = ThemePalette(
        mainBG: Color(hex: 0x0E0B1A),
        sidebarBG: Color(hex: 0x150F2A),
        diffBG: Color(hex: 0x0A0815),
        panelHeaderBG: Color(hex: 0xA855F7).opacity(0.06),
        borderColor: Color(hex: 0x2D1B69),
        primary: Color(hex: 0xA855F7),
        diffAddText: Color(hex: 0x86EFAC),
        diffAddBG: Color(hex: 0x0F2A1E),
        diffRemoveText: Color(hex: 0xFCA5A5),
        diffRemoveBG: Color(hex: 0x2A0F1E),
        modifiedBadge: Color(hex: 0xFBBF24),
        addedBadge: Color(hex: 0xA855F7),
        deletedBadge: Color(hex: 0xF87171),
        conflictedBadge: Color(hex: 0xFB923C),
        untrackedBadge: Color(hex: 0x4ADE80),
        textPrimary: Color(hex: 0xE8DEF8),
        textSecondary: Color(hex: 0xB8A5D6),
        textTertiary: Color(hex: 0x7C6A9E),
        textDimmed: Color(hex: 0x4A3870),
        subtleBG: Color(hex: 0xA855F7).opacity(0.08),
        hoverBG: Color(hex: 0xA855F7).opacity(0.12),
        pressedBG: Color(hex: 0xA855F7).opacity(0.18),
        lineNumberColor: Color(hex: 0xA855F7).opacity(0.25),
        hunkHeaderBG: Color(hex: 0xA855F7).opacity(0.05),
        inputStroke: Color(hex: 0xA855F7).opacity(0.2),
        badgeBG: Color(hex: 0xA855F7).opacity(0.12),
        preferredColorScheme: .dark
    )

    static func palette(for variant: ThemeVariant) -> ThemePalette {
        switch variant {
        case .dark: return .dark
        case .light: return .light
        case .lightBlue: return .lightBlue
        case .glitter: return .glitter
        }
    }
}

// MARK: - ThemeManager (shared singleton)

@Observable
final class ThemeManager {
    static let shared = ThemeManager()

    var current: ThemePalette
    var variant: ThemeVariant {
        didSet {
            current = ThemePalette.palette(for: variant)
            UserDefaults.standard.set(variant.rawValue, forKey: "gitdesk.theme")
        }
    }

    private init() {
        let saved = UserDefaults.standard.string(forKey: "gitdesk.theme")
            .flatMap { ThemeVariant(rawValue: $0) } ?? .dark
        self.variant = saved
        self.current = ThemePalette.palette(for: saved)
    }
}

// MARK: - Theme (static accessors — drop-in compatible)

enum Theme {
    private static var p: ThemePalette { ThemeManager.shared.current }

    // Background Colors
    static var mainBG: Color { p.mainBG }
    static var sidebarBG: Color { p.sidebarBG }
    static var diffBG: Color { p.diffBG }
    static var panelHeaderBG: Color { p.panelHeaderBG }
    static var borderColor: Color { p.borderColor }

    // Primary
    static var primary: Color { p.primary }

    // Diff Colors
    static var diffAddText: Color { p.diffAddText }
    static var diffAddBG: Color { p.diffAddBG }
    static var diffRemoveText: Color { p.diffRemoveText }
    static var diffRemoveBG: Color { p.diffRemoveBG }

    // Badge Colors
    static var modifiedBadge: Color { p.modifiedBadge }
    static var addedBadge: Color { p.addedBadge }
    static var deletedBadge: Color { p.deletedBadge }
    static var conflictedBadge: Color { p.conflictedBadge }
    static var untrackedBadge: Color { p.untrackedBadge }

    // Text
    static var textPrimary: Color { p.textPrimary }
    static var textSecondary: Color { p.textSecondary }
    static var textTertiary: Color { p.textTertiary }
    static var textDimmed: Color { p.textDimmed }

    // Interactive
    static var subtleBG: Color { p.subtleBG }
    static var hoverBG: Color { p.hoverBG }
    static var pressedBG: Color { p.pressedBG }
    static var lineNumberColor: Color { p.lineNumberColor }
    static var hunkHeaderBG: Color { p.hunkHeaderBG }
    static var inputStroke: Color { p.inputStroke }
    static var badgeBG: Color { p.badgeBG }

    // Window Controls (constant)
    static let windowClose = Color(hex: 0xFF5F57)
    static let windowMinimize = Color(hex: 0xFEBC2E)
    static let windowMaximize = Color(hex: 0x28C840)

    // Sizes (constant)
    static let headerHeight: CGFloat = 48
    static let footerHeight: CGFloat = 24
    static let sidebarWidth: CGFloat = 256
    static let changesPanelWidth: CGFloat = 288
    static let minWindowWidth: CGFloat = 960
    static let minWindowHeight: CGFloat = 600

    // Fonts (constant)
    static let monoFont = Font.system(size: 11, design: .monospaced)
    static let monoFontMedium = Font.system(size: 11, weight: .medium, design: .monospaced)
    static let uiFont = Font.system(size: 12)
    static let uiFontMedium = Font.system(size: 12, weight: .medium)
    static let uiFontSemibold = Font.system(size: 12, weight: .semibold)
    static let smallFont = Font.system(size: 10)
    static let smallFontMedium = Font.system(size: 10, weight: .medium)

    // Helpers
    static func badgeColor(for status: FileChangeStatus) -> Color {
        switch status {
        case .modified: return modifiedBadge
        case .added: return addedBadge
        case .deleted: return deletedBadge
        case .conflicted: return conflictedBadge
        case .untracked: return untrackedBadge
        case .renamed: return primary
        }
    }
}

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}
