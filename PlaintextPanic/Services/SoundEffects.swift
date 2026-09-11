import AVFoundation
import Foundation

/// Prepare complete sounds on the main actor; AVAudioPlayerNode owns rendering.
/// No application state, locks, or allocations run in an audio render callback.
@MainActor
class SoundEffects {
    private var audioEngine: AVAudioEngine?
    private var player: AVAudioPlayerNode?
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
    private let defaults: UserDefaults
    private let soundEnabledKey = "PlaintextPanicSoundEnabled"

    var soundEnabled: Bool {
        didSet {
            defaults.set(soundEnabled, forKey: soundEnabledKey)
            if !soundEnabled {
                player?.stop()
                audioEngine?.pause()
            }
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        soundEnabled = defaults.object(forKey: soundEnabledKey) == nil
            ? true : defaults.bool(forKey: soundEnabledKey)
    }

    // Each new effect replaces the previous one, as in the original game.
    private func play(_ tones: [(frequency: Double, milliseconds: Double)]) {
        guard soundEnabled else { return }
        if audioEngine == nil {
            let engine = AVAudioEngine()
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: format)
            audioEngine = engine
            player = node
        }
        guard let engine = audioEngine, let player else { return }
        let counts = tones.map { Int(format.sampleRate * $0.milliseconds / 1000) }
        let frameCount = counts.reduce(0, +)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frameCount)),
              let samples = buffer.floatChannelData?[0] else { return }
        buffer.frameLength = AVAudioFrameCount(frameCount)
        var offset = 0
        for (tone, count) in zip(tones, counts) {
            var phase = 0.0
            for _ in 0..<count {
                phase += tone.frequency / format.sampleRate
                if phase >= 1 { phase -= 1 }
                samples[offset] = phase < 0.5 ? 0.15 : -0.15
                offset += 1
            }
        }
        do {
            if !engine.isRunning { try engine.start() }
            player.stop()
            player.scheduleBuffer(buffer)
            player.play()
        } catch {
            // Sound is optional; allow a later keypress to retry the engine.
        }
    }

    func playValidWord() { play([(800, 150)]) }
    func playInvalidBuzz() { play([(200, 100)]) }
    func playKeystroke() { play([(1200, 30)]) }

    func playCountdown(secondsLeft: Int) {
        switch secondsLeft {
        case 2...5: play([(600, 80)])
        case 1: play([(150, 35), (250, 35), (150, 35), (250, 35),
                      (150, 35), (250, 35), (150, 35), (250, 35)])
        default: break
        }
    }

    func playBingoFanfare() {
        play([(261.63, 150), (329.63, 150), (392, 150), (523.25, 300)])
    }
}
