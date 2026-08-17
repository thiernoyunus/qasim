import AVFoundation
import Foundation

@MainActor
final class SoundBoard {
    private var firePlayer: AVAudioPlayer?
    private var oneshot: AVAudioPlayer?

    func playSwitch() {
        playOnce("switch-click")
    }

    func playNotes() {
        playOnce("paper-notes")
    }

    func playScold() {
        playOnce("scold-blip")
    }

    var volume: Float = 0.7

    func startFire() {
        guard firePlayer?.isPlaying != true else { return }
        firePlayer = player(named: "fire-crackle")
        firePlayer?.numberOfLoops = -1
        firePlayer?.volume = volume * 0.7
        firePlayer?.play()
    }

    func stopFire() {
        firePlayer?.stop()
        firePlayer = nil
    }

    func stopAll() {
        stopFire()
        oneshot?.stop()
        oneshot = nil
    }

    private func playOnce(_ name: String) {
        oneshot = player(named: name)
        oneshot?.numberOfLoops = 0
        oneshot?.volume = volume
        oneshot?.play()
    }

    private func player(named name: String) -> AVAudioPlayer? {
        let url = Bundle.main.url(forResource: name, withExtension: "wav")
        guard let url, let player = try? AVAudioPlayer(contentsOf: url) else { return nil }
        player.prepareToPlay()
        return player
    }
}
