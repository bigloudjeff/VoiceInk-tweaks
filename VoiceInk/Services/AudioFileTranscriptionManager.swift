import Foundation
import SwiftUI
import AVFoundation
import SwiftData
import os

@MainActor
class AudioTranscriptionManager: ObservableObject {
 static let shared = AudioTranscriptionManager()

 @Published var isProcessing = false
 @Published var processingPhase: ProcessingPhase = .idle
 @Published var currentTranscription: Transcription?
 @Published var errorMessage: String?

 private var currentTask: Task<Void, Error>?
 private let audioProcessor = AudioProcessor()
 private let promptDetectionService = PromptDetectionService()
 private let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "AudioTranscriptionManager")

 enum ProcessingPhase {
  case idle
  case loading
  case processingAudio
  case transcribing
  case enhancing
  case completed

  var message: String {
   switch self {
   case .idle:
    return ""
   case .loading:
    return "Loading transcription model..."
   case .processingAudio:
    return "Processing audio file for transcription..."
   case .transcribing:
    return "Transcribing audio..."
   case .enhancing:
    return "Enhancing transcription with AI..."
   case .completed:
    return "Transcription completed!"
   }
  }
 }

 private init() {}

 // MARK: - Import Audio (Transcribe Audio view)

 func startProcessing(url: URL, modelContext: ModelContext, whisperState: WhisperState) {
  // Cancel any existing processing
  cancelProcessing()

  isProcessing = true
  processingPhase = .loading
  errorMessage = nil

  currentTask = Task {
   do {
    guard let currentModel = whisperState.currentTranscriptionModel else {
     throw TranscriptionError.noModelSelected
    }

    let serviceRegistry = TranscriptionServiceRegistry(contextProvider: whisperState, modelContext: modelContext, modelsDirectory: whisperState.modelsDirectory)
    defer {
     serviceRegistry.cleanup()
    }

    processingPhase = .processingAudio
    let samples = try await audioProcessor.processAudioToSamples(url)

    let audioAsset = AVURLAsset(url: url)
    let duration = CMTimeGetSeconds(try await audioAsset.load(.duration))

    let permanentURL = Self.recordingsURL(prefix: "transcribed")

    try FileManager.default.createDirectory(at: permanentURL.deletingLastPathComponent(), withIntermediateDirectories: true)
    try audioProcessor.saveSamplesAsWav(samples: samples, to: permanentURL)

    processingPhase = .transcribing
    let transcriptionStart = Date()
    var text = try await serviceRegistry.transcribe(audioURL: permanentURL, model: currentModel)
    let transcriptionDuration = Date().timeIntervalSince(transcriptionStart)
    let postResult = TranscriptionPostProcessor.process(text, modelContext: modelContext)
    text = postResult.text

    let transcription = try await Self.createTranscription(
     text: text,
     duration: duration,
     audioFileURL: permanentURL.absoluteString,
     model: currentModel,
     transcriptionDuration: transcriptionDuration,
     enhancementService: whisperState.enhancementService,
     modelContext: modelContext,
     logger: logger
    )
    currentTranscription = transcription

    processingPhase = .completed
    try? await Task.sleep(for: .seconds(1.5))
    await finishProcessing()

   } catch {
    await handleError(error)
   }
  }
 }

 // MARK: - Retranscribe Existing Audio

 func retranscribeAudio(from url: URL, using model: any TranscriptionModel, modelContext: ModelContext, whisperState: WhisperState) async throws -> Transcription {
  guard FileManager.default.fileExists(atPath: url.path) else {
   throw TranscriptionError.noAudioFile
  }

  let serviceRegistry = TranscriptionServiceRegistry(contextProvider: whisperState, modelContext: modelContext, modelsDirectory: whisperState.modelsDirectory)

  let transcriptionStart = Date()
  var text = try await serviceRegistry.transcribe(audioURL: url, model: model)
  let transcriptionDuration = Date().timeIntervalSince(transcriptionStart)
  let postResult = TranscriptionPostProcessor.process(text, modelContext: modelContext)
  text = postResult.text
  logger.notice(" Post-processed transcript")

  let audioAsset = AVURLAsset(url: url)
  let duration = CMTimeGetSeconds(try await audioAsset.load(.duration))

  let permanentURL = Self.recordingsURL(prefix: "retranscribed")

  do {
   try FileManager.default.copyItem(at: url, to: permanentURL)
  } catch {
   logger.error(" Failed to create permanent copy of audio: \(error.localizedDescription, privacy: .public)")
   throw error
  }

  // Apply prompt detection for trigger words
  var promptDetectionResult: PromptDetectionService.PromptDetectionResult? = nil
  let enhancementService = whisperState.enhancementService

  if let enhancementService = enhancementService, enhancementService.isConfigured {
   let detectionResult = await promptDetectionService.analyzeText(text, with: enhancementService)
   promptDetectionResult = detectionResult
   await promptDetectionService.applyDetectionResult(detectionResult, to: enhancementService)
  }

  let textForAI = promptDetectionResult?.processedText ?? text
  let shouldEnhance = promptDetectionResult?.shouldEnableAI == true || (enhancementService?.isEnhancementEnabled == true)
  let effectiveEnhancementService = shouldEnhance ? enhancementService : nil

  let transcription = try await Self.createTranscription(
   text: text,
   duration: duration,
   audioFileURL: permanentURL.absoluteString,
   model: model,
   transcriptionDuration: transcriptionDuration,
   enhancementService: effectiveEnhancementService,
   textForAI: textForAI,
   modelContext: modelContext,
   logger: logger
  )

  // Restore original prompt settings if AI was temporarily enabled
  if let result = promptDetectionResult,
     result.shouldEnableAI,
     let enhancementService = enhancementService {
   await promptDetectionService.restoreOriginalSettings(result, to: enhancementService)
  }

  return transcription
 }

 // MARK: - Shared Transcription Creation

 private static func createTranscription(
  text: String,
  duration: TimeInterval,
  audioFileURL: String,
  model: any TranscriptionModel,
  transcriptionDuration: TimeInterval,
  enhancementService: AIEnhancementService?,
  textForAI: String? = nil,
  modelContext: ModelContext,
  logger: Logger
 ) async throws -> Transcription {
  let powerModeManager = PowerModeManager.shared
  let activePowerModeConfig = powerModeManager.currentActiveConfiguration
  let powerModeName = (activePowerModeConfig?.isEnabled == true) ? activePowerModeConfig?.name : nil
  let powerModeEmoji = (activePowerModeConfig?.isEnabled == true) ? activePowerModeConfig?.emoji : nil

  let transcription: Transcription

  if let enhancementService = enhancementService,
     enhancementService.isEnhancementEnabled,
     enhancementService.isConfigured {
   do {
    let enhanceText = textForAI ?? text
    let (enhancedText, enhancementDuration, promptName) = try await enhancementService.enhance(enhanceText)
    transcription = Transcription(
     text: text,
     duration: duration,
     enhancedText: enhancedText,
     audioFileURL: audioFileURL,
     transcriptionModelName: model.displayName,
     aiEnhancementModelName: enhancementService.getAIService()?.currentModel,
     promptName: promptName,
     transcriptionDuration: transcriptionDuration,
     enhancementDuration: enhancementDuration,
     aiRequestSystemMessage: enhancementService.lastSystemMessageSent,
     aiRequestUserMessage: enhancementService.lastUserMessageSent,
     powerModeName: powerModeName,
     powerModeEmoji: powerModeEmoji
    )
    transcription.aiProviderName = enhancementService.getAIService()?.selectedProvider.rawValue
    transcription.promptText = enhancementService.activePrompt?.promptText
    transcription.screenCaptureEnabled = enhancementService.useScreenCaptureContext
    transcription.clipboardContextEnabled = enhancementService.useClipboardContext
    if AIPrompts.powerModeOverride != nil {
     transcription.systemInstructionsSource = "power-mode"
    } else if PromptFileManager.hasUserOverride("system-instructions") {
     transcription.systemInstructionsSource = "user-override"
    } else {
     transcription.systemInstructionsSource = "bundle-default"
    }
   } catch {
    logger.error("Enhancement failed: \(error.localizedDescription, privacy: .public)")
    transcription = Transcription(
     text: text,
     duration: duration,
     audioFileURL: audioFileURL,
     transcriptionModelName: model.displayName,
     promptName: nil,
     transcriptionDuration: transcriptionDuration,
     powerModeName: powerModeName,
     powerModeEmoji: powerModeEmoji
    )
   }
  } else {
   transcription = Transcription(
    text: text,
    duration: duration,
    audioFileURL: audioFileURL,
    transcriptionModelName: model.displayName,
    promptName: nil,
    transcriptionDuration: transcriptionDuration,
    powerModeName: powerModeName,
    powerModeEmoji: powerModeEmoji
   )
  }

  modelContext.insert(transcription)
  modelContext.safeSave(context: "save transcription", logger: logger)
  NotificationCenter.default.post(name: .transcriptionCreated, object: transcription)
  NotificationCenter.default.post(name: .transcriptionCompleted, object: transcription)

  return transcription
 }

 // MARK: - Helpers

 private static func recordingsURL(prefix: String) -> URL {
  let recordingsDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
   .appendingPathComponent("com.prakashjoshipax.VoiceInk")
   .appendingPathComponent("Recordings")
  return recordingsDirectory.appendingPathComponent("\(prefix)_\(UUID().uuidString).wav")
 }

 func cancelProcessing() {
  currentTask?.cancel()
 }

 private func finishProcessing() {
  isProcessing = false
  processingPhase = .idle
  currentTask = nil
 }

 private func handleError(_ error: Error) {
  logger.error("Transcription error: \(error.localizedDescription, privacy: .public)")
  errorMessage = error.localizedDescription
  isProcessing = false
  processingPhase = .idle
  currentTask = nil
 }
}

enum TranscriptionError: Error, LocalizedError {
 case noModelSelected
 case noAudioFile
 case transcriptionCancelled

 var errorDescription: String? {
  switch self {
  case .noModelSelected:
   return "No transcription model selected"
  case .noAudioFile:
   return "Audio file not found"
  case .transcriptionCancelled:
   return "Transcription was cancelled"
  }
 }
}
