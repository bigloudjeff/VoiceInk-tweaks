import AppIntents
import Foundation
import SwiftData

struct SearchTranscriptionsIntent: AppIntent {
 static var title: LocalizedStringResource = "Search VoiceInk Transcriptions"
 static var description = IntentDescription("Search transcription history by keyword.")

 static var openAppWhenRun: Bool = false

 @Parameter(title: "Search Query")
 var query: String

 @MainActor
 func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
  guard let container = AppServiceLocator.shared.modelContainer else {
   throw IntentError.serviceNotAvailable
  }

  let context = container.mainContext
  let searchTerm = query.lowercased()
  var descriptor = FetchDescriptor<Transcription>(
   sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
  )
  descriptor.fetchLimit = 100

  let all = (try? context.fetch(descriptor)) ?? []
  let matches = all.filter { t in
   t.text.lowercased().contains(searchTerm) ||
   (t.enhancedText?.lowercased().contains(searchTerm) ?? false)
  }

  if matches.isEmpty {
   return .result(value: "", dialog: "No transcriptions matching \"\(query)\"")
  }

  let formatter = DateFormatter()
  formatter.dateStyle = .short
  formatter.timeStyle = .short

  let capped = Array(matches.prefix(20))
  let lines = capped.map { t in
   let text = t.enhancedText ?? t.text
   let date = formatter.string(from: t.timestamp)
   return "[\(date)] \(text)"
  }
  let result = lines.joined(separator: "\n\n")
  return .result(value: result, dialog: "Found \(matches.count) match(es)")
 }
}
