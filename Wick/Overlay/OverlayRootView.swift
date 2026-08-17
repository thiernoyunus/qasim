import SwiftUI

struct OverlayRootView: View {
    @Bindable var model: AppModel
    var screenFrame: CGRect
    @State private var timerDragOrigin: CGPoint?

    var body: some View {
        GeometryReader { geo in
            let brain = model.brain
            let size = brain.size(for: model.prefs)
            ZStack(alignment: .topLeading) {
                LightSwitchStage(
                    isOff: model.lightsOff,
                    flashWhite: model.flashWhite
                )

                if model.theater == .fire || model.session.escalation == .fire {
                    FireField(rect: model.fireRectSwiftUI, time: model.now, intensity: model.effectIntensity)
                }

                if model.theater == .notes || notesShowing {
                    NoteField(rect: model.fireRectSwiftUI, time: model.now, intensity: model.effectIntensity)
                }

                if model.prefs.showTimerChip, !model.prefs.timerOnTop,
                   model.session.phase == .running || model.session.phase == .paused || model.session.phase == .finished {
                    model.timerChip(
                        onDragChanged: { translation in
                            let start = timerDragOrigin ?? (model.timerCenter ?? timerCenter(in: geo.size))
                            timerDragOrigin = start
                            model.timerCenter = CGPoint(
                                x: start.x + translation.width,
                                y: start.y + translation.height
                            )
                        },
                        onDragEnded: {
                            timerDragOrigin = nil
                        }
                    )
                    .position(model.timerCenter ?? timerCenter(in: geo.size))
                }

                if (model.salah.matVisible || model.previewingSalah), model.prefs.companion != .qasim {
                    PrayerMatView()
                        .position(x: brain.position.x, y: brain.position.y + size.height * 0.28)
                }

                if model.showPet, let text = brain.bubble {
                    SpeechBubbleView(text: text) {
                        model.brain.bubble = nil
                    }
                    .position(
                        x: min(max(brain.position.x, 132), geo.size.width - 132),
                        y: max(28, brain.position.y - size.height * 0.5 - 36)
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
                        hopLift: model.salah.matVisible || model.previewingSalah || model.prefs.reducedMotion ? 0 : brain.hopLift,
                        breatheScale: model.prefs.reducedMotion ? 1 : brain.breatheScale,
                        pressed: model.characterPressed,
                        size: size,
                        lightsOff: model.lightsOff,
                        switchPressed: model.switchPressed,
                        breakActivity: model.activeBreakActivity
                    )
                    .position(brain.position)
                    .onTapGesture { model.poke() }
                    .gesture(drag)
                    .contextMenu {
                        Button("Hide for 15 minutes") { model.prefs.hide(for: 15 * 60) }
                        Button("Hide for an hour") { model.prefs.hide(for: 60 * 60) }
                        if model.brain.bubble != nil {
                            Button("Dismiss speech") { model.brain.bubble = nil }
                        }
                    }
                }
            }
            .coordinateSpace(name: "overlay")
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .allowsHitTesting(true)
    }

    private var notesShowing: Bool {
        guard model.prefs.allows(.notes, previewing: model.session.previewMove),
              model.session.escalation >= .nudge,
              model.session.phase == .running,
              !model.session.isOnTask else { return false }
        if let previewMove = model.session.previewMove {
            return previewMove == .notes
        }
        return model.session.previewTheater == nil
    }

    private var drag: some Gesture {
        DragGesture(minimumDistance: 4, coordinateSpace: .named("overlay"))
            .onChanged { value in
                model.characterPressed = true
                model.brain.position = value.location
                model.brain.target = value.location
            }
            .onEnded { _ in
                model.characterPressed = false
            }
    }

    private func timerCenter(in size: CGSize) -> CGPoint {
        CGPoint(x: size.width - 96, y: 86)
    }
}
