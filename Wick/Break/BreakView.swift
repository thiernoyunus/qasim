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
                breakActivity: model.breakState == .running ? model.breakActivity : nil
            )
        }
        .frame(height: 250)
    }

    @ViewBuilder
    private var footer: some View {
        VStack(spacing: 14) {
            switch model.breakState {
            case .choice:
                Text("Nice work! Remember Allah?")
                    .font(Typeface.display(19))
                    .foregroundStyle(Palette.cream)
                HStack(spacing: 8) {
                    Button("SKIP") { model.skipBreak() }
                        .buttonStyle(BreakButtonStyle())
                    Button("START") { model.startBreak() }
                        .buttonStyle(BreakButtonStyle())
                }
            case .running:
                Text(model.breakActivity?.title ?? "Break")
                    .font(Typeface.display(19))
                    .foregroundStyle(Palette.cream)
                Text(model.breakRemainingLabel)
                    .font(.system(size: 44, weight: .regular, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Palette.cream)
                Button("SKIP BREAK") { model.skipBreak() }
                    .buttonStyle(BreakButtonStyle())
            case .repeatChoice:
                Text("Repeat session?")
                    .font(Typeface.display(19))
                    .foregroundStyle(Palette.cream)
                HStack(spacing: 8) {
                    Button("NO") { model.declineRepeat() }
                        .buttonStyle(BreakButtonStyle())
                    Button("YES") { model.repeatSession() }
                        .buttonStyle(BreakButtonStyle())
                }
            case .none:
                EmptyView()
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .background(Color.black)
    }
}

private struct BreakButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .frame(minWidth: 78)
            .padding(.vertical, 9)
            .foregroundStyle(Palette.cream)
            .background(
                Capsule()
                    .stroke(Palette.cream.opacity(configuration.isPressed ? 0.55 : 0.85), lineWidth: 1)
            )
    }
}
