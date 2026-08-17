import SwiftUI

struct PrayerMatView: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color(red: 0.18, green: 0.42, blue: 0.28))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Palette.flame.opacity(0.55), lineWidth: 2)
            )
            .frame(width: 92, height: 56)
            .shadow(color: .black.opacity(0.2), radius: 6, y: 3)
            .allowsHitTesting(false)
    }
}

struct LightSwitchStage: View {
    var isOff: Bool
    var flashWhite: Bool

    var body: some View {
        Rectangle()
            .fill(
                flashWhite
                    ? Color.white.opacity(0.92)
                    : Color.black.opacity(isOff ? 0.96 : 0)
            )
            .animation(.easeInOut(duration: 0.06), value: isOff)
            .animation(.easeInOut(duration: 0.04), value: flashWhite)
            .allowsHitTesting(false)
    }
}

struct FireField: View {
    var rect: CGRect
    var time: TimeInterval
    var intensity: CGFloat

    var body: some View {
        Canvas { context, _ in
            guard rect.width > 8, rect.height > 8, intensity > 0.02 else { return }
            let count = max(1, Int(46 * Double(intensity)))
            for i in 0..<count {
                let seed = Double(i) * 13.91
                let col = (sin(seed * 1.7) * 0.5 + 0.5)
                let x = rect.minX + 16 + CGFloat(col) * (rect.width - 32)
                let speed = 0.22 + seed.truncatingRemainder(dividingBy: 0.18)
                let grow = min(1, intensity * 1.15)
                let w: CGFloat = (18 + CGFloat(i % 5) * 4) * grow
                let h = w * 1.7
                let fall = CGFloat((time * speed + seed).truncatingRemainder(dividingBy: 1.0))
                let y = rect.minY - h + fall * (rect.height + h * 2)
                let lean = CGFloat(sin(seed * 2.7)) * w * 0.18
                var flame = Path()
                flame.move(to: CGPoint(x: x, y: y + h / 2))
                flame.addCurve(
                    to: CGPoint(x: x - w * 0.58, y: y + h * 0.08),
                    control1: CGPoint(x: x - w * 0.72, y: y + h * 0.34),
                    control2: CGPoint(x: x - w * 0.68, y: y + h * 0.14)
                )
                flame.addCurve(
                    to: CGPoint(x: x - w * 0.22, y: y - h * 0.24),
                    control1: CGPoint(x: x - w * 0.44, y: y - h * 0.12),
                    control2: CGPoint(x: x - w * 0.30, y: y - h * 0.42)
                )
                flame.addCurve(
                    to: CGPoint(x: x + lean, y: y - h * 0.82),
                    control1: CGPoint(x: x - w * 0.10, y: y - h * 0.52),
                    control2: CGPoint(x: x + lean * 0.35, y: y - h * 0.72)
                )
                flame.addCurve(
                    to: CGPoint(x: x + w * 0.48, y: y - h * 0.06),
                    control1: CGPoint(x: x + w * 0.12, y: y - h * 0.58),
                    control2: CGPoint(x: x + w * 0.48, y: y - h * 0.30)
                )
                flame.addCurve(
                    to: CGPoint(x: x, y: y + h / 2),
                    control1: CGPoint(x: x + w * 0.62, y: y + h * 0.18),
                    control2: CGPoint(x: x + w * 0.44, y: y + h * 0.40)
                )
                var core = Path()
                core.move(to: CGPoint(x: x, y: y + h * 0.30))
                core.addCurve(
                    to: CGPoint(x: x - w * 0.20, y: y + h * 0.04),
                    control1: CGPoint(x: x - w * 0.24, y: y + h * 0.22),
                    control2: CGPoint(x: x - w * 0.26, y: y + h * 0.08)
                )
                core.addCurve(
                    to: CGPoint(x: x + lean * 0.35, y: y - h * 0.36),
                    control1: CGPoint(x: x - w * 0.06, y: y - h * 0.12),
                    control2: CGPoint(x: x + lean * 0.22, y: y - h * 0.26)
                )
                core.addCurve(
                    to: CGPoint(x: x + w * 0.22, y: y + h * 0.08),
                    control1: CGPoint(x: x + w * 0.16, y: y - h * 0.22),
                    control2: CGPoint(x: x + w * 0.30, y: y - h * 0.04)
                )
                core.addCurve(
                    to: CGPoint(x: x, y: y + h * 0.30),
                    control1: CGPoint(x: x + w * 0.22, y: y + h * 0.20),
                    control2: CGPoint(x: x + w * 0.10, y: y + h * 0.28)
                )
                context.fill(
                    flame,
                    with: .color(Palette.ember.opacity(0.92 * intensity))
                )
                context.stroke(flame, with: .color(Palette.ink.opacity(0.8 * intensity)), lineWidth: 1.5)
                context.fill(core, with: .color(Palette.flame.opacity(0.94 * intensity)))
            }
        }
        .allowsHitTesting(false)
    }
}

struct NoteField: View {
    var rect: CGRect
    var time: TimeInterval
    var intensity: CGFloat

    var body: some View {
        Canvas { context, _ in
            guard rect.width > 8, rect.height > 8, intensity > 0.02 else { return }
            let total = 16
            let visible = max(1, Int(ceil(Double(total) * Double(intensity))))
            for i in 0..<visible {
                let seed = Double(i) * 9.17
                let x = rect.minX + 18 + CGFloat((sin(seed) * 0.5 + 0.5)) * (rect.width - 70)
                let y = rect.minY + 18 + CGFloat((cos(seed * 1.3) * 0.5 + 0.5)) * (rect.height - 70)
                let birth = CGFloat(i) / CGFloat(total)
                let local = min(1, max(0, (intensity - birth) / 0.18))
                let scale = 0.55 + 0.45 * local
                let w: CGFloat = 54 * scale
                let card = Path(roundedRect: CGRect(x: x, y: y, width: w, height: w), cornerRadius: 4)
                context.opacity = Double(local)
                context.fill(card, with: .color(i.isMultiple(of: 2) ? Palette.flame.opacity(0.92) : Palette.cream))
                context.stroke(card, with: .color(Palette.ink.opacity(0.55)), lineWidth: 1.5)
                var line = Path()
                line.move(to: CGPoint(x: x + 8, y: y + 18 * scale))
                line.addLine(to: CGPoint(x: x + 46 * scale, y: y + 18 * scale))
                line.move(to: CGPoint(x: x + 8, y: y + 28 * scale))
                line.addLine(to: CGPoint(x: x + 40 * scale, y: y + 28 * scale))
                context.stroke(line, with: .color(Palette.ink.opacity(0.35)), lineWidth: 1)
                _ = time
            }
        }
        .allowsHitTesting(false)
    }
}
