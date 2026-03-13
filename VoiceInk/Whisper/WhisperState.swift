import Foundation
import SwiftUI
import AVFoundation
import SwiftData
import AppKit
import KeyboardShortcuts
import os

// MARK: - Recording State Machine
enum RecordingState: Equatable {
 case idle
 case starting
 case recording
 case transcribing
 case enhancing
 case busy
}

@MainActor
class WhisperState: NSObject, ObservableObject, WhisperContextProvider {
 @Published var recordingState: RecordingState = .idle
 @Published var isModelLoaded = false
 @Published var loadedLocalModel: WhisperModel?
 @Published var currentTranscriptionModel: (any TranscriptionModel)?
 @Published var isModelLoading = false
 @Published var availableModels: [WhisperModel] = []
 @Published var allAvailableModels: [any TranscriptionModel] = PredefinedModels.models
 @Published var clipboardMessage = ""
 @Published var miniRecorderError: String?
 @Published var shouldCancelRecording = false
 var partialTranscript: String = ""
 var currentSession: TranscriptionSession?
 private(set) var modelResourceManager: ModelResourceManager!
 var enhancementTask: Task<(String, TimeInterval, String?), Error>?
 var activeTranscriptionTask: Task<Void, Never>?


 @Published var recorderType: String = UserDefaults.standard.string(forKey: UserDefaults.Keys.recorderType) ?? "mini" {
 didSet {
 if isMiniRecorderVisible {
 if oldValue == "notch" {
 recorderUICoordinator.notchWindowManager?.hide()
 recorderUICoordinator.notchWindowManager = nil
 } else {
 recorderUICoordinator.miniWindowManager?.hide()
 recorderUICoordinator.miniWindowManager = nil
 }
 Task { @MainActor in
 try? await Task.sleep(for: .milliseconds(50))
 showRecorderPanel()
 }
 }
 UserDefaults.standard.set(recorderType, forKey: UserDefaults.Keys.recorderType)
 }
 }

 @Published var recorderScreenSelection: String = UserDefaults.standard.string(forKey: UserDefaults.Keys.recorderScreenSelection) ?? "mouseCursor" {
 didSet {
 UserDefaults.standard.set(recorderScreenSelection, forKey: UserDefaults.Keys.recorderScreenSelection)
 }
 }

 var selectedScreen: NSScreen? {
 switch recorderScreenSelection {
 case "mouseCursor":
 return NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) }
  ?? NSScreen.main
  ?? NSScreen.screens.first
 case "primaryDisplay":
 return NSScreen.screens.first
  ?? NSScreen.main
 default: // "activeWindow"
 return NSScreen.main
  ?? NSScreen.screens.first
 }
 }
 
 @Published var isMiniRecorderVisible = false {
 didSet {
 // Dispatch asynchronously to avoid "Publishing changes from within view updates" warning
 Task { @MainActor [self] in
 if isMiniRecorderVisible {
 showRecorderPanel()
 } else {
 hideRecorderPanel()
 }
 }
 }
 }
 
 var whisperContext: WhisperContext?
 let recorder = Recorder()
 var recordedFile: URL? = nil
 let whisperPrompt = WhisperPrompt()
 private(set) var localModelManager: LocalModelManager!
 private(set) var parakeetModelManager = ParakeetModelManager()
 
 // Prompt detection service for trigger word handling
 private let promptDetectionService = PromptDetectionService()

 private(set) var transcriptionOrchestrator: TranscriptionOrchestrator!
 private(set) var recorderUICoordinator = RecorderUICoordinator()

 let modelContext: ModelContext

 internal var serviceRegistry: TranscriptionServiceRegistry!
 
 private var modelUrl: URL? {
 let possibleURLs = [
 Bundle.main.url(forResource: "ggml-base.en", withExtension: "bin", subdirectory: "Models"),
 Bundle.main.url(forResource: "ggml-base.en", withExtension: "bin"),
 Bundle.main.bundleURL.appendingPathComponent("Models/ggml-base.en.bin")
 ]
 
 for url in possibleURLs {
 if let url = url, FileManager.default.fileExists(atPath: url.path) {
 return url
 }
 }
 return nil
 }
 
 private enum LoadError: Error {
 case couldNotLocateModel
 }
 
 let modelsDirectory: URL
 let recordingsDirectory: URL
 let enhancementService: AIEnhancementService?
 var licenseViewModel: LicenseViewModel
 let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "WhisperState")
 
 // For model progress tracking
 @Published var downloadProgress: [String: Double] = [:]
 @Published var parakeetDownloadStates: [String: Bool] = [:]
 
 init(modelContext: ModelContext, enhancementService: AIEnhancementService? = nil) {
 self.modelContext = modelContext
 let appSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
 .appendingPathComponent("com.prakashjoshipax.VoiceInk")
 
 self.modelsDirectory = appSupportDirectory.appendingPathComponent("WhisperModels")
 self.recordingsDirectory = appSupportDirectory.appendingPathComponent("Recordings")
 
 self.enhancementService = enhancementService
 self.licenseViewModel = LicenseViewModel()
 
 super.init()
 
 // Configure the session manager
 if let enhancementService = enhancementService {
 PowerModeSessionManager.shared.configure(whisperState: self, enhancementService: enhancementService)
 }

 // Initialize sub-managers
 self.localModelManager = LocalModelManager(modelsDirectory: self.modelsDirectory, modelContext: self.modelContext)
 self.localModelManager.delegate = self
 self.parakeetModelManager.delegate = self

 // Initialize the transcription service registry
 self.serviceRegistry = TranscriptionServiceRegistry(contextProvider: self, modelContext: self.modelContext, modelsDirectory: self.modelsDirectory)

 // Initialize the model resource manager
 self.modelResourceManager = ModelResourceManager(
  localModelManager: self.localModelManager,
  serviceRegistry: self.serviceRegistry
 )

 // Initialize the transcription orchestrator
 self.transcriptionOrchestrator = TranscriptionOrchestrator(
  modelContext: self.modelContext,
  recorder: self.recorder,
  serviceRegistry: self.serviceRegistry,
  enhancementService: self.enhancementService,
  promptDetectionService: self.promptDetectionService,
  licenseViewModel: self.licenseViewModel,
  powerModeProvider: PowerModeManager.shared,
  logger: self.logger
 )
 self.transcriptionOrchestrator.delegate = self

 // Wire up the recorder UI coordinator
 self.recorderUICoordinator.delegate = self

 setupNotifications()
 localModelManager.createModelsDirectoryIfNeeded()
 createRecordingsDirectoryIfNeeded()
 localModelManager.loadAvailableModels()
 loadCurrentTranscriptionModel()
 refreshAllAvailableModels()
 }
 
 deinit {
 enhancementTask?.cancel()
 activeTranscriptionTask?.cancel()
 NotificationCenter.default.removeObserver(self)
 }
 
 private func createRecordingsDirectoryIfNeeded() {
 do {
 try FileManager.default.createDirectory(at: recordingsDirectory, withIntermediateDirectories: true, attributes: nil)
 } catch {
 logger.error("Error creating recordings directory: \(error.localizedDescription, privacy: .public)")
 }
 }
 
 func toggleRecord(powerModeId: UUID? = nil) async {
 logger.notice("toggleRecord called – state=\(String(describing: self.recordingState), privacy: .public)")
 cancelScheduledModelCleanup()
 // Only allow toggle from .idle (start) or .recording (stop)
 guard recordingState == .idle || recordingState == .recording else {
 logger.notice("toggleRecord: ignored, state=\(String(describing: self.recordingState), privacy: .public)")
 return
 }
 if recordingState == .recording {
 partialTranscript = ""
 recordingState = .transcribing
 await recorder.stopRecording(restoreAudio: false)
 if let recordedFile {
 if !shouldCancelRecording {
 let audioAsset = AVURLAsset(url: recordedFile)
 let duration = (try? CMTimeGetSeconds(await audioAsset.load(.duration))) ?? 0.0

 let transcription = Transcription(
 text: "",
 duration: duration,
 audioFileURL: recordedFile.absoluteString,
 transcriptionStatus: .pending
 )
 modelContext.insert(transcription)
 modelContext.safeSave(context: "insert new transcription", logger: logger)
 NotificationCenter.default.post(name: .transcriptionCreated, object: transcription)

 let task = Task { await self.transcribeAudio(on: transcription) }
 self.activeTranscriptionTask = task
 await task.value
 self.activeTranscriptionTask = nil
 } else {
 currentSession?.cancel()
 currentSession = nil
 try? FileManager.default.removeItem(at: recordedFile)
 recorder.restoreAudio()
 await MainActor.run {
 recordingState = .idle
 }
 scheduleModelCleanup()
 }
 } else {
 logger.error(" No recorded file found after stopping recording")
 currentSession?.cancel()
 currentSession = nil
 recorder.restoreAudio()
 await MainActor.run {
 recordingState = .idle
 }
 }
 } else {
 logger.notice("toggleRecord: entering start-recording branch")
 guard currentTranscriptionModel != nil else {
 await MainActor.run {
 NotificationManager.shared.showNotification(
 title: "No AI Model Selected",
 type: .error
 )
 }
 return
 }
 shouldCancelRecording = false
 partialTranscript = ""
 requestRecordPermission { [self] granted in
 if granted {
 Task {
 do {
 // --- Prepare permanent file URL ---
 let fileName = "\(UUID().uuidString).wav"
 let permanentURL = self.recordingsDirectory.appendingPathComponent(fileName)
 self.recordedFile = permanentURL

 // Buffer chunks until session is ready, then forward directly.
 // A single lock guards both the buffer and the forward callback
 // so the audio thread never sees a half-swapped state.
 struct ChunkRouter {
 var buffer: [Data] = []
 var forward: ((Data) -> Void)? = nil
 }
 let chunkRouter = OSAllocatedUnfairLock(initialState: ChunkRouter())

 self.recorder.onAudioChunk = { data in
 let (fwd, buffered) = chunkRouter.withLock { router -> (((Data) -> Void)?, [Data]) in
 if let fwd = router.forward {
  if !router.buffer.isEmpty {
  let buf = router.buffer
  router.buffer.removeAll()
  return (fwd, buf)
  }
  return (fwd, [])
 }
 router.buffer.append(data)
 return (nil, [])
 }
 if let fwd {
 for chunk in buffered { fwd(chunk) }
 fwd(data)
 }
 }

 // Start recording immediately — no waiting for network
 try await self.recorder.startRecording(toOutputFile: permanentURL)

 await MainActor.run {
 self.recordingState = .recording
 }
 self.logger.notice("toggleRecord: recording started successfully, state=recording")

 // Power Mode resolves while recording runs (~50-200ms)
 await ActiveWindowService.shared.applyConfiguration(powerModeId: powerModeId)

 // Create session with the resolved model (skip if user already stopped)
 if self.recordingState == .recording, let model = self.currentTranscriptionModel {
 let session = self.serviceRegistry.createSession(for: model, onPartialTranscript: { [weak self] partial in
 Task { @MainActor in
 self?.partialTranscript = partial
 }
 })
 self.currentSession = session
 let realCallback = try await session.prepare(model: model)

 if let realCallback = realCallback {
 // Atomically activate forwarding; buffered chunks drain on next audio delivery
 chunkRouter.withLock { $0.forward = realCallback }
 } else {
 self.recorder.onAudioChunk = nil
 chunkRouter.withLock { $0.buffer.removeAll() }
 }
 }

 // Load model and capture context in background without blocking
 Task.detached { [weak self] in
 guard let self = self else { return }

 // Only load model if it's a local model and not already loaded
 if let model = await self.currentTranscriptionModel, model.provider == .local {
 if let localWhisperModel = await self.availableModels.first(where: { $0.name == model.name }),
 await self.whisperContext == nil {
 do {
 try await self.loadModel(localWhisperModel)
 } catch {
 await self.logger.error(" Model loading failed: \(error.localizedDescription, privacy: .public)")
 }
 }
 } else if let parakeetModel = await self.currentTranscriptionModel as? ParakeetModel {
 try? await self.serviceRegistry.parakeetTranscriptionService.loadModel(for: parakeetModel)
 }

 if let enhancementService = await self.enhancementService {
 async let clipboard: Void = MainActor.run {
 enhancementService.captureClipboardContext()
 }
 async let screen: Void = enhancementService.captureScreenContext()
 _ = await (clipboard, screen)

 // Prewarm enhancement LLM in background
 if let aiService = await enhancementService.getAIService() {
 await LLMPrewarmService.shared.prewarm(aiService: aiService)
 }
 }
 }

 } catch {
 self.logger.error(" Failed to start recording: \(error.localizedDescription, privacy: .public)")
 await NotificationManager.shared.showNotification(title: "Recording failed to start", type: .error)
 self.logger.notice("toggleRecord: calling dismissMiniRecorder from error handler")
 await self.dismissMiniRecorder()
 // Do not remove the file on a failed start, to preserve all recordings.
 self.recordedFile = nil
 }
 }
 } else {
 logger.error(" Recording permission denied.")
 }
 }
 }
 }
 
 private func requestRecordPermission(response: @escaping (Bool) -> Void) {
 response(true)
 }
 
 private func transcribeAudio(on transcription: Transcription) async {
  await transcriptionOrchestrator.transcribeAudio(on: transcription)
 }

 func getEnhancementService() -> AIEnhancementService? {
  return enhancementService
 }


 func scheduleModelCleanup() {
  modelResourceManager.scheduleModelCleanup()
 }

 func cancelScheduledModelCleanup() {
  modelResourceManager.cancelScheduledModelCleanup()
 }
}

// MARK: - TranscriptionOrchestratorDelegate

extension WhisperState: TranscriptionOrchestratorDelegate {}
