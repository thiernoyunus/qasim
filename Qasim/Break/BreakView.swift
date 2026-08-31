import SwiftUI

struct BreakView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        VStack(spacing: 0) {
            characterStage
            footer
        }
        .background(Palette.paper)
        .preferredColorScheme(.light)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var characterStage: some View {
        ZStack {
            Palette.cream
            CharacterView(
                companion: model.prefs.companion,
                pose: model.breakActivity?.pose ?? .idle,
                facing: 1,
                hopLift: 0,
                breatheScale: 1,
                pressed: false,
                size: CGSize(width: 180, height: 194),
                breakActivity: model.breakState == .running ? model.breakActivity : nil,
                celebrating: model.breakState == .choice && !model.prefs.motionReduced
            )
        }
        .frame(height: 250)
    }

    @ViewBuilder
    private var footer: some View {
        VStack(spacing: 14) {
            switch model.breakState {
            case .choice:
                Text("Session complete!")
                    .font(Typeface.display(19))
                    .foregroundStyle(Palette.ink)
                Text("Nice work. Want to take a break?")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.inkSoft)
                HStack(spacing: 8) {
                    Button("Not now") { model.skipBreak() }
                        .buttonStyle(BreakButtonStyle(filled: false))
                    Button("Take a break") { model.startBreak() }
                        .buttonStyle(BreakButtonStyle(filled: true))
                }
                statsButton
            case .running:
                Text(model.breakActivity?.title ?? "Break")
                    .font(Typeface.display(19))
                    .foregroundStyle(Palette.ink)
                Text(model.breakRemainingLabel)
                    .font(.system(size: 44, weight: .regular, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Palette.ink)
                Button("Skip break") { model.skipBreak() }
                    .buttonStyle(BreakButtonStyle(filled: false))
            case .repeatChoice:
                Text("Ready for another?")
                    .font(Typeface.display(19))
                    .foregroundStyle(Palette.ink)
                Text("Keep your focus going?")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.inkSoft)
                HStack(spacing: 8) {
                    Button("Back to Home") { model.declineRepeat() }
                        .buttonStyle(BreakButtonStyle(filled: false))
                    Button("Repeat session") { model.repeatSession() }
                        .buttonStyle(BreakButtonStyle(filled: true))
                }
                statsButton
            case .none:
                EmptyView()
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(Palette.paper)
    }

    private var statsButton: some View {
        Button { model.openProgress(showStats: true) } label: {
            Label("View stats", systemImage: "chart.bar.fill")
        }
        .buttonStyle(BreakStatsButtonStyle())
    }
}

private struct BreakButtonStyle: ButtonStyle {
    var filled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .frame(maxWidth: .infinity, minHeight: 36)
            .foregroundStyle(filled ? Palette.cream : Palette.ink)
            .background(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(filled ? Palette.ink : Palette.cream)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .stroke(filled ? Color.clear : Palette.ink.opacity(0.32), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
    }
}

private struct BreakStatsButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(Palette.inkSoft.opacity(configuration.isPressed ? 0.6 : 1))
            .padding(.vertical, 4)
    }
}
