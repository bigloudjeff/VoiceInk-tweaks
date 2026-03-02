import AppIntents
import Foundation
import SwiftData

struct GetLastTranscriptionIntent: AppIntent {
 static var title: LocalizedStringResource = "Get Last VoiceInk Transcription"
 static var description = IntentDescription("Get the most recent transcription text from VoiceInk.")

 static var openAppWhenRun: Bool = false

 @MainActor
 func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
  guard let container = AppServiceLocator.shared.modelContainer else {
   throw IntentError.serviceNotAvailable
  }

  let context = container.mainContext
  guard let transcription = LastTranscriptionService.getLastTranscription(from: context) else {
   return .result(value: "", dialog: "No transcriptions found")
  }

  let text = transcription.enhancedText ?? transcription.text
  return .result(value: text, dialog: "\(text)")
 }
}
