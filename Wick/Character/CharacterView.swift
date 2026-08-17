import AppKit
import SwiftUI

struct CharacterView: View {
    var companion: CompanionID
    var pose: WickPose
    var facing: CGFloat
    var hopLift: CGFloat
    var breatheScale: CGFloat
    var pressed: Bool
    var size: CGSize
    var lightsOff = false
    var switchPressed = false
    var breakActivity: BreakActivity? = nil

    var body: some View {
        ZStack {
            Ellipse()
                .fill(Color.black.opacity(0.18))
                .frame(width: size.width * 0.5, height: 16)
                .offset(y: size.height * 0.37)
                .blur(radius: 1)

            ZStack {
                sprite
            }
            .offset(y: -hopLift)

            if let breakActivity {
                BreakPropView(activity: breakActivity, companion: companion, size: size)
                    .offset(y: -hopLift)
            }
        }
        .frame(width: size.width, height: size.height)
        .animation(.easeOut(duration: 0.12), value: pose)
        .animation(.easeOut(duration: 0.08), value: pressed)
    }

    @ViewBuilder
    private var sprite: some View {
        if breakActivity == .adhkar, companion == .qasim {
            TimelineView(.animation(minimumInterval: 0.12)) { timeline in
                renderedSprite(named: tasbihAsset(at: timeline.date))
            }
        } else if pose == .typing {
            TimelineView(.animation(minimumInterval: 0.16)) { timeline in
                renderedSprite(named: resolvedAsset)
                    .offset(y: typingBob(at: timeline.date))
            }
        } else {
            renderedSprite(named: resolvedAsset)
        }
    }

    private func renderedSprite(named: String) -> some View {
        Image(named)
            .resizable()
            .interpolation(companion.isPixelCompanion ? .none : .high)
            .scaledToFit()
            .scaleEffect(x: facing, y: 1, anchor: .center)
            .scaleEffect(breatheScale * (pressed ? 0.94 : 1))
            .shadow(color: .black.opacity(0.18), radius: 8, y: 6)
    }

    private func tasbihAsset(at date: Date) -> String {
        Int(date.timeIntervalSinceReferenceDate * 1.6) % 2 == 0
            ? "qasim-tasbih-a"
            : "qasim-tasbih-b"
    }

    private func typingBob(at date: Date) -> CGFloat {
        let phase = (sin(date.timeIntervalSinceReferenceDate * 7.5) + 1) * 0.5
        return -CGFloat(phase) * 1.5
    }

    private var resolvedAsset: String {
        let named: String
        if breakActivity == .quran, companion == .qasim {
            named = "qasim-quran"
        } else if pose == .flipSwitch, companion == .qasim {
            named = lightsOff || switchPressed ? "qasim-switch-down" : "qasim-switch-up"
        } else {
            named = companion.assetName(for: pose)
        }
        if NSImage(named: named) != nil { return named }
#if DEBUG
        assertionFailure("Missing companion sprite: \(named)")
#endif
        let idle = companion.assetName(for: .idle)
        if NSImage(named: idle) != nil { return idle }
        return CompanionID.qasim.assetName(for: .idle)
    }
}

private struct BreakPropView: View {
    var activity: BreakActivity
    var companion: CompanionID
    var size: CGSize

    var body: some View {
        switch activity {
        case .adhkar:
            if companion == .qasim {
                EmptyView()
            } else {
                HStack(spacing: 3) {
                    ForEach(0..<7, id: \.self) { _ in
                        Circle()
                            .fill(Palette.ember)
                            .frame(width: 5, height: 5)
                    }
                }
                .padding(5)
                .background(Palette.cream.opacity(0.92), in: Capsule())
                .overlay(Capsule().stroke(Palette.ink.opacity(0.55), lineWidth: 1))
                .offset(x: size.width * 0.2, y: size.height * 0.12)
            }
        case .quran:
            if companion == .qasim {
                EmptyView()
            } else {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(Palette.ink)
                    .padding(6)
                    .background(Palette.cream.opacity(0.92), in: Circle())
                    .overlay(Circle().stroke(Palette.ink.opacity(0.55), lineWidth: 1))
                    .offset(y: size.height * 0.16)
            }
        case .rest:
            Text("z z")
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(Palette.inkSoft)
                .offset(x: size.width * 0.18, y: -size.height * 0.27)
        }
    }
}

struct SpeechBubbleView: View {
    var text: String
    var onDismiss: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 6) {
                Text(text)
                    .font(Typeface.display(16))
                    .foregroundStyle(Palette.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: true, vertical: true)
                if let onDismiss {
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(Palette.inkSoft)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dismiss")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Palette.cream, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Palette.ink, lineWidth: 2)
            )

            BubbleTail()
                .fill(Palette.cream)
                .overlay(BubbleTail().stroke(Palette.ink, lineWidth: 2))
                .frame(width: 14, height: 9)
                .offset(y: -1)
        }
        .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
    }
}

private struct BubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}
