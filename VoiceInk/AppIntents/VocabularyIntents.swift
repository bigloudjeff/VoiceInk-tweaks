import AppIntents
import Foundation

struct AddVocabularyIntent: AppIntent {
 static var title: LocalizedStringResource = "Add VoiceInk Vocabulary"
 static var description = IntentDescription("Add words to VoiceInk vocabulary for improved transcription.")

 static var openAppWhenRun: Bool = false

 @Parameter(title: "Words")
 var words: String

 @Parameter(title: "Phonetic Hints", default: nil)
 var phoneticHints: String?

 @MainActor
 func perform() async throws -> some IntentResult & ProvidesDialog {
  guard let container = AppServiceLocator.shared.modelContainer else {
   throw IntentError.serviceNotAvailable
  }
  let result = CustomVocabularyService.shared.addWords(words, phoneticHints: phoneticHints, in: container)
  var parts: [String] = []
  if !result.added.isEmpty {
   parts.append("Added: \(result.added.joined(separator: ", "))")
  }
  if !result.duplicates.isEmpty {
   parts.append("Already exists: \(result.duplicates.joined(separator: ", "))")
  }
  let message = parts.isEmpty ? "No words to add" : parts.joined(separator: ". ")
  return .result(dialog: "\(message)")
 }
}

struct RemoveVocabularyIntent: AppIntent {
 static var title: LocalizedStringResource = "Remove VoiceInk Vocabulary"
 static var description = IntentDescription("Remove a word from VoiceInk vocabulary.")

 static var openAppWhenRun: Bool = false

 @Parameter(title: "Word")
 var word: String

 @MainActor
 func perform() async throws -> some IntentResult & ProvidesDialog {
  guard let container = AppServiceLocator.shared.modelContainer else {
   throw IntentError.serviceNotAvailable
  }
  if CustomVocabularyService.shared.removeWord(word, from: container) {
   return .result(dialog: "Removed: \(word)")
  } else {
   return .result(dialog: "Not found: \(word)")
  }
 }
}

struct ListVocabularyIntent: AppIntent {
 static var title: LocalizedStringResource = "List VoiceInk Vocabulary"
 static var description = IntentDescription("List all words in VoiceInk vocabulary.")

 static var openAppWhenRun: Bool = false

 @MainActor
 func perform() async throws -> some IntentResult & ProvidesDialog {
  guard let container = AppServiceLocator.shared.modelContainer else {
   throw IntentError.serviceNotAvailable
  }
  let words = CustomVocabularyService.shared.listWords(from: container)
  if words.isEmpty {
   return .result(dialog: "Vocabulary is empty")
  }
  return .result(dialog: "\(words.count) words: \(words.joined(separator: ", "))")
 }
}
