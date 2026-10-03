import SwiftUI

enum Palette {
    static let paper = Color(red: 0.937, green: 0.898, blue: 0.816)
    static let paperDeep = Color(red: 0.890, green: 0.835, blue: 0.725)
    static let ink = Color(red: 0.102, green: 0.086, blue: 0.071)
    static let inkSoft = Color(red: 0.102, green: 0.086, blue: 0.071).opacity(0.62)
    static let ember = Color(red: 0.910, green: 0.278, blue: 0.090)
    static let flame = Color(red: 1.000, green: 0.729, blue: 0.031)
    static let wax = Color(red: 0.780, green: 0.490, blue: 0.196)
    static let soot = Color(red: 0.145, green: 0.122, blue: 0.098)
    static let cream = Color(red: 0.980, green: 0.953, blue: 0.890)
    static let good = Color(red: 0.290, green: 0.620, blue: 0.380)

    // Text-safe variants of the accent colors. The bright versions above are
    // for fills and large shapes; these reach at least 4.5:1 on paper, cream
    // and the footer tint (WCAG AA for body text).
    static let goodText = Color(red: 0.197, green: 0.422, blue: 0.258)
    static let emberText = Color(red: 0.692, green: 0.211, blue: 0.068)
    static let waxText = Color(red: 0.530, green: 0.333, blue: 0.133)
}

enum Typeface {
    static func display(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
}
