import AVFoundation
import SwiftUI

/// The sound played when a rest timer finishes. Stored in `@AppStorage(RestTimerSound.storageKey)`.
enum RestTimerSound: String, CaseIterable, Identifiable {
    case boxingBell
    case readySetGo
    case raceStart
    case none

    static let storageKey = "restTimerSound"

    var id: Self { self }

    var label: String {
        switch self {
        case .boxingBell: return "Boxing Bell"
        case .readySetGo: return "On Your Mark, Get Set, Go"
        case .raceStart: return "Race Start"
        case .none: return "None"
        }
    }

    static var selected: RestTimerSound {
        RestTimerSound(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .boxingBell
    }
}

/// Plays rest timer sounds. Bell and race-start tones are synthesized, so no audio assets are needed.
@MainActor
final class RestTimerSoundPlayer {
    static let shared = RestTimerSoundPlayer()

    private var player: AVAudioPlayer?
    private var keepAlivePlayer: AVAudioPlayer?
    private let synthesizer = AVSpeechSynthesizer()
    private static let sampleRate = 44100.0

    func playSelected() {
        play(RestTimerSound.selected)
    }

    /// Starts a silent audio loop for the length of a rest. With the `audio` background mode this keeps
    /// the app running while the phone is locked or the app is backgrounded, so the rest timer can
    /// still fire and play its sound.
    func beginKeepAlive() {
        guard keepAlivePlayer?.isPlaying != true else { return }
        activateSession()
        keepAlivePlayer = try? AVAudioPlayer(data: Self.wavData(from: [Float](repeating: 0, count: Int(Self.sampleRate))))
        keepAlivePlayer?.numberOfLoops = -1
        keepAlivePlayer?.prepareToPlay()
        keepAlivePlayer?.play()
    }

    /// Stops the silent loop and releases the audio session unless the end-of-rest sound is still playing.
    func endKeepAlive() {
        keepAlivePlayer?.stop()
        keepAlivePlayer = nil
        deactivateSessionWhenIdle()
    }

    private func activateSession() {
        // Playback is required to keep running in the background; mixing leaves the user's music playing.
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private func deactivateSessionWhenIdle() {
        guard keepAlivePlayer == nil, player?.isPlaying != true, !synthesizer.isSpeaking else { return }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func play(_ sound: RestTimerSound) {
        player?.stop()
        synthesizer.stopSpeaking(at: .immediate)
        activateSession()

        // Release the session once the sound has finished, unless another rest has started.
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            self?.deactivateSessionWhenIdle()
        }

        switch sound {
        case .none:
            return
        case .readySetGo:
            let utterance = AVSpeechUtterance(string: "On your mark. Get set. Go!")
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
            synthesizer.speak(utterance)
        case .boxingBell:
            playSamples(Self.bellSamples())
        case .raceStart:
            playSamples(Self.raceStartSamples())
        }
    }

    private func playSamples(_ samples: [Float]) {
        player = try? AVAudioPlayer(data: Self.wavData(from: samples))
        player?.prepareToPlay()
        player?.play()
    }

    // MARK: - Synthesis

    /// Three quick strikes of an inharmonic, exponentially decaying bell.
    private static func bellSamples() -> [Float] {
        var buffer = [Float](repeating: 0, count: Int(sampleRate * 2.6))
        for strike in 0..<3 {
            let start = Int(Double(strike) * 0.32 * sampleRate)
            let partials: [(ratio: Double, gain: Double)] = [(1, 1), (2.76, 0.6), (5.4, 0.35), (8.93, 0.2)]
            let length = Int(sampleRate * 1.8)
            for i in 0..<length where start + i < buffer.count {
                let t = Double(i) / sampleRate
                var value = 0.0
                for (index, partial) in partials.enumerated() {
                    value += partial.gain * sin(2 * .pi * 880 * partial.ratio * t) * exp(-t * (3.0 + Double(index) * 2.5))
                }
                let attack = min(1, t / 0.002)
                buffer[start + i] += Float(value * attack * 0.28)
            }
        }
        return buffer
    }

    /// Three low beeps followed by a long, higher "go" tone.
    private static func raceStartSamples() -> [Float] {
        var buffer = [Float](repeating: 0, count: Int(sampleRate * 2.2))
        func beep(at seconds: Double, length: Double, frequency: Double) {
            let start = Int(seconds * sampleRate)
            let count = Int(length * sampleRate)
            for i in 0..<count where start + i < buffer.count {
                let t = Double(i) / sampleRate
                let envelope = min(1, t / 0.01) * min(1, (length - t) / 0.03)
                let wave = sin(2 * .pi * frequency * t) + 0.3 * sin(2 * .pi * frequency * 2 * t)
                buffer[start + i] += Float(wave * envelope * 0.3)
            }
        }
        beep(at: 0.0, length: 0.25, frequency: 440)
        beep(at: 0.5, length: 0.25, frequency: 440)
        beep(at: 1.0, length: 0.25, frequency: 440)
        beep(at: 1.5, length: 0.7, frequency: 880)
        return buffer
    }

    /// Wraps mono float samples as 16-bit PCM WAV data.
    private static func wavData(from samples: [Float]) -> Data {
        var data = Data()
        func append<T: FixedWidthInteger>(_ value: T) {
            withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
        }
        let byteCount = samples.count * 2
        data.append(contentsOf: Array("RIFF".utf8)); append(UInt32(36 + byteCount))
        data.append(contentsOf: Array("WAVEfmt ".utf8)); append(UInt32(16))
        append(UInt16(1)); append(UInt16(1))
        append(UInt32(sampleRate)); append(UInt32(sampleRate) * 2)
        append(UInt16(2)); append(UInt16(16))
        data.append(contentsOf: Array("data".utf8)); append(UInt32(byteCount))
        for sample in samples {
            append(Int16(max(-1, min(1, sample)) * Float(Int16.max)))
        }
        return data
    }
}
