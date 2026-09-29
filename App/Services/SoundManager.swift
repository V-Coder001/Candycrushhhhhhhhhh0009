import AVFoundation
import Match3Core

/// Sound effects and combo voice.
///
/// Placeholder sounds are synthesised at runtime, so the game makes noise without any assets.
/// To use real recordings, add files named after an `Effect` (e.g. `pop.caf`, `crunch.wav`) or a
/// combo voice line (`voice_delicious.caf`) to the app target. Bundled files always win.
@MainActor
final class SoundManager {
    static let shared = SoundManager()

    enum Effect: String, CaseIterable {
        case swap, pop, crunch, special, bomb, invalid, collect, win, lose
    }

    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var nextPlayer = 0
    private var buffers: [String: AVAudioPCMBuffer] = [:]
    private var filePlayers: [String: [AVAudioPlayer]] = [:]
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private let speech = AVSpeechSynthesizer()
    private var isConfigured = false

    private var soundOn: Bool { UserDefaults.standard.bool(forKey: SettingsKey.sound) }
    private var voiceOn: Bool { UserDefaults.standard.bool(forKey: SettingsKey.voice) }

    private init() {}

    // MARK: Public

    /// `pitch` > 1 raises the sound; cascades use it so chains climb upwards.
    func play(_ effect: Effect, pitch: Double = 1) {
        guard soundOn else { return }
        if playBundled(effect.rawValue) { return }
        guard prepareEngine() else { return }
        let key = "\(effect.rawValue)-\(Int(pitch * 100))"
        if buffers[key] == nil { buffers[key] = synthesize(effect, pitch: pitch) }
        guard let buffer = buffers[key] else { return }
        let player = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        if !player.isPlaying { player.play() }
    }

    /// Deep voice for combo chains ("Delicious!", "Divine!").
    func say(_ word: ComboWord) {
        guard voiceOn else { return }
        let name = "voice_" + word.rawValue.lowercased().replacingOccurrences(of: "!", with: "")
        if soundOn, playBundled(name) { return }
        let utterance = AVSpeechUtterance(string: word.rawValue.replacingOccurrences(of: "!", with: ""))
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.pitchMultiplier = 0.6
        utterance.rate = 0.42
        utterance.volume = 0.9
        speech.stopSpeaking(at: .immediate)
        speech.speak(utterance)
    }

    // MARK: Engine

    private func prepareEngine() -> Bool {
        if !isConfigured {
            try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
            try? AVAudioSession.sharedInstance().setActive(true)
            for _ in 0..<8 {
                let player = AVAudioPlayerNode()
                engine.attach(player)
                engine.connect(player, to: engine.mainMixerNode, format: format)
                players.append(player)
            }
            engine.mainMixerNode.outputVolume = 0.8
            isConfigured = true
        }
        if !engine.isRunning {
            do { try engine.start() } catch { return false }
        }
        return true
    }

    private func playBundled(_ name: String) -> Bool {
        if filePlayers[name] == nil {
            let url = ["caf", "wav", "m4a", "mp3"].lazy
                .compactMap { Bundle.main.url(forResource: name, withExtension: $0) }.first
            filePlayers[name] = url.map { url in (0..<3).compactMap { _ in try? AVAudioPlayer(contentsOf: url) } } ?? []
        }
        guard let pool = filePlayers[name], !pool.isEmpty else { return false }
        let player = pool.first { !$0.isPlaying } ?? pool[0]
        player.currentTime = 0
        player.play()
        return true
    }

    // MARK: Synthesis (placeholders)

    private func synthesize(_ effect: Effect, pitch: Double) -> AVAudioPCMBuffer? {
        let sampleRate = format.sampleRate
        var phase = 0.0
        var phase2 = 0.0
        var noise = 0.0

        func render(_ duration: Double, _ sample: (Double, Double) -> Double) -> AVAudioPCMBuffer? {
            let frames = AVAudioFrameCount(duration * sampleRate)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
                  let data = buffer.floatChannelData?[0] else { return nil }
            buffer.frameLength = frames
            for i in 0..<Int(frames) {
                let t = Double(i) / sampleRate
                data[i] = Float(max(-1, min(1, sample(t, t / duration))))
            }
            return buffer
        }
        func tone(_ frequency: Double) -> Double {
            phase += 2 * .pi * frequency / sampleRate
            return sin(phase)
        }
        func overtone(_ frequency: Double) -> Double {
            phase2 += 2 * .pi * frequency / sampleRate
            return sin(phase2)
        }
        func softNoise(_ smoothing: Double) -> Double {
            noise = noise * smoothing + Double.random(in: -1...1) * (1 - smoothing)
            return noise
        }
        func envelope(_ x: Double, attack: Double = 0.01, power: Double = 2) -> Double {
            x < attack ? x / attack : pow(1 - (x - attack) / (1 - attack), power)
        }

        switch effect {
        case .swap:
            return render(0.07) { _, x in tone(520 * pitch) * envelope(x, power: 3) * 0.18 }
        case .pop:
            // "Plopp": a bubble whose pitch drops quickly.
            return render(0.12) { _, x in
                tone((760 - 480 * x) * pitch) * envelope(x, attack: 0.03, power: 2.5) * 0.5
            }
        case .crunch:
            return render(0.16) { _, x in
                (softNoise(0.55) * 1.6 + tone(140) * 0.3) * envelope(x, attack: 0.02, power: 2) * 0.55
            }
        case .special:
            return render(0.32) { _, x in
                let f = (480 + 800 * x) * pitch
                return (tone(f) * 0.7 + overtone(f * 2) * 0.2) * envelope(x, attack: 0.05, power: 1.6) * 0.35
            }
        case .bomb:
            return render(0.5) { _, x in
                (tone(90 - 50 * x) * 0.8 + softNoise(0.85) * 2.2) * envelope(x, attack: 0.01, power: 2.2) * 0.6
            }
        case .invalid:
            return render(0.22) { _, x in
                let gate = (x < 0.4 || x > 0.55) ? 1.0 : 0.0
                return tone(196) * gate * envelope(x, power: 1.2) * 0.25
            }
        case .collect:
            return render(0.3) { _, x in
                let f = x < 0.33 ? 660.0 : (x < 0.66 ? 880.0 : 1320.0)
                return tone(f) * envelope(x, attack: 0.02, power: 1.4) * 0.3
            }
        case .win:
            return render(0.7) { _, x in
                let notes = [523.25, 659.25, 783.99, 1046.5]
                let f = notes[min(notes.count - 1, Int(x * 4))]
                return (tone(f) * 0.7 + overtone(f * 2) * 0.15) * envelope(x, attack: 0.02, power: 1.2) * 0.3
            }
        case .lose:
            return render(0.6) { _, x in
                let notes = [392.0, 329.63, 261.63]
                let f = notes[min(notes.count - 1, Int(x * 3))]
                return tone(f) * envelope(x, attack: 0.03, power: 1.1) * 0.25
            }
        }
    }
}
