import AppIntents
import Foundation
import SwiftData

struct TranscribeAudioFileIntent: AppIntent {
 static var title: LocalizedStringResource = "Transcribe Audio File with VoiceInk"
 static var description = IntentDescription("Transcribe an audio file using the currently selected transcription model.")

 static var openAppWhenRun: Bool = false

 @Parameter(title: "Audio File")
 var file: IntentFile

 @MainActor
 func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
  guard let whisperState = AppServiceLocator.shared.whisperState,
        let container = AppServiceLocator.shared.modelContainer else {
   throw IntentError.serviceNotAvailable
  }

  guard let currentModel = whisperState.currentTranscriptionModel else {
   return .result(value: "", dialog: "No transcription model is selected")
  }

  // Write intent file data to a temporary location (sanitize to prevent path traversal)
  let tempDir = FileManager.default.temporaryDirectory
  let rawName = file.filename ?? "voiceink_intent_audio.wav"
  let fileName = URL(fileURLWithPath: rawName).lastPathComponent
  let tempURL = tempDir.appendingPathComponent(fileName)

  try file.data.write(to: tempURL)
  defer { try? FileManager.default.removeItem(at: tempURL) }

  let context = container.mainContext
  let service = AudioTranscriptionService(modelContext: context, whisperState: whisperState)

  let transcription = try await service.retranscribeAudio(from: tempURL, using: currentModel)
  let text = transcription.enhancedText ?? transcription.text
  return .result(value: text, dialog: "\(text)")
 }
}
