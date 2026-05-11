import SwiftUI

extension Color {
    // MARK: - Brand
    static let hfPrimary    = Color(hex: "#FF8243") // Tropical orange — CTAs, streaks
    static let hfSecondary  = Color(hex: "#FFC0CB") // Soft pink — accents
    static let hfTertiary   = Color(hex: "#069494") // Teal — completion, AI, success
    static let hfAccent     = Color(hex: "#FCE883") // Warm yellow — AI Insight surfaces

    // MARK: - Surfaces
    static let hfBackground     = Color(hex: "#FFF9F5") // Warm cream — app background
    static let hfSurface        = Color(hex: "#FFFFFF") // Cards, sheets
    static let hfSurfaceVariant = Color(hex: "#F4F1EF") // Disabled, gutters

    // MARK: - Text
    static let hfOnBackground     = Color(hex: "#302E2C") // Primary text — warm near-black
    static let hfOnSurfaceVariant = Color(hex: "#5E5B58") // Secondary text

    // MARK: - Structural
    static let hfOutline = Color(hex: "#E0DAD6") // Hairline borders

    // MARK: - Semantic state
    static let hfDanger      = Color(hex: "#EF4444")
    static let hfDangerBg    = Color(hex: "#FEF2F2")
    static let hfDangerBorder = Color(hex: "#FECACA")

    // MARK: - Category accents (bg / fg pairs)
    enum Category {
        static let healthBg        = Color(hex: "#DCFCE7")
        static let healthFg        = Color(hex: "#15803D")
        static let fitnessBg       = Color(hex: "#FFEDD5")
        static let fitnessFg       = Color(hex: "#C2410C")
        static let mindfulnessBg   = Color(hex: "#F3E8FF")
        static let mindfulnessFg   = Color(hex: "#7E22CE")
        static let productivityBg  = Color(hex: "#DBEAFE")
        static let productivityFg  = Color(hex: "#1D4ED8")
        static let learningBg      = Color(hex: "#FEF9C3")
        static let learningFg      = Color(hex: "#A16207")
        static let socialBg        = Color(hex: "#FCE7F3")
        static let socialFg        = Color(hex: "#BE185D")
    }
}

// MARK: - Hex initialiser
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: Double
        switch hex.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >>  8) & 0xFF) / 255
            b = Double( int        & 0xFF) / 255
        default:
            r = 1; g = 1; b = 1
        }
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Category helper
enum HabitCategory: String, CaseIterable {
    case health, fitness, mindfulness, productivity, learning, social

    var bg: Color {
        switch self {
        case .health:        return .Category.healthBg
        case .fitness:       return .Category.fitnessBg
        case .mindfulness:   return .Category.mindfulnessBg
        case .productivity:  return .Category.productivityBg
        case .learning:      return .Category.learningBg
        case .social:        return .Category.socialBg
        }
    }

    var fg: Color {
        switch self {
        case .health:        return .Category.healthFg
        case .fitness:       return .Category.fitnessFg
        case .mindfulness:   return .Category.mindfulnessFg
        case .productivity:  return .Category.productivityFg
        case .learning:      return .Category.learningFg
        case .social:        return .Category.socialFg
        }
    }

    var icon: String {
        switch self {
        case .health:        return "heart.fill"
        case .fitness:       return "figure.run"
        case .mindfulness:   return "brain.head.profile"
        case .productivity:  return "briefcase.fill"
        case .learning:      return "book.fill"
        case .social:        return "person.2.fill"
        }
    }
}
