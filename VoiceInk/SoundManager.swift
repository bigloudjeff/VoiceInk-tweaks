import Foundation
import AVFoundation
import SwiftUI

@MainActor
class SoundManager: ObservableObject, SoundPlaying {
    static let shared = SoundManager()

    private var startSound: AVAudioPlayer?
    private var stopSound: AVAudioPlayer?
    private var escSound: AVAudioPlayer?
    private var customStartSound: AVAudioPlayer?
    private var customStopSound: AVAudioPlayer?

    @AppStorage(UserDefaults.Keys.isSoundFeedbackEnabled) private var isSoundFeedbackEnabled = true

    private init() {
        Task(priority: .background) {
            await setupSounds()
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(reloadCustomSounds),
            name: .customSoundsChanged,
            object: nil
        )
    }

    func setupSounds() async {
        if let startSoundURL = Bundle.main.url(forResource: "recstart", withExtension: "mp3"),
           let stopSoundURL = Bundle.main.url(forResource: "recstop", withExtension: "mp3"),
           let escSoundURL = Bundle.main.url(forResource: "esc", withExtension: "wav") {
            try? await loadSounds(start: startSoundURL, stop: stopSoundURL, esc: escSoundURL)
        }

        await reloadCustomSoundsAsync()
    }

    @objc private func reloadCustomSounds() {
        Task {
            await reloadCustomSoundsAsync()
        }
    }

    private func loadAndPreparePlayer(from url: URL?) -> AVAudioPlayer? {
        guard let url = url else { return nil }
        let player = try? AVAudioPlayer(contentsOf: url)
        player?.volume = 0.4
        player?.prepareToPlay()
        return player
    }

    private func reloadCustomSoundsAsync() async {
        if customStartSound?.isPlaying == true {
            customStartSound?.stop()
        }
        if customStopSound?.isPlaying == true {
            customStopSound?.stop()
        }

        customStartSound = loadAndPreparePlayer(from: CustomSoundManager.shared.getCustomSoundURL(for: .start))
        customStopSound = loadAndPreparePlayer(from: CustomSoundManager.shared.getCustomSoundURL(for: .stop))
    }

    private func loadSounds(start startURL: URL, stop stopURL: URL, esc escURL: URL) async throws {
        do {
            startSound = try AVAudioPlayer(contentsOf: startURL)
            stopSound = try AVAudioPlayer(contentsOf: stopURL)
            escSound = try AVAudioPlayer(contentsOf: escURL)

            await MainActor.run {
                startSound?.prepareToPlay()
                stopSound?.prepareToPlay()
                escSound?.prepareToPlay()
            }

            startSound?.volume = 0.4
            stopSound?.volume = 0.4
            escSound?.volume = 0.3
        } catch {
            throw error
        }
    }

    func playStartSound() {
        guard isSoundFeedbackEnabled else { return }
        playReliably(customStartSound ?? startSound, volume: 0.4)
    }

    /// Duration of the currently playing start sound, or 0 if not playing.
    var startSoundRemainingDuration: TimeInterval {
        if let custom = customStartSound, custom.isPlaying {
            return max(0, custom.duration - custom.currentTime)
        }
        if let sound = startSound, sound.isPlaying {
            return max(0, sound.duration - sound.currentTime)
        }
        return 0
    }

    func playStopSound() {
        guard isSoundFeedbackEnabled else { return }
        playReliably(customStopSound ?? stopSound, volume: 0.4)
    }

    func playEscSound() {
        guard isSoundFeedbackEnabled else { return }
        playReliably(escSound, volume: 0.3)
    }

    /// Play a sound reliably even during rapid repeated calls.
    /// Resets to the start if already playing, and re-prepares after
    /// playback so the next call has zero latency.
    private func playReliably(_ player: AVAudioPlayer?, volume: Float = 0.4) {
        guard let player else { return }
        if player.isPlaying {
            player.currentTime = 0
        }
        player.volume = volume
        player.play()
        player.prepareToPlay()
    }
    
    var isEnabled: Bool {
        get { isSoundFeedbackEnabled }
        set {
            objectWillChange.send()
            isSoundFeedbackEnabled = newValue
        }
    }
} 
