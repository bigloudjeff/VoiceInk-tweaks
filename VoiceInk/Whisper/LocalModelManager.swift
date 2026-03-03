import Foundation
import os
import Zip
import SwiftUI
import SwiftData
import Atomics

@MainActor
protocol LocalModelManagerDelegate: AnyObject {
 func localModelManagerDidUpdateAvailableModels(_ models: [WhisperModel])
 func localModelManagerDidUpdateDownloadProgress(_ progress: [String: Double])
 func localModelManagerDidUpdateModelLoaded(_ loaded: Bool)
 func localModelManagerDidUpdateModelLoading(_ loading: Bool)
 func localModelManagerDidDeleteCurrentModel(named: String)
 func localModelManagerDidImportModel(name: String, asTranscriptionModel model: ImportedLocalModel)
 func localModelManagerDidUpdateWhisperContext(_ context: WhisperContext?)
 func localModelManagerDidUpdateLoadedLocalModel(_ model: WhisperModel?)
}

@MainActor
class LocalModelManager {

 let modelsDirectory: URL
 private let modelContext: ModelContext
 private let notificationPresenter: any NotificationPresenting
 let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "LocalModelManager")

 weak var delegate: LocalModelManagerDelegate?

 private(set) var whisperContext: WhisperContext? {
  didSet { delegate?.localModelManagerDidUpdateWhisperContext(whisperContext) }
 }
 private(set) var availableModels: [WhisperModel] = [] {
  didSet { delegate?.localModelManagerDidUpdateAvailableModels(availableModels) }
 }
 var downloadProgress: [String: Double] = [:] {
  didSet { delegate?.localModelManagerDidUpdateDownloadProgress(downloadProgress) }
 }
 private(set) var isModelLoaded = false {
  didSet { delegate?.localModelManagerDidUpdateModelLoaded(isModelLoaded) }
 }
 private(set) var isModelLoading = false {
  didSet { delegate?.localModelManagerDidUpdateModelLoading(isModelLoading) }
 }
 private(set) var loadedLocalModel: WhisperModel? {
  didSet { delegate?.localModelManagerDidUpdateLoadedLocalModel(loadedLocalModel) }
 }

 init(modelsDirectory: URL, modelContext: ModelContext, notificationPresenter: any NotificationPresenting = NotificationManager.shared) {
  self.modelsDirectory = modelsDirectory
  self.modelContext = modelContext
  self.notificationPresenter = notificationPresenter
 }

 // MARK: - Model Directory Management

 func createModelsDirectoryIfNeeded() {
  do {
   try FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true, attributes: nil)
  } catch {
   logError("Error creating models directory", error)
  }
 }

 func loadAvailableModels() {
  do {
   let fileURLs = try FileManager.default.contentsOfDirectory(at: modelsDirectory, includingPropertiesForKeys: nil)
   availableModels = fileURLs.compactMap { url in
    guard url.pathExtension == "bin" else { return nil }
    return WhisperModel(name: url.deletingPathExtension().lastPathComponent, url: url)
   }
  } catch {
   logError("Error loading available models", error)
  }
 }

 // MARK: - Model Loading

 func loadModel(_ model: WhisperModel) async throws {
  guard whisperContext == nil else { return }

  isModelLoading = true
  defer { isModelLoading = false }

  do {
   whisperContext = try await WhisperContext.createContext(path: model.url.path)

   let basePrompt = UserDefaults.standard.string(forKey: UserDefaults.Keys.transcriptionPrompt) ?? WhisperPrompt().transcriptionPrompt
   let vocabularyString = CustomVocabularyService.shared.getTranscriptionVocabulary(from: modelContext)
   let fullPrompt = vocabularyString.isEmpty ? basePrompt : basePrompt + " " + vocabularyString
   await whisperContext?.setPrompt(fullPrompt)

   isModelLoaded = true
   loadedLocalModel = model
  } catch {
   throw WhisperStateError.modelLoadFailed
  }
 }

 // MARK: - Model Download

 func downloadModel(_ model: LocalModel) async {
  guard let url = URL(string: model.downloadURL) else { return }
  await performModelDownload(model, url)
 }

 private func performModelDownload(_ model: LocalModel, _ url: URL) async {
  do {
   var whisperModel = try await downloadMainModel(model, from: url)

   if let coreMLZipURL = whisperModel.coreMLZipDownloadURL,
    let coreMLURL = URL(string: coreMLZipURL) {
    whisperModel = try await downloadAndSetupCoreMLModel(for: whisperModel, from: coreMLURL)
   }

   availableModels.append(whisperModel)
   downloadProgress.removeValue(forKey: model.name + "_main")

   if shouldWarmup(model) {
    WhisperModelWarmupCoordinator.shared.scheduleWarmup(for: model, contextProvider: self)
   }
  } catch {
   handleModelDownloadError(model, error)
  }
 }

 private func downloadMainModel(_ model: LocalModel, from url: URL) async throws -> WhisperModel {
  let progressKeyMain = model.name + "_main"
  let data = try await downloadFileWithProgress(from: url, progressKey: progressKeyMain)

  let destinationURL = modelsDirectory.appendingPathComponent(model.filename)
  try data.write(to: destinationURL)

  return WhisperModel(name: model.name, url: destinationURL)
 }

 private func downloadAndSetupCoreMLModel(for model: WhisperModel, from url: URL) async throws -> WhisperModel {
  let progressKeyCoreML = model.name + "_coreml"
  let coreMLData = try await downloadFileWithProgress(from: url, progressKey: progressKeyCoreML)

  let coreMLZipPath = modelsDirectory.appendingPathComponent("\(model.name)-encoder.mlmodelc.zip")
  try coreMLData.write(to: coreMLZipPath)

  return try await unzipAndSetupCoreMLModel(for: model, zipPath: coreMLZipPath, progressKey: progressKeyCoreML)
 }

 private func unzipAndSetupCoreMLModel(for model: WhisperModel, zipPath: URL, progressKey: String) async throws -> WhisperModel {
  let coreMLDestination = modelsDirectory.appendingPathComponent("\(model.name)-encoder.mlmodelc")

  try? FileManager.default.removeItem(at: coreMLDestination)
  try await unzipCoreMLFile(zipPath, to: modelsDirectory)
  return try verifyAndCleanupCoreMLFiles(model, coreMLDestination, zipPath, progressKey)
 }

 private func unzipCoreMLFile(_ zipPath: URL, to destination: URL) async throws {
  let finished = ManagedAtomic(false)

  return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
   func finishOnce(_ result: Result<Void, Error>) {
    if finished.exchange(true, ordering: .acquiring) == false {
     continuation.resume(with: result)
    }
   }

   do {
    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
    try Zip.unzipFile(zipPath, destination: destination, overwrite: true, password: nil)
    finishOnce(.success(()))
   } catch {
    finishOnce(.failure(error))
   }
  }
 }

 private func verifyAndCleanupCoreMLFiles(_ model: WhisperModel, _ destination: URL, _ zipPath: URL, _ progressKey: String) throws -> WhisperModel {
  var model = model

  var isDirectory: ObjCBool = false
  guard FileManager.default.fileExists(atPath: destination.path, isDirectory: &isDirectory), isDirectory.boolValue else {
   try? FileManager.default.removeItem(at: zipPath)
   throw WhisperStateError.unzipFailed
  }

  try? FileManager.default.removeItem(at: zipPath)
  model.coreMLEncoderURL = destination
  downloadProgress.removeValue(forKey: progressKey)

  return model
 }

 private func shouldWarmup(_ model: LocalModel) -> Bool {
  !model.name.contains("q5") && !model.name.contains("q8")
 }

 private func handleModelDownloadError(_ model: LocalModel, _ error: Error) {
  downloadProgress.removeValue(forKey: model.name + "_main")
  downloadProgress.removeValue(forKey: model.name + "_coreml")
 }

 private func downloadFileWithProgress(from url: URL, progressKey: String) async throws -> Data {
  let destinationURL = modelsDirectory.appendingPathComponent(UUID().uuidString)

  return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Data, Error>) in
   let finished = ManagedAtomic(false)

   func finishOnce(_ result: Result<Data, Error>) {
    if finished.exchange(true, ordering: .acquiring) == false {
     continuation.resume(with: result)
    }
   }

   let task = URLSession.shared.downloadTask(with: url) { tempURL, response, error in
    if let error = error {
     finishOnce(.failure(error))
     return
    }

    guard let httpResponse = response as? HTTPURLResponse,
       (200...299).contains(httpResponse.statusCode),
       let tempURL = tempURL else {
     finishOnce(.failure(URLError(.badServerResponse)))
     return
    }

    do {
     try FileManager.default.moveItem(at: tempURL, to: destinationURL)
     let data = try Data(contentsOf: destinationURL, options: .mappedIfSafe)
     finishOnce(.success(data))
     try? FileManager.default.removeItem(at: destinationURL)
    } catch {
     finishOnce(.failure(error))
    }
   }

   task.resume()

   var lastUpdateTime = Date()
   var lastProgressValue: Double = 0

   let observation = task.progress.observe(\.fractionCompleted) { progress, _ in
    let currentTime = Date()
    let timeSinceLastUpdate = currentTime.timeIntervalSince(lastUpdateTime)
    let currentProgress = round(progress.fractionCompleted * 100) / 100

    if timeSinceLastUpdate >= 0.5 && abs(currentProgress - lastProgressValue) >= 0.01 {
     lastUpdateTime = currentTime
     lastProgressValue = currentProgress

     DispatchQueue.main.async {
      self.downloadProgress[progressKey] = currentProgress
     }
    }
   }

   Task {
    await withTaskCancellationHandler {
     observation.invalidate()
     if finished.exchange(true, ordering: .acquiring) == false {
      continuation.resume(throwing: CancellationError())
     }
    } operation: {
     await withCheckedContinuation { (_: CheckedContinuation<Void, Never>) in }
    }
   }
  }
 }

 // MARK: - Model Deletion

 func deleteModel(_ model: WhisperModel, currentTranscriptionModelName: String?) async {
  do {
   try FileManager.default.removeItem(at: model.url)

   if let coreMLURL = model.coreMLEncoderURL {
    try? FileManager.default.removeItem(at: coreMLURL)
   } else {
    let coreMLDir = modelsDirectory.appendingPathComponent("\(model.name)-encoder.mlmodelc")
    if FileManager.default.fileExists(atPath: coreMLDir.path) {
     try? FileManager.default.removeItem(at: coreMLDir)
    }
   }

   availableModels.removeAll { $0.id == model.id }
   if currentTranscriptionModelName == model.name {
    delegate?.localModelManagerDidDeleteCurrentModel(named: model.name)
    loadedLocalModel = nil
   }
  } catch {
   logError("Error deleting model: \(model.name)", error)
  }
 }

 func unloadModel() {
  Task {
   await whisperContext?.releaseResources()
   whisperContext = nil
   isModelLoaded = false
  }
 }

 func clearDownloadedModels() async {
  for model in availableModels {
   do {
    try FileManager.default.removeItem(at: model.url)
   } catch {
    logError("Error deleting model during cleanup", error)
   }
  }
  availableModels.removeAll()
 }

 // MARK: - Resource Management

 func cleanupModelResources() async {
  logger.notice("cleanupModelResources: releasing model resources")
  await whisperContext?.releaseResources()
  whisperContext = nil
  isModelLoaded = false
  logger.notice("cleanupModelResources: completed")
 }

 // MARK: - Import Local Model

 func importLocalModel(from sourceURL: URL) async {
  guard sourceURL.pathExtension.lowercased() == "bin" else { return }

  let baseName = sourceURL.deletingPathExtension().lastPathComponent
  let destinationURL = modelsDirectory.appendingPathComponent("\(baseName).bin")

  if FileManager.default.fileExists(atPath: destinationURL.path) {
   await notificationPresenter.showNotification(
    title: "A model named \(baseName).bin already exists",
    type: .warning,
    duration: 4.0
   )
   return
  }

  do {
   try FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
   try FileManager.default.copyItem(at: sourceURL, to: destinationURL)

   let newWhisperModel = WhisperModel(name: baseName, url: destinationURL)
   availableModels.append(newWhisperModel)

   let imported = ImportedLocalModel(fileBaseName: baseName)
   delegate?.localModelManagerDidImportModel(name: baseName, asTranscriptionModel: imported)

   await notificationPresenter.showNotification(
    title: "Imported \(destinationURL.lastPathComponent)",
    type: .success,
    duration: 3.0
   )
  } catch {
   logError("Failed to import local model", error)
   await notificationPresenter.showNotification(
    title: "Failed to import model: \(error.localizedDescription)",
    type: .error,
    duration: 5.0
   )
  }
 }

 // MARK: - Helpers

 private func logError(_ message: String, _ error: Error) {
  logger.error("\(message, privacy: .public): \(error.localizedDescription, privacy: .public)")
 }
}

// MARK: - WhisperContextProvider Conformance

extension LocalModelManager: WhisperContextProvider {
 var currentTranscriptionModel: (any TranscriptionModel)? { nil }
}
