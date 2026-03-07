import Foundation
import SwiftData

@Model
final class VocabularySuggestion {
 var correctedPhrase: String = ""
 var rawPhrase: String = ""
 var occurrenceCount: Int = 1
 var status: String = "pending"
 var dateFirstSeen: Date = Date()
 var dateLastSeen: Date = Date()
 var sourceTranscriptionId: UUID?

 init(correctedPhrase: String, rawPhrase: String, sourceTranscriptionId: UUID? = nil) {
  self.correctedPhrase = correctedPhrase
  self.rawPhrase = rawPhrase
  self.occurrenceCount = 1
  self.status = "pending"
  self.dateFirstSeen = Date()
  self.dateLastSeen = Date()
  self.sourceTranscriptionId = sourceTranscriptionId
 }
}
