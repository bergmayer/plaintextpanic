import AVFoundation
import Foundation

class SoundEffects {
    private var audioEngine: AVAudioEngine?
    private var sourceNode: AVAudioSourceNode?
    private var isEnabled: Bool
    private var sampleRate: Double = 44100.0

    // Audio thread state
    private var currentPhase: Double = 0.0
    private var samplesRemaining: Int = 0
    private var currentFrequency: Double = 0.0

    // Multi-tone sequence support (for fanfare)
    private var toneQueue: [(frequency: Double, durationSamples: Int)] = []
    private let toneQueueLock = NSLock()

    private let soundEnabledKey = "PlaintextPanicSoundEnabled"

    init() {
        isEnabled = UserDefaults.standard.object(forKey: soundEnabledKey) == nil
            ? true
            : UserDefaults.standard.bool(forKey: soundEnabledKey)
        setupAudioEngine()
    }

    var soundEnabled: Bool {
        get { isEnabled }
        set {
            isEnabled = newValue
            UserDefaults.standard.set(newValue, forKey: soundEnabledKey)
        }
    }

    private func setupAudioEngine() {
        let engine = AVAudioEngine()
        let outputFormat = engine.outputNode.inputFormat(forBus: 0)
        sampleRate = outputFormat.sampleRate > 0 ? outputFormat.sampleRate : 44100.0

        let node = AVAudioSourceNode(format: outputFormat) { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }

            let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)

            for frame in 0..<Int(frameCount) {
                var sample: Float = 0.0

                if self.samplesRemaining > 0 && self.currentFrequency > 0 {
                    // Generate square wave - the authentic Apple II sound
                    let phaseIncrement = self.currentFrequency / self.sampleRate
                    self.currentPhase += phaseIncrement
                    if self.currentPhase >= 1.0 { self.currentPhase -= 1.0 }

                    sample = self.currentPhase < 0.5 ? 0.15 : -0.15
                    self.samplesRemaining -= 1

                    // Advance to next tone in queue when current finishes
                    if self.samplesRemaining == 0 {
                        self.toneQueueLock.lock()
                        if !self.toneQueue.isEmpty {
                            let next = self.toneQueue.removeFirst()
                            self.currentFrequency = next.frequency
                            self.samplesRemaining = next.durationSamples
                            self.currentPhase = 0.0
                        }
                        self.toneQueueLock.unlock()
                    }
                }

                for buffer in ablPointer {
                    let buf = UnsafeMutableBufferPointer<Float>(buffer)
                    buf[frame] = sample
                }
            }

            return noErr
        }

        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: outputFormat)

        self.audioEngine = engine
        self.sourceNode = node
    }

    private func ensureEngineRunning() {
        guard let engine = audioEngine, !engine.isRunning else { return }
        do {
            try engine.start()
        } catch {
            // Silently fail - game works fine without sound
        }
    }

    private func playTone(frequency: Double, durationMs: Double) {
        guard isEnabled else { return }
        ensureEngineRunning()

        let durationSamples = Int(sampleRate * durationMs / 1000.0)

        // Clear any queued tones
        toneQueueLock.lock()
        toneQueue.removeAll()
        toneQueueLock.unlock()

        // Set new tone - order matters for thread safety:
        // zero out remaining first, then set frequency/phase, then set remaining
        samplesRemaining = 0
        currentFrequency = frequency
        currentPhase = 0.0
        samplesRemaining = durationSamples
    }

    // MARK: - Sound Effects

    /// Short beep for valid word found
    func playValidWord() {
        playTone(frequency: 800, durationMs: 150)
    }

    /// Low buzz for invalid word / error
    func playInvalidBuzz() {
        playTone(frequency: 200, durationMs: 100)
    }

    /// Subtle tick for keystroke
    func playKeystroke() {
        playTone(frequency: 1200, durationMs: 30)
    }

    /// Countdown beep - 4 flat beeps then a buzzer
    func playCountdown(secondsLeft: Int) {
        switch secondsLeft {
        case 5, 4, 3, 2:
            playTone(frequency: 600, durationMs: 80)
        case 1:
            playBuzzer()
        default: return
        }
    }

    /// Harsh buzzer - rapidly alternates between two low frequencies
    private func playBuzzer() {
        guard isEnabled else { return }
        ensureEngineRunning()

        // Alternate between 150Hz and 250Hz in short bursts for a jagged buzzer
        let tones: [(Double, Double)] = [
            (150, 35), (250, 35),
            (150, 35), (250, 35),
            (150, 35), (250, 35),
            (150, 35), (250, 35),
        ]

        toneQueueLock.lock()
        toneQueue.removeAll()
        for i in 1..<tones.count {
            toneQueue.append((
                frequency: tones[i].0,
                durationSamples: Int(sampleRate * tones[i].1 / 1000.0)
            ))
        }
        toneQueueLock.unlock()

        samplesRemaining = 0
        currentFrequency = tones[0].0
        currentPhase = 0.0
        samplesRemaining = Int(sampleRate * tones[0].1 / 1000.0)
    }

    /// Ascending fanfare for BINGO (C4-E4-G4-C5)
    func playBingoFanfare() {
        guard isEnabled else { return }
        ensureEngineRunning()

        let tones: [(Double, Double)] = [
            (261.63, 150),  // C4
            (329.63, 150),  // E4
            (392.00, 150),  // G4
            (523.25, 300),  // C5 (longer final note)
        ]

        // Queue all tones after the first
        toneQueueLock.lock()
        toneQueue.removeAll()
        for i in 1..<tones.count {
            toneQueue.append((
                frequency: tones[i].0,
                durationSamples: Int(sampleRate * tones[i].1 / 1000.0)
            ))
        }
        toneQueueLock.unlock()

        // Start the first tone
        samplesRemaining = 0
        currentFrequency = tones[0].0
        currentPhase = 0.0
        samplesRemaining = Int(sampleRate * tones[0].1 / 1000.0)
    }
}
