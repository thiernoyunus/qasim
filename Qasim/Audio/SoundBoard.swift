import AVFoundation
import Foundation

@MainActor
final class SoundBoard {
    private var firePlayer: AVAudioPlayer?
    private var sprayPlayer: AVAudioPlayer?
    private var oneshot: AVAudioPlayer?

    func playSwitch() {
        playOnce("light-switch-dragon", fallback: "switch-click")
    }

    func playNotes() {
        playOnce("paper-notes")
    }

    func playScold() {
        playOnce("scold-blip")
    }

    /// The prayer nudge. Louder than the other one-shots because it has to reach
    /// you when you are not looking at the screen.
    func playSalahChime() {
        oneshot = player(named: "salah-chime")
        oneshot?.numberOfLoops = 0
        oneshot?.volume = min(1, volume * 1.3)
        oneshot?.play()
    }

    var volume: Float = 0.7

    func startFire() {
        guard firePlayer?.isPlaying != true else { return }
        firePlayer = player(named: "fire-maxhammarback", fallback: "fire-crackle")
        firePlayer?.numberOfLoops = -1
        firePlayer?.volume = volume * 0.7
        firePlayer?.play()
    }

    func stopFire() {
        firePlayer?.stop()
        firePlayer = nil
    }

    func startSpray() {
        guard sprayPlayer?.isPlaying != true else { return }
        sprayPlayer = player(named: "spray-tiovanlley")
        sprayPlayer?.numberOfLoops = -1
        sprayPlayer?.volume = volume * 0.65
        sprayPlayer?.play()
    }

    func stopSpray() {
        sprayPlayer?.stop()
        sprayPlayer = nil
    }

    func stopAll() {
        stopFire()
        stopSpray()
        oneshot?.stop()
        oneshot = nil
    }

    private func playOnce(_ name: String, fallback: String? = nil) {
        oneshot = player(named: name, fallback: fallback)
        oneshot?.numberOfLoops = 0
        oneshot?.volume = volume
        oneshot?.play()
    }

    private func player(named name: String, fallback: String? = nil) -> AVAudioPlayer? {
        for candidate in [name, fallback].compactMap({ $0 }) {
            for fileExtension in ["wav", "mp3"] {
                guard let url = Bundle.main.url(forResource: candidate, withExtension: fileExtension),
                      let player = try? AVAudioPlayer(contentsOf: url) else { continue }
                player.prepareToPlay()
                return player
            }
        }
        return nil
    }
}
