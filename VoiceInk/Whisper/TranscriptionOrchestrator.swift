import Foundation
import SwiftUI
import AVFoundation
import SwiftData
import AppKit
import os

// MARK: - Delegate Protocol

@MainActor
protocol TranscriptionOrchestratorDelegate: AnyObject {
 var recordingState: RecordingState { get set }
 var shouldCancelRecording: Bool { get set }
 var currentTranscriptionModel: (any TranscriptionModel)? { get }
 var currentSession: TranscriptionSession? { get set }
 var enhancementTask: Task<(String, TimeInterval, String?), Error>? { get set }
 func dismissMiniRecorder() async
 func scheduleModelCleanup()
}

// MARK: - TranscriptionOrchestrator

@MainActor
class TranscriptionOrchestrator {
 private let modelContext: ModelContext
 private let recorder: Recorder
 private let serviceRegistry: TranscriptionServiceRegistry
 private let enhancementService: AIEnhancementService?
 private let promptDetectionService: PromptDetectionService
 private let licenseViewModel: LicenseViewModel
 private let logger: Logger

 weak var delegate: TranscriptionOrchestratorDelegate?

 init(
  modelContext: ModelContext,
  recorder: Recorder,
  serviceRegistry: TranscriptionServiceRegistry,
  enhancementService: AIEnhancementService?,
  promptDetectionService: PromptDetectionService,
  licenseViewModel: LicenseViewModel,
  logger: Logger
 ) {
  self.modelContext = modelContext
  self.recorder = recorder
  self.serviceRegistry = serviceRegistry
  self.enhancementService = enhancementService
  self.promptDetectionService = promptDetectionService
  self.licenseViewModel = licenseViewModel
  self.logger = logger
 }

 func transcribeAudio(on transcription: Transcription) async {
  guard let delegate = delegate else { return }

  guard let urlString = transcription.audioFileURL, let url = URL(string: urlString) else {
   logger.error(" Invalid audio file URL in transcription object.")
   delegate.recordingState = .idle
   transcription.text = "Transcription Failed: Invalid audio file URL"
   transcription.transcriptionStatus = TranscriptionStatus.failed.rawValue
   modelContext.safeSave(context: "transcription failure status", logger: logger)
   return
  }

  if delegate.shouldCancelRecording {
   delegate.recordingState = .idle
   delegate.scheduleModelCleanup()
   return
  }

  delegate.recordingState = .transcribing

  // Play stop sound when transcription starts with a small delay
  Task {
   let isSystemMuteEnabled = UserDefaults.standard.bool(forKey: UserDefaults.Keys.isSystemMuteEnabled)
   if isSystemMuteEnabled {
    try? await Task.sleep(for: .milliseconds(200))
   }
   await MainActor.run {
    SoundManager.shared.playStopSound()
   }
  }

  defer {
   if delegate.shouldCancelRecording {
    Task {
     await delegate.scheduleModelCleanup()
    }
   }
  }

  logger.notice(" Starting transcription...")

  var finalPastedText: String?
  var promptDetectionResult: PromptDetectionService.PromptDetectionResult?

  do {
   guard let model = delegate.currentTranscriptionModel else {
    throw WhisperStateError.transcriptionFailed
   }

   let transcriptionStart = Date()
   var text: String
   if let session = delegate.currentSession {
    text = try await session.transcribe(audioURL: url)
    delegate.currentSession = nil
   } else {
    text = try await serviceRegistry.transcribe(audioURL: url, model: model)
   }
   logger.notice(" Transcript: \(text, privacy: .private)")
   text = TranscriptionOutputFilter.filter(text)
   logger.notice(" Output filter result: \(text, privacy: .private)")
   let transcriptionDuration = Date().timeIntervalSince(transcriptionStart)

   let powerModeManager = PowerModeManager.shared
   let activePowerModeConfig = powerModeManager.currentActiveConfiguration
   let powerModeName = (activePowerModeConfig?.isEnabled == true) ? activePowerModeConfig?.name : nil
   let powerModeEmoji = (activePowerModeConfig?.isEnabled == true) ? activePowerModeConfig?.emoji : nil

   if await checkCancellationAndCleanup() { return }

   text = text.trimmingCharacters(in: .whitespacesAndNewlines)

   if UserDefaults.standard.bool(forKey: UserDefaults.Keys.isTextFormattingEnabled) {
    text = WhisperTextFormatter.format(text)
    logger.notice(" Formatted transcript: \(text, privacy: .private)")
   }

   text = WordReplacementService.shared.applyReplacements(to: text, using: modelContext)
   logger.notice(" WordReplacement: \(text, privacy: .private)")

   let audioAsset = AVURLAsset(url: url)
   let actualDuration = (try? CMTimeGetSeconds(await audioAsset.load(.duration))) ?? 0.0

   transcription.text = text
   transcription.duration = actualDuration
   transcription.transcriptionModelName = model.displayName
   transcription.transcriptionDuration = transcriptionDuration
   transcription.powerModeName = powerModeName
   transcription.powerModeEmoji = powerModeEmoji

   // Capture the target app that was frontmost when recording started
   if let frontApp = ActiveWindowService.shared.currentApplication {
    transcription.targetAppName = frontApp.localizedName
    transcription.targetAppBundleId = frontApp.bundleIdentifier
   }

   // Capture the STT prompt that was sent to the transcription model
   let basePrompt = UserDefaults.standard.string(forKey: UserDefaults.Keys.transcriptionPrompt) ?? ""
   let vocabString = CustomVocabularyService.shared.getTranscriptionVocabulary(from: modelContext)
   let fullSttPrompt = vocabString.isEmpty ? basePrompt : basePrompt + " " + vocabString
   if !fullSttPrompt.isEmpty {
    transcription.sttPrompt = fullSttPrompt
   }
   finalPastedText = text

   if let enhancementService = enhancementService, enhancementService.isConfigured {
    let detectionResult = await promptDetectionService.analyzeText(text, with: enhancementService)
    promptDetectionResult = detectionResult
    await promptDetectionService.applyDetectionResult(detectionResult, to: enhancementService)
   }

   if let enhancementService = enhancementService,
      enhancementService.isConfigured {
    let textForAI = promptDetectionResult?.processedText ?? text
    let formattedUserMessage = "\n<TRANSCRIPT>\n\(textForAI)\n</TRANSCRIPT>"

    // Determine effective mode: prompt detection forces synchronous enhancement
    let effectiveMode: EnhancementMode = if promptDetectionResult?.shouldEnableAI == true {
     .on
    } else {
     enhancementService.effectiveEnhancementMode
    }

    switch effectiveMode {
    case .on:
     if await checkCancellationAndCleanup() { return }

     delegate.recordingState = .enhancing

     do {
      let task = Task {
       try await enhancementService.enhance(textForAI)
      }
      delegate.enhancementTask = task
      let (enhancedText, enhancementDuration, promptName) = try await task.value
      delegate.enhancementTask = nil
      logger.notice(" AI enhancement: \(enhancedText, privacy: .private)")
      transcription.enhancedText = enhancedText
      transcription.aiEnhancementModelName = enhancementService.getAIService()?.currentModel
      transcription.promptName = promptName
      transcription.enhancementDuration = enhancementDuration
      transcription.enhancementSource = "synchronous"
      transcription.aiRequestSystemMessage = enhancementService.lastSystemMessageSent
      transcription.aiRequestUserMessage = enhancementService.lastUserMessageSent
      finalPastedText = enhancedText
     } catch is CancellationError {
      delegate.enhancementTask = nil
      transcription.enhancedText = nil
      if await checkCancellationAndCleanup() { return }
     } catch {
      delegate.enhancementTask = nil
      transcription.enhancedText = "Enhancement failed: \(error)"

      if await checkCancellationAndCleanup() { return }
     }

    case .background:
     // Snapshot system message before contexts are cleared by dismissMiniRecorder
     let systemMessage = await enhancementService.buildSystemMessageSnapshot()
     let job = BackgroundEnhancementJob(
      transcriptionId: transcription.id,
      text: textForAI,
      systemMessage: systemMessage,
      userMessage: formattedUserMessage,
      promptName: enhancementService.activePrompt?.title,
      aiModelName: enhancementService.getAIService()?.currentModel
     )
     EnhancementQueueService.shared.enqueue(job)
     // finalPastedText stays as raw text; pipeline proceeds immediately

    case .off:
     break
    }
   }

   transcription.transcriptionStatus = TranscriptionStatus.completed.rawValue

  } catch is CancellationError {
   logger.notice("Transcription cancelled, cleaning up silently")
   modelContext.delete(transcription)
   modelContext.safeSave(context: "cancellation cleanup", logger: logger)
   recorder.restoreAudio()
   await delegate.dismissMiniRecorder()
   delegate.scheduleModelCleanup()
   return
  } catch {
   let errorDescription = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
   let recoverySuggestion = (error as? LocalizedError)?.recoverySuggestion ?? ""
   let fullErrorText = recoverySuggestion.isEmpty ? errorDescription : "\(errorDescription) \(recoverySuggestion)"

   transcription.text = "Transcription Failed: \(fullErrorText)"
   transcription.transcriptionStatus = TranscriptionStatus.failed.rawValue
  }

  modelContext.safeSave(context: "completed transcription", logger: logger)

  NotificationCenter.default.post(name: .transcriptionCompleted, object: transcription)

  if await checkCancellationAndCleanup() { return }

  if var textToPaste = finalPastedText, transcription.transcriptionStatus == TranscriptionStatus.completed.rawValue,
     !textToPaste.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
   if case .trialExpired = licenseViewModel.licenseState {
    textToPaste = """
    Your trial has expired. Upgrade to VoiceInk Pro at tryvoiceink.com/buy
    \n\(textToPaste)
    """
   }

   let warnEnabled = UserDefaults.standard.bool(forKey: UserDefaults.Keys.warnNoTextField)
   let hasEditableField = EditableTextFieldChecker.isEditableTextFieldFocused()

   if warnEnabled && !hasEditableField {
    // Copy to clipboard but skip paste
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    pasteboard.setString(textToPaste + (CursorPaster.appendTrailingSpace ? " " : ""), forType: .string)
    NotificationManager.shared.showNotification(
     title: "No text field detected -- use Paste Last Transcription to paste",
     type: .warning,
     duration: 3.0
    )
    recorder.restoreAudio()
   } else {
    Task { @MainActor in
     try? await Task.sleep(for: .milliseconds(50))
     CursorPaster.pasteAtCursor(textToPaste + (CursorPaster.appendTrailingSpace ? " " : ""))

     let powerMode = PowerModeManager.shared
     if let activeConfig = powerMode.currentActiveConfiguration, activeConfig.isAutoSendEnabled {
      try? await Task.sleep(for: .milliseconds(200))
      CursorPaster.pressEnter()
     }
    }

    let audioRestoreDelay: UInt64
    if let activeConfig = PowerModeManager.shared.currentActiveConfiguration, activeConfig.isAutoSendEnabled {
     audioRestoreDelay = 350
    } else {
     audioRestoreDelay = 150
    }
    Task { @MainActor [weak self] in
     try? await Task.sleep(for: .milliseconds(audioRestoreDelay))
     self?.recorder.restoreAudio()
    }
   }
  } else {
   // No text to paste -- restore audio immediately
   recorder.restoreAudio()
  }

  if let result = promptDetectionResult,
     let enhancementService = enhancementService,
     result.shouldEnableAI {
   await promptDetectionService.restoreOriginalSettings(result, to: enhancementService)
  }

  await delegate.dismissMiniRecorder()

  delegate.shouldCancelRecording = false
 }

 private func checkCancellationAndCleanup() async -> Bool {
  guard let delegate = delegate else { return true }
  if delegate.shouldCancelRecording {
   recorder.restoreAudio()
   delegate.scheduleModelCleanup()
   return true
  }
  return false
 }
}
