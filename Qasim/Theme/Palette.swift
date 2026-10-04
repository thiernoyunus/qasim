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

// MARK: - Redesign (Kiki-style) tokens and pieces

extension Palette {
    /// Window background.
    static let ground = Color(red: 0.957, green: 0.937, blue: 0.894)
    /// Inside fields and boxes.
    static let field = Color(red: 0.984, green: 0.973, blue: 0.945)
    /// Secondary text. Solid (not ink at an opacity) so it stays 6:1 on ground.
    static let muted = Color(red: 0.373, green: 0.341, blue: 0.306)
    /// Hairlines between rows.
    static let line = Color(red: 0.106, green: 0.090, blue: 0.075).opacity(0.14)
    /// Distracted time in charts: lighter than ink so the two differ by lightness, not just hue.
    static let distracted = Color(red: 0.910, green: 0.643, blue: 0.549)
}

/// "TASK TO COMPLETE"-style label above a field or group.
struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .semibold))
            .tracking(0.7)
            .foregroundStyle(Palette.muted)
            .accessibilityAddTraits(.isHeader)
    }
}

/// The bordered box fields and settings rows sit in.
struct FieldBox<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .background(Palette.field, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Palette.ink, lineWidth: 1.5)
            )
    }
}

/// Divider between rows inside a FieldBox.
struct RowLine: View {
    var body: some View { Palette.line.frame(height: 1) }
}

/// The full-width START / CONTINUE / DONE bar at the bottom of a screen.
struct BarButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .bold))
            .tracking(1.8)
            .textCase(.uppercase)
            .foregroundStyle(Palette.field)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(Palette.ink.opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.4))
            .contentShape(Rectangle())
    }
}

/// 44pt icon-only button for top bars.
struct IconButton: View {
    let systemName: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .help(label)
    }
}

/// Top bar: optional back arrow, centered title, optional trailing control.
struct ScreenHeader<Trailing: View>: View {
    var title: String = ""
    var back: (() -> Void)?
    @ViewBuilder var trailing: Trailing

    var body: some View {
        ZStack {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            HStack {
                if let back {
                    IconButton(systemName: "arrow.left", label: "Back", action: back)
                }
                Spacer()
                trailing
            }
        }
        .frame(height: 52)
        .padding(.horizontal, 12)
    }
}

extension ScreenHeader where Trailing == EmptyView {
    init(title: String = "", back: (() -> Void)? = nil) {
        self.init(title: title, back: back) { EmptyView() }
    }
}

/// Small on/off switch row used in settings and onboarding.
struct SwitchRow: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            Text(title).font(.system(size: 15)).foregroundStyle(Palette.ink)
        }
        .toggleStyle(.switch)
        .tint(Palette.ink)
        .padding(.horizontal, 14)
        .frame(minHeight: 50)
    }
}
