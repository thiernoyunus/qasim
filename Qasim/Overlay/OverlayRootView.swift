import SwiftUI

struct OverlayRootView: View {
    @Bindable var model: AppModel
    var screenFrame: CGRect
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    var body: some View {
        GeometryReader { geo in
            let brain = model.brain
            let size = brain.size(for: model.prefs)
            ZStack(alignment: .topLeading) {
                LightSwitchStage(
                    isOff: model.lightsOff,
                    flashWhite: model.flashWhite
                )

                if model.theater == .fire {
                    FireField(
                        rect: model.fireRectSwiftUI,
                        time: model.now,
                        age: model.effectAge,
                        intensity: model.effectIntensity
                    )
                }

                if model.theater == .notes {
                    NoteField(
                        rect: model.fireRectSwiftUI,
                        age: model.effectAge,
                        intensity: model.effectIntensity
                    )
                }

                if model.theater == .spray {
                    SprayField(
                        rect: model.fireRectSwiftUI,
                        time: model.now,
                        intensity: model.effectIntensity
                    )
                }

                if (model.salah.matVisible || model.previewingSalah), model.prefs.companion != .qasim {
                    PrayerMatView()
                        .position(x: brain.position.x, y: brain.position.y + size.height * 0.28)
                }

                if model.showPet, let ask = model.salah.ask {
                    let placed = bubblePlacement(
                        headX: brain.position.x,
                        halfWidth: 140,
                        screenWidth: geo.size.width
                    )
                    SalahAskBubbleView(
                        text: SpeechLines.salahAsk(ask),
                        showSnooze: !ask.isFinal,
                        tailOffset: placed.tail,
                        onRise: { model.answerSalahRising() },
                        onSnooze: { model.answerSalahSnooze() }
                    )
                    .position(
                        x: placed.x,
                        y: max(52, brain.position.y - size.height * 0.5 - 60)
                    )
                    .transition(.scale.combined(with: .opacity))
                } else if model.showPet, let text = brain.bubble {
                    let placed = bubblePlacement(
                        headX: brain.position.x,
                        halfWidth: SpeechBubbleView.halfWidth(for: text),
                        screenWidth: geo.size.width
                    )
                    SpeechBubbleView(text: text, tailOffset: placed.tail)
                    .position(
                        x: placed.x,
                        y: max(28, brain.position.y - size.height * 0.5 - 30)
                    )
                    .transition(.scale.combined(with: .opacity))
                }

                if model.showPet {
                    CharacterView(
                        companion: model.prefs.companion,
                        pose: brain.pose,
                        facing: model.prefs.companion == .qasim && (model.salah.matVisible || model.previewingSalah)
                            ? 1
                            : brain.facing,
                        hopLift: model.salah.matVisible || model.previewingSalah || model.prefs.motionReduced ? 0 : brain.hopLift,
                        breatheScale: model.prefs.motionReduced ? 1 : brain.breatheScale,
                        pressed: model.characterPressed,
                        size: size,
                        lightsOff: model.lightsOff,
                        switchPressed: model.switchPressed,
                        breakActivity: model.activeBreakActivity,
                        reducedMotion: model.prefs.motionReduced,
                        distractionActive: brain.distractionTransitionActive
                    )
                    .position(brain.position)
                    .onTapGesture { model.poke() }
                    .gesture(drag)
                    .contextMenu {
                        Button("Hide for 15 minutes") { model.prefs.hide(for: 15 * 60) }
                        Button("Hide for an hour") { model.prefs.hide(for: 60 * 60) }
                    }
                }
            }
            .coordinateSpace(name: "overlay")
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .onAppear { model.prefs.systemReducedMotion = accessibilityReduceMotion }
        .onChange(of: accessibilityReduceMotion) { _, value in
            model.prefs.systemReducedMotion = value
        }
        .allowsHitTesting(true)
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named("overlay"))
            .onChanged { value in
                model.characterPressed = true
                model.brain.placeManually(at: value.location)
            }
            .onEnded { _ in
                model.characterPressed = false
            }
    }

    /// Centre the bubble on his head, and only slide it inward if it would run
    /// off the screen edge. The tail shifts by the same amount it slid, so it
    /// keeps pointing at him instead of the bubble drifting off to one side.
    private func bubblePlacement(
        headX: CGFloat,
        halfWidth: CGFloat,
        screenWidth: CGFloat
    ) -> (x: CGFloat, tail: CGFloat) {
        let margin: CGFloat = 8
        let lowest = halfWidth + margin
        let highest = max(lowest, screenWidth - halfWidth - margin)
        let x = min(max(headX, lowest), highest)
        // Keep the tail within the bubble's rounded corners.
        let tail = min(max(headX - x, -halfWidth + 22), halfWidth - 22)
        return (x, tail)
    }
}
