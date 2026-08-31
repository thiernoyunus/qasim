import SwiftUI

private func stableNoise(_ seed: Double) -> CGFloat {
    let value = sin(seed * 12.9898) * 43758.5453
    return CGFloat(value - floor(value))
}

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
    var age: TimeInterval
    var intensity: CGFloat

    var body: some View {
        Canvas { context, _ in
            guard rect.width > 8, rect.height > 8, intensity > 0.02 else { return }
            // ponytail: 180 vector flames stays close to Kiki's 200 sprites
            // while keeping the overlay in one Canvas.
            let count = 240
            // Keep adding flames almost until the 10-second theater stage changes.
            let spawnInterval = 9.8 / Double(count)
            for i in 0..<count {
                let seed = Double(i) * 13.91
                let local = min(1, max(0, (age - Double(i) * spawnInterval) / 0.28))
                guard local > 0 else { continue }
                let sizeNoise = 0.7 + stableNoise(seed * 1.71) * 0.6
                let pulse = 0.9 + 0.1 * (sin(time * 1.8 + seed) * 0.5 + 0.5)
                let grow = min(1, intensity * 1.2) * (0.45 + 0.55 * CGFloat(local)) * CGFloat(pulse)
                let w: CGFloat = (18 + 28 * sizeNoise) * grow
                let h = w * 1.7
                let xNoise = stableNoise(seed * 2.13)
                let yNoise = stableNoise(seed * 2.91)
                let xInset = max(18, w * 0.7)
                let topInset = max(18, h * 0.85)
                let bottomInset = max(18, h * 0.5)
                let x = rect.minX + xInset + xNoise * max(0, rect.width - xInset * 2)
                let y = rect.minY + topInset + yNoise * max(0, rect.height - topInset - bottomInset)
                    + CGFloat(sin(time * 1.4 + seed)) * 3
                let opacity = intensity * CGFloat(0.18 + 0.82 * local)
                let lean = (CGFloat(sin(seed * 2.7)) * 0.18 + CGFloat(sin(time * 4.0 + seed)) * 0.05) * w
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
                context.opacity = Double(opacity)
                context.fill(flame, with: .color(Palette.ember.opacity(0.92)))
                context.stroke(flame, with: .color(Palette.ink.opacity(0.8)), lineWidth: 1.5)
                context.fill(core, with: .color(Palette.flame.opacity(0.94)))
            }
        }
        .allowsHitTesting(false)
    }
}

struct NoteField: View {
    var rect: CGRect
    var age: TimeInterval
    var intensity: CGFloat

    var body: some View {
        Canvas { context, _ in
            guard rect.width > 8, rect.height > 8, intensity > 0.02 else { return }
            let total = 200
            // Match the paper sound: notes arrive in small waves every 0.75s
            // instead of appearing continuously between unrelated sound cues.
            let notesPerWave = 16
            let waveInterval = 0.75
            let waveDuration = 0.36
            for i in 0..<total {
                let seed = Double(i) * 9.17
                let wave = i / notesPerWave
                let withinWave = i % notesPerWave
                let spawnTime = Double(wave) * waveInterval
                    + Double(withinWave) / Double(notesPerWave) * waveDuration
                let local = min(1, max(0, (age - spawnTime) / 0.22))
                guard local > 0 else { continue }
                let base = 38 + 16 * stableNoise(seed * 1.43)
                let scale = 0.68 + 0.32 * local
                let w = base * scale
                let xRange = max(0, rect.width - w - 40)
                let yRange = max(0, rect.height - w - 40)
                let x = rect.minX + 20 + stableNoise(seed * 2.07) * xRange
                let y = rect.minY + 20 + stableNoise(seed * 2.89) * yRange
                let card = Path(roundedRect: CGRect(x: x, y: y, width: w, height: w), cornerRadius: 4)
                context.opacity = Double(intensity * CGFloat(0.2 + 0.8 * local))
                context.fill(card, with: .color(i.isMultiple(of: 2) ? Palette.flame.opacity(0.92) : Palette.cream))
                context.stroke(card, with: .color(Palette.ink.opacity(0.55)), lineWidth: 1.5)
                var line = Path()
                line.move(to: CGPoint(x: x + 8, y: y + 18 * scale))
                line.addLine(to: CGPoint(x: x + 46 * scale, y: y + 18 * scale))
                line.move(to: CGPoint(x: x + 8, y: y + 28 * scale))
                line.addLine(to: CGPoint(x: x + 40 * scale, y: y + 28 * scale))
                context.stroke(line, with: .color(Palette.ink.opacity(0.35)), lineWidth: 1)
            }
        }
        .allowsHitTesting(false)
    }
}

struct SprayField: View {
    var rect: CGRect
    var time: TimeInterval
    var intensity: CGFloat

    var body: some View {
        Canvas { context, _ in
            guard rect.width > 8, rect.height > 8, intensity > 0.02 else { return }
            // Black aerosol mist: broad overlapping clouds obscure most of the
            // window while leaving enough transparency for notes to read.
            let strength = min(1, max(0, intensity))
            context.fill(
                Path(rect),
                with: .color(Color.black.opacity(0.50 + 0.28 * strength))
            )

            let cloudCount = 96
            for i in 0..<cloudCount {
                let seed = Double(i) * 7.41
                let x = rect.minX + stableNoise(seed * 1.37) * rect.width
                    + CGFloat(sin(time * 0.22 + seed)) * 22
                let y = rect.minY + stableNoise(seed * 2.23) * rect.height
                    + CGFloat(cos(time * 0.18 + seed)) * 18
                let width = 70 + stableNoise(seed * 3.11) * 210
                let height = width * (0.45 + stableNoise(seed * 4.27) * 0.5)
                let cloud = Path(
                    ellipseIn: CGRect(
                        x: x - width / 2,
                        y: y - height / 2,
                        width: width,
                        height: height
                    )
                )
                context.opacity = Double(strength * CGFloat(0.04 + stableNoise(seed * 5.19) * 0.08))
                context.fill(cloud, with: .color(Color.black))
            }
        }
        .blur(radius: 22)
        .allowsHitTesting(false)
    }
}
