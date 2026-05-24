import SwiftUI

enum MC {
    // MARK: Surfaces
    static let background = Color(hex: "#0B0B0C")
    static let surface = Color(hex: "#141414")
    static let elevated = Color(hex: "#1C1C1E")
    static let card = Color(hex: "#1F1F21")
    static let border = Color(hex: "#2C2C2E")

    // MARK: Text
    static let textPrimary = Color(hex: "#F3F0EE")
    static let textSecondary = Color(hex: "#8E8E93")
    static let textMuted = Color(hex: "#636366")

    // MARK: Accent
    static let signal = Color(hex: "#CF4500")
    static let lightSignal = Color(hex: "#F37338")
    static let clay = Color(hex: "#9A3A0A")

    // MARK: Semantic
    static let success = Color(hex: "#30D158")
    static let link = Color(hex: "#3860BE")

    // MARK: Typography
    static func headline(_ size: CGFloat) -> Font {
        Font.system(size: size, weight: .semibold, design: .rounded)
    }
    static func bodyText(_ size: CGFloat) -> Font {
        Font.system(size: size, weight: .regular, design: .rounded)
    }
    static func label(_ size: CGFloat) -> Font {
        Font.system(size: size, weight: .medium, design: .rounded)
    }

    static let tightTracking: CGFloat = -0.02
    static let eyebrowTracking: CGFloat = 0.04

    static let radiusSmall: CGFloat = 8
    static let radiusButton: CGFloat = 20
    static let radiusCard: CGFloat = 16
    static let radiusStadium: CGFloat = 24
    static let radiusPill: CGFloat = 999

    static let space8: CGFloat = 8
    static let space12: CGFloat = 12
    static let space16: CGFloat = 16
    static let space24: CGFloat = 24
    static let space32: CGFloat = 32

    static let shadowNav = Shadow(color: Color.black.opacity(0.3), radius: 24, x: 0, y: 8)
    static let shadowElevated = Shadow(color: Color.black.opacity(0.4), radius: 48, x: 0, y: 16)
}

struct Shadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

struct InkPillButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(MC.label(14))
            .foregroundStyle(MC.textPrimary)
            .padding(.vertical, 10)
            .padding(.horizontal, 24)
            .background(MC.textPrimary)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct OutlinePillButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(MC.label(14))
            .foregroundStyle(MC.textPrimary)
            .padding(.vertical, 10)
            .padding(.horizontal, 24)
            .background(Color.clear)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(MC.border, lineWidth: 1.5))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SignalPillButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(MC.label(13))
            .foregroundStyle(MC.textPrimary)
            .padding(.vertical, 8)
            .padding(.horizontal, 28)
            .background(MC.signal)
            .clipShape(Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SmallPillButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(MC.label(12))
            .foregroundStyle(MC.textSecondary)
            .padding(.vertical, 6)
            .padding(.horizontal, 14)
            .background(MC.elevated)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(MC.border, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension View {
    func mcHeadline(size: CGFloat) -> some View {
        self
            .font(MC.headline(size))
            .tracking(size * MC.tightTracking)
            .foregroundStyle(MC.textPrimary)
    }

    func mcBody(size: CGFloat = 14) -> some View {
        self
            .font(MC.bodyText(size))
            .foregroundStyle(MC.textSecondary)
    }

    func mcEyebrow() -> some View {
        self
            .font(MC.label(10))
            .tracking(10 * MC.eyebrowTracking)
            .textCase(.uppercase)
            .foregroundStyle(MC.textMuted)
    }

    func mcNavShadow() -> some View {
        self.shadow(color: Color.black.opacity(0.3), radius: 24, x: 0, y: 8)
    }

    func mcElevatedShadow() -> some View {
        self.shadow(color: Color.black.opacity(0.4), radius: 48, x: 0, y: 16)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
