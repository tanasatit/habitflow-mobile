import SwiftUI

// Design system uses Plus Jakarta Sans (headlines) + Be Vietnam Pro (body).
// iOS ships neither, so we map to the closest system equivalents:
//   Plus Jakarta Sans  → .rounded design variant (friendly, geometric)
//   Be Vietnam Pro     → system default (neutral, readable)
// Bundle the actual fonts in a later polish pass if needed.

extension Font {
    // MARK: - Display / hero  (italic ExtraBold — "Your Oasis.")
    static let hfDisplay = Font.system(size: 40, weight: .heavy, design: .rounded).italic()

    // MARK: - Headlines
    static let hfH1 = Font.system(size: 32, weight: .heavy,    design: .rounded)
    static let hfH2 = Font.system(size: 24, weight: .bold,     design: .rounded)
    static let hfH3 = Font.system(size: 18, weight: .bold,     design: .rounded)

    // MARK: - Body (Be Vietnam Pro → default system)
    static let hfBody      = Font.system(size: 14, weight: .regular)
    static let hfBodySmall = Font.system(size: 12, weight: .regular)
    static let hfTiny      = Font.system(size: 11, weight: .regular)

    // MARK: - Numeric display  (streak counters — tabular, ExtraBold)
    static let hfNumericDisplay = Font.system(size: 48, weight: .heavy, design: .rounded)
        .monospacedDigit()
    static let hfNumericLarge  = Font.system(size: 38, weight: .heavy, design: .rounded)
        .monospacedDigit()
    static let hfNumericMedium = Font.system(size: 24, weight: .bold,  design: .rounded)
        .monospacedDigit()

    // MARK: - Label (uppercase, tight tracking — "SEND" button)
    static let hfLabelStrong = Font.system(size: 12, weight: .bold, design: .rounded)
}

// MARK: - Corner radii (from design tokens)
enum HFRadius {
    static let sm:   CGFloat = 8
    static let md:   CGFloat = 12
    static let lg:   CGFloat = 16
    static let xl:   CGFloat = 20
    static let xxl:  CGFloat = 24
    static let full: CGFloat = 9999
}

// MARK: - Spacing (4 pt grid)
enum HFSpacing {
    static let s1:  CGFloat = 4
    static let s2:  CGFloat = 8
    static let s3:  CGFloat = 12
    static let s4:  CGFloat = 16
    static let s5:  CGFloat = 20
    static let s6:  CGFloat = 24
    static let s8:  CGFloat = 32
    static let s10: CGFloat = 40
}
