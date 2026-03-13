import Foundation
import SwiftUI
import os

// MARK: - Delegate Protocol

@MainActor
protocol RecorderUICoordinatorDelegate: AnyObject {
 var recordingState: RecordingState { get set }
 var shouldCancelRecording: Bool { get set }
 var isMiniRecorderVisible: Bool { get set }
 var recorderType: String { get }
 var selectedScreen: NSScreen? { get }
 var currentSession: TranscriptionSession? { get set }
 var enhancementTask: Task<(String, TimeInterval, String?), Error>? { get set }
 var activeTranscriptionTask: Task<Void, Never>? { get set }
 var miniRecorderError: String? { get set }
 var enhancementService: AIEnhancementService? { get }
 var recorder: Recorder { get }
 var logger: Logger { get }
 func toggleRecord(powerModeId: UUID?) async
 func scheduleModelCleanup()
 func cleanupModelResources() async
 func showRecorderPanel()
 func hideRecorderPanel()
}

// MARK: - RecorderUICoordinator

@MainActor
class RecorderUICoordinator: NSObject {
 var miniWindowManager: MiniWindowManager?
 var notchWindowManager: NotchWindowManager?

 weak var delegate: RecorderUICoordinatorDelegate?

 func showRecorderPanel() {
  guard let delegate = delegate else { return }
  guard let whisperState = delegate as? WhisperState else {
   delegate.logger.error("RecorderUICoordinator: delegate is not WhisperState, cannot show recorder panel")
   return
  }
  let screen = delegate.selectedScreen
  delegate.logger.notice(" Showing \(delegate.recorderType, privacy: .public) recorder")
  if delegate.recorderType == RecorderStyle.notch.rawValue {
   if notchWindowManager == nil {
    notchWindowManager = NotchWindowManager(whisperState: whisperState, recorder: delegate.recorder)
   }
   notchWindowManager?.show(on: screen)
  } else {
   if miniWindowManager == nil {
    miniWindowManager = MiniWindowManager(whisperState: whisperState, recorder: delegate.recorder)
   }
   miniWindowManager?.show(on: screen)
  }
 }

 func hideRecorderPanel() {
  guard let delegate = delegate else { return }
  if delegate.recorderType == RecorderStyle.notch.rawValue {
   notchWindowManager?.hide()
  } else {
   miniWindowManager?.hide()
  }
 }

 func toggleMiniRecorder(powerModeId: UUID? = nil) async {
  guard let delegate = delegate else { return }
  delegate.logger.notice("toggleMiniRecorder called – visible=\(delegate.isMiniRecorderVisible, privacy: .public), state=\(String(describing: delegate.recordingState), privacy: .public)")
  if delegate.isMiniRecorderVisible {
   if delegate.recordingState == .recording {
    delegate.logger.notice("toggleMiniRecorder: stopping recording (was recording)")
    await delegate.toggleRecord(powerModeId: powerModeId)
   } else {
    delegate.logger.notice("toggleMiniRecorder: cancelling (was not recording)")
    await cancelRecording()
   }
  } else {
   // Show the panel immediately -- bypass the didSet's DispatchQueue.main.async
   // to eliminate one run loop cycle of latency
   delegate.isMiniRecorderVisible = true
   showRecorderPanel()

   SoundManager.shared.playStartSound()

   await delegate.toggleRecord(powerModeId: powerModeId)
  }
 }

 func dismissMiniRecorder() async {
  guard let delegate = delegate else { return }
  delegate.logger.notice("dismissMiniRecorder called – state=\(String(describing: delegate.recordingState), privacy: .public)")
  if delegate.recordingState == .busy {
   delegate.logger.notice("dismissMiniRecorder: early return, state is busy")
   return
  }

  let wasRecording = delegate.recordingState == .recording

  delegate.recordingState = .busy

  // Cancel and release any active streaming session to prevent resource leaks.
  delegate.currentSession?.cancel()
  delegate.currentSession = nil

  if wasRecording {
   await delegate.recorder.stopRecording()
  }

  hideRecorderPanel()

  // Clear captured context when the recorder is dismissed
  if let enhancementService = delegate.enhancementService {
   enhancementService.clearCapturedContexts()
  }

  delegate.isMiniRecorderVisible = false

  delegate.scheduleModelCleanup()

  if UserDefaults.standard.bool(forKey: UserDefaults.Keys.powerModeAutoRestoreEnabled) {
   await PowerModeSessionManager.shared.endSession()
   PowerModeManager.shared.setActiveConfiguration(nil)
  }

  delegate.recordingState = .idle
  delegate.logger.notice("dismissMiniRecorder completed")
 }

 func resetOnLaunch() async {
  guard let delegate = delegate else { return }
  delegate.logger.notice(" Resetting recording state on launch")
  await delegate.recorder.stopRecording()
  hideRecorderPanel()
  delegate.isMiniRecorderVisible = false
  delegate.shouldCancelRecording = false
  delegate.miniRecorderError = nil
  delegate.recordingState = .idle
  await delegate.cleanupModelResources()
 }

 func cancelRecording() async {
  guard let delegate = delegate else { return }
  delegate.logger.notice("cancelRecording called")
  SoundManager.shared.playEscSound()
  delegate.shouldCancelRecording = true
  delegate.activeTranscriptionTask?.cancel()
  delegate.activeTranscriptionTask = nil
  delegate.enhancementTask?.cancel()
  delegate.enhancementTask = nil
  await dismissMiniRecorder()
 }

 // MARK: - Notification Handling

 func setupRecorderNotifications() {
  NotificationCenter.default.addObserver(self, selector: #selector(handleToggleMiniRecorder), name: .toggleMiniRecorder, object: nil)
  NotificationCenter.default.addObserver(self, selector: #selector(handleDismissMiniRecorder), name: .dismissMiniRecorder, object: nil)
 }

 @objc public func handleToggleMiniRecorder() {
  guard let delegate = delegate else { return }
  delegate.logger.notice("handleToggleMiniRecorder: .toggleMiniRecorder notification received")
  guard delegate.recordingState == .idle || delegate.recordingState == .recording else {
   delegate.logger.notice("handleToggleMiniRecorder: ignored, state=\(String(describing: delegate.recordingState), privacy: .public)")
   return
  }
  Task {
   await toggleMiniRecorder()
  }
 }

 @objc public func handleDismissMiniRecorder() {
  guard let delegate = delegate else { return }
  delegate.logger.notice("handleDismissMiniRecorder: .dismissMiniRecorder notification received")
  Task {
   await dismissMiniRecorder()
  }
 }
}
