import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIComponents)
import UIComponents
#endif

/// Semantic palette for the AI Course Builder MVP design board.
///
/// The guiding visual direction is:
/// - warm off-white workspace
/// - deep navy navigation shell
/// - cool editorial blue as the primary action color
/// - muted teal and warm amber as supporting accents
/// - very soft grays for borders, tracks, and low-emphasis surfaces
///
/// Organize colors by role rather than screen so the palette can survive
/// layout changes without leaking raw hex values throughout the app.
public struct CourseBuilderThemePalette: Sendable {
    public struct Surface: Sendable {
        public var appCanvas: Color
        public var page: Color
        public var sidebar: Color
        public var sidebarActive: Color
        public var card: Color
        public var cardMuted: Color
        public var input: Color
        public var codeBlock: Color
        public var noteBlock: Color
        public var accentTint: Color
        public var successTint: Color
        public var warmTint: Color

        public init(
            appCanvas: Color,
            page: Color,
            sidebar: Color,
            sidebarActive: Color,
            card: Color,
            cardMuted: Color,
            input: Color,
            codeBlock: Color,
            noteBlock: Color,
            accentTint: Color,
            successTint: Color,
            warmTint: Color
        ) {
            self.appCanvas = appCanvas
            self.page = page
            self.sidebar = sidebar
            self.sidebarActive = sidebarActive
            self.card = card
            self.cardMuted = cardMuted
            self.input = input
            self.codeBlock = codeBlock
            self.noteBlock = noteBlock
            self.accentTint = accentTint
            self.successTint = successTint
            self.warmTint = warmTint
        }
    }

    public struct Text: Sendable {
        public var primary: Color
        public var secondary: Color
        public var tertiary: Color
        public var inverse: Color
        public var sidebarPrimary: Color
        public var sidebarSecondary: Color
        public var link: Color
        public var success: Color
        public var warning: Color
        public var danger: Color

        public init(
            primary: Color,
            secondary: Color,
            tertiary: Color,
            inverse: Color,
            sidebarPrimary: Color,
            sidebarSecondary: Color,
            link: Color,
            success: Color,
            warning: Color,
            danger: Color
        ) {
            self.primary = primary
            self.secondary = secondary
            self.tertiary = tertiary
            self.inverse = inverse
            self.sidebarPrimary = sidebarPrimary
            self.sidebarSecondary = sidebarSecondary
            self.link = link
            self.success = success
            self.warning = warning
            self.danger = danger
        }
    }

    public struct Accent: Sendable {
        public var primary: Color
        public var pressed: Color
        public var focusRing: Color
        public var softFill: Color
        public var teal: Color
        public var tealSoft: Color
        public var warm: Color
        public var warmSoft: Color

        public init(
            primary: Color,
            pressed: Color,
            focusRing: Color,
            softFill: Color,
            teal: Color,
            tealSoft: Color,
            warm: Color,
            warmSoft: Color
        ) {
            self.primary = primary
            self.pressed = pressed
            self.focusRing = focusRing
            self.softFill = softFill
            self.teal = teal
            self.tealSoft = tealSoft
            self.warm = warm
            self.warmSoft = warmSoft
        }
    }

    public struct State: Sendable {
        public var success: Color
        public var successSoft: Color
        public var warning: Color
        public var warningSoft: Color
        public var danger: Color
        public var dangerSoft: Color
        public var info: Color
        public var infoSoft: Color
        public var locked: Color
        public var progressTrack: Color
        public var progressCurrent: Color
        public var progressComplete: Color

        public init(
            success: Color,
            successSoft: Color,
            warning: Color,
            warningSoft: Color,
            danger: Color,
            dangerSoft: Color,
            info: Color,
            infoSoft: Color,
            locked: Color,
            progressTrack: Color,
            progressCurrent: Color,
            progressComplete: Color
        ) {
            self.success = success
            self.successSoft = successSoft
            self.warning = warning
            self.warningSoft = warningSoft
            self.danger = danger
            self.dangerSoft = dangerSoft
            self.info = info
            self.infoSoft = infoSoft
            self.locked = locked
            self.progressTrack = progressTrack
            self.progressCurrent = progressCurrent
            self.progressComplete = progressComplete
        }
    }

    public struct Border: Sendable {
        public var subtle: Color
        public var regular: Color
        public var strong: Color
        public var accent: Color
        public var inverse: Color

        public init(
            subtle: Color,
            regular: Color,
            strong: Color,
            accent: Color,
            inverse: Color
        ) {
            self.subtle = subtle
            self.regular = regular
            self.strong = strong
            self.accent = accent
            self.inverse = inverse
        }
    }

    public struct Overlay: Sendable {
        public var hover: Color
        public var pressed: Color
        public var selected: Color
        public var scrim: Color
        public var sidebarScrim: Color

        public init(
            hover: Color,
            pressed: Color,
            selected: Color,
            scrim: Color,
            sidebarScrim: Color
        ) {
            self.hover = hover
            self.pressed = pressed
            self.selected = selected
            self.scrim = scrim
            self.sidebarScrim = sidebarScrim
        }
    }

    public struct Decorative: Sendable {
        public var heroGlowWarm: Color
        public var heroGlowBlue: Color
        public var heroGlowLavender: Color
        public var cardShadow: Color
        public var floatingShadow: Color

        public init(
            heroGlowWarm: Color,
            heroGlowBlue: Color,
            heroGlowLavender: Color,
            cardShadow: Color,
            floatingShadow: Color
        ) {
            self.heroGlowWarm = heroGlowWarm
            self.heroGlowBlue = heroGlowBlue
            self.heroGlowLavender = heroGlowLavender
            self.cardShadow = cardShadow
            self.floatingShadow = floatingShadow
        }
    }

    public var surface: Surface
    public var text: Text
    public var accent: Accent
    public var state: State
    public var border: Border
    public var overlay: Overlay
    public var decorative: Decorative

    public init(
        surface: Surface,
        text: Text,
        accent: Accent,
        state: State,
        border: Border,
        overlay: Overlay,
        decorative: Decorative
    ) {
        self.surface = surface
        self.text = text
        self.accent = accent
        self.state = state
        self.border = border
        self.overlay = overlay
        self.decorative = decorative
    }
}

public extension CourseBuilderThemePalette {
    /// The default palette for the four-screen MVP board:
    /// Goal Intake, Home Dashboard, Session Workspace, Program Map.
    static let mvp = CourseBuilderThemePalette(
        surface: .init(
            appCanvas: .cb(light: 0xF7F3EE, dark: 0x0C131D),
            page: .cb(light: 0xFFFCF8, dark: 0x111B27),
            sidebar: .cb(light: 0x102A4A, dark: 0x0A1830),
            sidebarActive: .cb(light: 0x1A3A63, dark: 0x153154),
            card: .cb(light: 0xFFFEFC, dark: 0x172334),
            cardMuted: .cb(light: 0xF5F8FC, dark: 0x132031),
            input: .cb(light: 0xFBFCFE, dark: 0x0E1C2E),
            codeBlock: .cb(light: 0x112746, dark: 0x081424),
            noteBlock: .cb(light: 0xEEF4FB, dark: 0x102238),
            accentTint: .cb(light: 0xEDF3FF, dark: 0x12294A),
            successTint: .cb(light: 0xEAF7F2, dark: 0x112721),
            warmTint: .cb(light: 0xFFF4E6, dark: 0x2A1E10)
        ),
        text: .init(
            primary: .cb(light: 0x1A2E47, dark: 0xEDF4FF),
            secondary: .cb(light: 0x607086, dark: 0xA7B5C9),
            tertiary: .cb(light: 0x8D99AA, dark: 0x7E90A8),
            inverse: .cb(light: 0xFFFFFF, dark: 0xFFFFFF),
            sidebarPrimary: .cb(light: 0xF8FBFF, dark: 0xF2F7FF),
            sidebarSecondary: .cb(light: 0xAFC0D9, dark: 0x91A8C8),
            link: .cb(light: 0x2B61D4, dark: 0x7FA6FF),
            success: .cb(light: 0x2F936E, dark: 0x78D8B2),
            warning: .cb(light: 0xC9832E, dark: 0xF0C17F),
            danger: .cb(light: 0xBF5C54, dark: 0xF09A93)
        ),
        accent: .init(
            primary: .cb(light: 0x295FD3, dark: 0x74A0FF),
            pressed: .cb(light: 0x1C4CAF, dark: 0x5E8AEE),
            focusRing: .cb(light: 0x295FD3, dark: 0x74A0FF, alpha: 0.34),
            softFill: .cb(light: 0xEAF2FF, dark: 0x153154),
            teal: .cb(light: 0x4BA591, dark: 0x63CBB2),
            tealSoft: .cb(light: 0xE7F6F1, dark: 0x122C25),
            warm: .cb(light: 0xF0B15B, dark: 0xF5C47E),
            warmSoft: .cb(light: 0xFFF3E1, dark: 0x312311)
        ),
        state: .init(
            success: .cb(light: 0x45B57E, dark: 0x69D7A3),
            successSoft: .cb(light: 0xE9F7F0, dark: 0x10261F),
            warning: .cb(light: 0xE4A04D, dark: 0xF0BF78),
            warningSoft: .cb(light: 0xFFF4E4, dark: 0x2F2414),
            danger: .cb(light: 0xD96C64, dark: 0xEF8F88),
            dangerSoft: .cb(light: 0xFCEBE8, dark: 0x331A18),
            info: .cb(light: 0x295FD3, dark: 0x74A0FF),
            infoSoft: .cb(light: 0xEBF2FF, dark: 0x14294A),
            locked: .cb(light: 0xA6B2C2, dark: 0x6D809A),
            progressTrack: .cb(light: 0xDCE6F3, dark: 0x24384F),
            progressCurrent: .cb(light: 0x7B98D9, dark: 0x9BB8FF),
            progressComplete: .cb(light: 0x45B57E, dark: 0x69D7A3)
        ),
        border: .init(
            subtle: .cb(light: 0xEEF2F7, dark: 0x1A293C),
            regular: .cb(light: 0xDCE4EF, dark: 0x24364B),
            strong: .cb(light: 0xC5D2E2, dark: 0x31465F),
            accent: .cb(light: 0xAFC6F5, dark: 0x4B6FB7),
            inverse: .cb(light: 0xFFFFFF, dark: 0xFFFFFF, alpha: 0.12)
        ),
        overlay: .init(
            hover: .cb(light: 0x102A4A, dark: 0xFFFFFF, alpha: 0.04),
            pressed: .cb(light: 0x102A4A, dark: 0xFFFFFF, alpha: 0.08),
            selected: .cb(light: 0x295FD3, dark: 0x74A0FF, alpha: 0.10),
            scrim: .cb(light: 0x102A4A, dark: 0x000000, alpha: 0.12),
            sidebarScrim: .cb(light: 0xFFFFFF, dark: 0xFFFFFF, alpha: 0.08)
        ),
        decorative: .init(
            heroGlowWarm: .cb(light: 0xF4DCC8, dark: 0x5A3B28, alpha: 0.48),
            heroGlowBlue: .cb(light: 0xDCE7FB, dark: 0x24426E, alpha: 0.52),
            heroGlowLavender: .cb(light: 0xECE4FA, dark: 0x332B58, alpha: 0.42),
            cardShadow: .cb(light: 0x102A4A, dark: 0x000000, alpha: 0.08),
            floatingShadow: .cb(light: 0x102A4A, dark: 0x000000, alpha: 0.14)
        )
    )
}

#if canImport(UIComponents)
public extension Theme {
    /// Bridge the Course Builder palette into the existing `UIComponents`
    /// theme system so older UI primitives can still consume it.
    static let courseBuilderMVP = Theme(
        colors: .init(
            base: CourseBuilderThemePalette.mvp.surface.appCanvas,
            canvas: CourseBuilderThemePalette.mvp.surface.page,
            sidebar: CourseBuilderThemePalette.mvp.surface.sidebar,
            inspector: CourseBuilderThemePalette.mvp.surface.cardMuted,
            card: CourseBuilderThemePalette.mvp.surface.card,
            input: CourseBuilderThemePalette.mvp.surface.input,
            stroke: CourseBuilderThemePalette.mvp.border.regular,
            strokeSubtle: CourseBuilderThemePalette.mvp.border.subtle,
            strokeFaint: CourseBuilderThemePalette.mvp.border.subtle,
            cardEdge: CourseBuilderThemePalette.mvp.border.strong,
            accent: CourseBuilderThemePalette.mvp.accent.primary,
            accentDeep: CourseBuilderThemePalette.mvp.accent.pressed,
            statusOk: CourseBuilderThemePalette.mvp.state.success,
            primaryText: CourseBuilderThemePalette.mvp.text.primary,
            hoverOverlay: CourseBuilderThemePalette.mvp.overlay.hover,
            hoverOverlayStrong: CourseBuilderThemePalette.mvp.overlay.pressed,
            selectedOverlay: CourseBuilderThemePalette.mvp.overlay.selected
        )
    )
}
#endif

private extension Color {
    static func cb(_ hex: UInt32, alpha: Double = 1.0) -> Color {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        return Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    static func cb(light: UInt32, dark: UInt32, alpha: Double = 1.0) -> Color {
        cb(light: cb(light, alpha: alpha), dark: cb(dark, alpha: alpha))
    }

    static func cb(light: Color, dark: Color) -> Color {
        #if canImport(UIKit)
        return Color(
            uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
            }
        )
        #elseif canImport(AppKit)
        return Color(
            nsColor: NSColor(name: nil) { appearance in
                let isDark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
                return isDark ? NSColor(dark) : NSColor(light)
            }
        )
        #else
        return dark
        #endif
    }
}
