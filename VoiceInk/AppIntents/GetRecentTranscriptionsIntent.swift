import AppIntents
import Foundation
import SwiftData

struct GetRecentTranscriptionsIntent: AppIntent {
 static var title: LocalizedStringResource = "Get Recent VoiceInk Transcriptions"
 static var description = IntentDescription("Get the most recent transcriptions from VoiceInk.")

 static var openAppWhenRun: Bool = false

 @Parameter(title: "Count", default: 5)
 var count: Int

 @MainActor
 func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
  guard let container = AppServiceLocator.shared.modelContainer else {
   throw IntentError.serviceNotAvailable
  }

  let limit = max(1, min(count, 50))
  let context = container.mainContext
  var descriptor = FetchDescriptor<Transcription>(
   sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
  )
  descriptor.fetchLimit = limit

  let transcriptions = (try? context.fetch(descriptor)) ?? []

  if transcriptions.isEmpty {
   return .result(value: "", dialog: "No transcriptions found")
  }

  let formatter = DateFormatter()
  formatter.dateStyle = .short
  formatter.timeStyle = .short

  let lines = transcriptions.map { t in
   let text = t.enhancedText ?? t.text
   let date = formatter.string(from: t.timestamp)
   return "[\(date)] \(text)"
  }
  let result = lines.joined(separator: "\n\n")
  return .result(value: result, dialog: "Found \(transcriptions.count) transcription(s)")
 }
}
