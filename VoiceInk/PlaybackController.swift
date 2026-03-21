import AppKit
import Combine
import Foundation
import SwiftUI
import MediaRemoteAdapter
@Observable
class PlaybackController {
    static let shared = PlaybackController()
    @ObservationIgnored private var mediaController: MediaRemoteAdapter.MediaController
    @ObservationIgnored private var wasPlayingWhenRecordingStarted = false
    @ObservationIgnored private var isMediaPlaying = false
    @ObservationIgnored private var lastKnownTrackInfo: TrackInfo?
    @ObservationIgnored private var originalMediaAppBundleId: String?
    @ObservationIgnored private var resumeTask: Task<Void, Never>?

    var isPauseMediaEnabled: Bool = UserDefaults.standard.bool(forKey: UserDefaults.Keys.isPauseMediaEnabled) {
        didSet {
            UserDefaults.standard.set(isPauseMediaEnabled, forKey: UserDefaults.Keys.isPauseMediaEnabled)

            if isPauseMediaEnabled {
                startMediaTracking()
            } else {
                stopMediaTracking()
            }
        }
    }

    var mediaResumptionDelay: Double = UserDefaults.standard.double(forKey: UserDefaults.Keys.mediaResumptionDelay) {
        didSet { UserDefaults.standard.set(mediaResumptionDelay, forKey: UserDefaults.Keys.mediaResumptionDelay) }
    }
    
    private init() {
        mediaController = MediaRemoteAdapter.MediaController()

        setupMediaControllerCallbacks()

        if isPauseMediaEnabled {
            startMediaTracking()
        }
    }
    
    private func setupMediaControllerCallbacks() {
        mediaController.onTrackInfoReceived = { [weak self] trackInfo in
            self?.isMediaPlaying = trackInfo.payload.isPlaying ?? false
            self?.lastKnownTrackInfo = trackInfo
        }
        
        mediaController.onListenerTerminated = { }
    }
    
    private func startMediaTracking() {
        mediaController.startListening()
    }
    
    private func stopMediaTracking() {
        mediaController.stopListening()
        isMediaPlaying = false
        lastKnownTrackInfo = nil
        wasPlayingWhenRecordingStarted = false
        originalMediaAppBundleId = nil
    }
    
    func pauseMedia() async {
        resumeTask?.cancel()
        resumeTask = nil

        wasPlayingWhenRecordingStarted = false
        originalMediaAppBundleId = nil

        guard isPauseMediaEnabled,
              isMediaPlaying,
              lastKnownTrackInfo?.payload.isPlaying == true,
              let bundleId = lastKnownTrackInfo?.payload.bundleIdentifier else {
            return
        }

        wasPlayingWhenRecordingStarted = true
        originalMediaAppBundleId = bundleId

        try? await Task.sleep(for: .milliseconds(50))

        mediaController.pause()
    }

    func resumeMedia() async {
        let shouldResume = wasPlayingWhenRecordingStarted
        let originalBundleId = originalMediaAppBundleId
        let delay = mediaResumptionDelay

        defer {
            wasPlayingWhenRecordingStarted = false
            originalMediaAppBundleId = nil
        }

        guard isPauseMediaEnabled,
              shouldResume,
              let bundleId = originalBundleId else {
            return
        }

        guard isAppStillRunning(bundleId: bundleId) else {
            return
        }

        guard let currentTrackInfo = lastKnownTrackInfo,
              let currentBundleId = currentTrackInfo.payload.bundleIdentifier,
              currentBundleId == bundleId,
              currentTrackInfo.payload.isPlaying == false else {
            return
        }

        let task = Task {
            try? await Task.sleep(for: .seconds(delay))

            if Task.isCancelled {
                return
            }

            Self.sendMediaPlayPauseKey()
        }

        resumeTask = task
        await task.value
    }

    /// Simulate the hardware media Play/Pause key (NX_KEYTYPE_PLAY = 16).
    /// Some apps (e.g. Plexamp) ignore the MediaRemote `play` command but
    /// respond to the same HID key event the physical F8 key produces.
    private static func sendMediaPlayPauseKey() {
        func post(down: Bool) {
            let flags: UInt = down ? 0xa00 : 0xb00
            let data1 = Int((16 << 16) | ((down ? 0xa : 0xb) << 8))
            let event = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: NSEvent.ModifierFlags(rawValue: flags),
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: data1,
                data2: -1
            )
            event?.cgEvent?.post(tap: .cghidEventTap)
        }
        post(down: true)
        post(down: false)
    }

    private func isAppStillRunning(bundleId: String) -> Bool {
        let runningApps = NSWorkspace.shared.runningApplications
        return runningApps.contains { $0.bundleIdentifier == bundleId }
    }
}


