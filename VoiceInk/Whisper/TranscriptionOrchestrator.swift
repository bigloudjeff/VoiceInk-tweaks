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
 private let powerModeProvider: PowerModeProviding
 private let logger: Logger

 weak var delegate: TranscriptionOrchestratorDelegate?

 init(
  modelContext: ModelContext,
  recorder: Recorder,
  serviceRegistry: TranscriptionServiceRegistry,
  enhancementService: AIEnhancementService?,
  promptDetectionService: PromptDetectionService,
  licenseViewModel: LicenseViewModel,
  powerModeProvider: PowerModeProviding,
  logger: Logger
 ) {
  self.modelContext = modelContext
  self.recorder = recorder
  self.serviceRegistry = serviceRegistry
  self.enhancementService = enhancementService
  self.promptDetectionService = promptDetectionService
  self.licenseViewModel = licenseViewModel
  self.powerModeProvider = powerModeProvider
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
   let postResult = TranscriptionPostProcessor.process(text, modelContext: modelContext)
   text = postResult.text
   logger.notice(" Post-processed: \(text, privacy: .private)")
   let transcriptionDuration = Date().timeIntervalSince(transcriptionStart)

   if await checkCancellationAndCleanup() { return }

   let audioAsset = AVURLAsset(url: url)
   let actualDuration = (try? CMTimeGetSeconds(await audioAsset.load(.duration))) ?? 0.0

   await populateMetadata(
    on: transcription, text: text, postResult: postResult,
    model: model, transcriptionDuration: transcriptionDuration,
    audioDuration: actualDuration, audioURL: url
   )

   finalPastedText = text

   let enhancementResult = await performEnhancement(
    text: text, transcription: transcription, delegate: delegate
   )
   promptDetectionResult = enhancementResult.promptDetectionResult
   if let enhanced = enhancementResult.enhancedText {
    finalPastedText = enhanced
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

  pasteResult(finalPastedText, transcription: transcription)

  if let result = promptDetectionResult,
     let enhancementService = enhancementService,
     result.shouldEnableAI {
   await promptDetectionService.restoreOriginalSettings(result, to: enhancementService)
  }

  await delegate.dismissMiniRecorder()

  delegate.shouldCancelRecording = false
 }

 // MARK: - Metadata Population

 private func populateMetadata(
  on transcription: Transcription,
  text: String,
  postResult: TranscriptionPostProcessor.Result,
  model: any TranscriptionModel,
  transcriptionDuration: TimeInterval,
  audioDuration: Double,
  audioURL: URL
 ) async {
  let activePowerModeConfig = powerModeProvider.currentActiveConfiguration
  let powerModeName = (activePowerModeConfig?.isEnabled == true) ? activePowerModeConfig?.name : nil
  let powerModeEmoji = (activePowerModeConfig?.isEnabled == true) ? activePowerModeConfig?.emoji : nil

  transcription.text = text
  transcription.duration = audioDuration
  transcription.transcriptionModelName = model.displayName
  transcription.transcriptionDuration = transcriptionDuration
  transcription.powerModeName = powerModeName
  transcription.powerModeEmoji = powerModeEmoji

  if let frontApp = ActiveWindowService.shared.currentApplication {
   transcription.targetAppName = frontApp.localizedName
   transcription.targetAppBundleId = frontApp.bundleIdentifier
  }

  let basePrompt = UserDefaults.standard.string(forKey: UserDefaults.Keys.transcriptionPrompt) ?? ""
  let vocabString = CustomVocabularyService.shared.getTranscriptionVocabulary(from: modelContext)
  let fullSttPrompt = vocabString.isEmpty ? basePrompt : basePrompt + " " + vocabString
  if !fullSttPrompt.isEmpty {
   transcription.sttPrompt = fullSttPrompt
  }

  transcription.rawTranscript = postResult.rawTranscript
  transcription.outputFilterApplied = postResult.outputFilterApplied
  let fillerManager = FillerWordManager.shared
  transcription.fillerWordRemovalEnabled = fillerManager.isEnabled
  if fillerManager.isEnabled {
   transcription.fillerWordList = fillerManager.fillerWords.joined(separator: ", ")
  }

  if let pmConfig = activePowerModeConfig, pmConfig.isEnabled {
   transcription.powerModeSystemInstructions = pmConfig.systemInstructions
   transcription.powerModePromptName = pmConfig.selectedPrompt
  }

  if AIPrompts.powerModeOverride != nil {
   transcription.systemInstructionsSource = "power-mode"
  } else if PromptFileManager.hasUserOverride("system-instructions") {
   transcription.systemInstructionsSource = "user-override"
  } else {
   transcription.systemInstructionsSource = "bundle-default"
  }
 }

 // MARK: - Enhancement

 private struct EnhancementResult {
  var enhancedText: String?
  var promptDetectionResult: PromptDetectionService.PromptDetectionResult?
 }

 private func performEnhancement(
  text: String,
  transcription: Transcription,
  delegate: TranscriptionOrchestratorDelegate
 ) async -> EnhancementResult {
  var result = EnhancementResult()

  guard let enhancementService = enhancementService, enhancementService.isConfigured else {
   return result
  }

  let detectionResult = await promptDetectionService.analyzeText(text, with: enhancementService)
  result.promptDetectionResult = detectionResult
  await promptDetectionService.applyDetectionResult(detectionResult, to: enhancementService)

  let textForAI = detectionResult.processedText ?? text
  let formattedUserMessage = "\n<TRANSCRIPT>\n\(textForAI)\n</TRANSCRIPT>"

  let effectiveMode: EnhancementMode = if detectionResult.shouldEnableAI {
   .on
  } else {
   enhancementService.effectiveEnhancementMode
  }

  switch effectiveMode {
  case .on:
   if await checkCancellationAndCleanup() { return result }

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
    transcription.aiRequestSystemMessage = Transcription.redactSensitiveContext(enhancementService.lastSystemMessageSent)
    transcription.aiRequestUserMessage = enhancementService.lastUserMessageSent
    transcription.aiProviderName = enhancementService.getAIService()?.selectedProvider.rawValue
    transcription.promptText = enhancementService.activePrompt?.promptText
    transcription.screenCaptureEnabled = enhancementService.useScreenCaptureContext
    transcription.clipboardContextEnabled = enhancementService.useClipboardContext
    result.enhancedText = enhancedText
   } catch is CancellationError {
    delegate.enhancementTask = nil
    transcription.enhancedText = nil
    _ = await checkCancellationAndCleanup()
   } catch {
    delegate.enhancementTask = nil
    transcription.enhancedText = "Enhancement failed: \(error)"
    _ = await checkCancellationAndCleanup()
   }

  case .background:
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

  case .off:
   break
  }

  return result
 }

 // MARK: - Paste / Output

 private func pasteResult(_ finalPastedText: String?, transcription: Transcription) {
  guard var textToPaste = finalPastedText,
        transcription.transcriptionStatus == TranscriptionStatus.completed.rawValue,
        !textToPaste.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
   recorder.restoreAudio()
   return
  }

  if case .trialExpired = licenseViewModel.licenseState {
   textToPaste = """
   Your trial has expired. Upgrade to VoiceInk Pro at tryvoiceink.com/buy
   \n\(textToPaste)
   """
  }

  let warnEnabled = UserDefaults.standard.bool(forKey: UserDefaults.Keys.warnNoTextField)
  let hasEditableField = EditableTextFieldChecker.isEditableTextFieldFocused()

  if warnEnabled && !hasEditableField {
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

    if let activeConfig = self.powerModeProvider.currentActiveConfiguration, activeConfig.isAutoSendEnabled {
     try? await Task.sleep(for: .milliseconds(200))
     CursorPaster.pressEnter()
    }
   }

   let audioRestoreDelay: UInt64
   if let activeConfig = powerModeProvider.currentActiveConfiguration, activeConfig.isAutoSendEnabled {
    audioRestoreDelay = 350
   } else {
    audioRestoreDelay = 150
   }
   Task { @MainActor [weak self] in
    try? await Task.sleep(for: .milliseconds(audioRestoreDelay))
    self?.recorder.restoreAudio()
   }
  }
 }

 // MARK: - Cancellation

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
