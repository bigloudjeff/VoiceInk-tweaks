import Foundation

@MainActor
protocol WhisperContextProvider: AnyObject {
 var isModelLoaded: Bool { get }
 var whisperContext: WhisperContext? { get }
 var currentTranscriptionModel: (any TranscriptionModel)? { get }
 var availableModels: [WhisperModel] { get }
 var modelsDirectory: URL { get }
}
