import Foundation
import CoreAudio

@Observable
final class MediaController {

    static let shared = MediaController()

    @ObservationIgnored private var didMuteAudio = false
    @ObservationIgnored private var wasAudioMutedBeforeRecording = false
    @ObservationIgnored private var unmuteTask: Task<Void, Never>?
    @ObservationIgnored private var muteGeneration: Int = 0

    var isSystemMuteEnabled: Bool = UserDefaults.standard.bool(forKey: UserDefaults.Keys.isSystemMuteEnabled) {
        didSet { UserDefaults.standard.set(isSystemMuteEnabled, forKey: UserDefaults.Keys.isSystemMuteEnabled) }
    }

    var audioResumptionDelay: Double = UserDefaults.standard.double(forKey: UserDefaults.Keys.audioResumptionDelay) {
        didSet { UserDefaults.standard.set(audioResumptionDelay, forKey: UserDefaults.Keys.audioResumptionDelay) }
    }

    private init() {}

    func muteSystemAudio() async -> Bool {
        guard isSystemMuteEnabled else { return false }

        unmuteTask?.cancel()
        unmuteTask = nil
        muteGeneration += 1

        let currentlyMuted = isSystemAudioMuted()

        if currentlyMuted {
            if didMuteAudio {
                // We muted it previously, stay responsible for unmuting
                wasAudioMutedBeforeRecording = false
            } else {
                // User muted it, don't unmute when done
                wasAudioMutedBeforeRecording = true
                didMuteAudio = false
            }
            return true
        }

        wasAudioMutedBeforeRecording = false
        let success = setSystemMuted(true)
        didMuteAudio = success
        return success
    }

    func unmuteSystemAudio() async {
        guard isSystemMuteEnabled else { return }

        let delay = audioResumptionDelay
        let shouldUnmute = didMuteAudio && !wasAudioMutedBeforeRecording
        let myGeneration = muteGeneration

        let task = Task { [weak self] in
            if delay > 0 {
                try? await Task.sleep(for: .seconds(delay))
            }

            guard let self = self else { return }
            guard !Task.isCancelled else { return }
            guard self.muteGeneration == myGeneration else { return }

            if shouldUnmute {
                _ = self.setSystemMuted(false)
            }

            self.didMuteAudio = false
        }

        unmuteTask = task
        await task.value
    }

    /// Unconditionally unmute if we were responsible for muting.
    /// Bypasses generation checks and delay -- used by stopRecording to guarantee
    /// audio is restored even during rapid push-to-talk cycles.
    func forceUnmuteIfResponsible() async {
        unmuteTask?.cancel()
        unmuteTask = nil

        if didMuteAudio && !wasAudioMutedBeforeRecording {
            _ = setSystemMuted(false)
        }

        didMuteAudio = false
    }

    private func getDefaultOutputDevice() -> AudioDeviceID? {
        var deviceID = AudioDeviceID(0)
        var propertySize = UInt32(MemoryLayout<AudioDeviceID>.size)

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &propertySize,
            &deviceID
        )

        return status == noErr ? deviceID : nil
    }

    private func isSystemAudioMuted() -> Bool {
        guard let deviceID = getDefaultOutputDevice() else { return false }

        var muted: UInt32 = 0
        var propertySize = UInt32(MemoryLayout<UInt32>.size)

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        if !AudioObjectHasProperty(deviceID, &address) {
            address.mElement = 0
            if !AudioObjectHasProperty(deviceID, &address) { return false }
        }

        let status = AudioObjectGetPropertyData(deviceID, &address, 0, nil, &propertySize, &muted)
        return status == noErr && muted != 0
    }

    private func setSystemMuted(_ muted: Bool) -> Bool {
        guard let deviceID = getDefaultOutputDevice() else { return false }

        var muteValue: UInt32 = muted ? 1 : 0
        let propertySize = UInt32(MemoryLayout<UInt32>.size)

        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )

        if !AudioObjectHasProperty(deviceID, &address) {
            address.mElement = 0
            if !AudioObjectHasProperty(deviceID, &address) { return false }
        }

        var isSettable: DarwinBoolean = false
        var status = AudioObjectIsPropertySettable(deviceID, &address, &isSettable)
        if status != noErr || !isSettable.boolValue { return false }

        status = AudioObjectSetPropertyData(deviceID, &address, 0, nil, propertySize, &muteValue)
        return status == noErr
    }
}
