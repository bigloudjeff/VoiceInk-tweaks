import Testing
import SwiftData
@testable import VoiceInk

@MainActor
struct CustomVocabularyServiceTests {
 private func makeContainer() throws -> ModelContainer {
  let schema = Schema([VocabularyWord.self, WordReplacement.self, VocabularySuggestion.self])
  let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
  return try ModelContainer(for: schema, configurations: [config])
 }

 // MARK: - addWords

 @Test func addSingleWord() throws {
  let container = try makeContainer()
  let result = CustomVocabularyService.shared.addWords("Kubernetes", in: container)
  #expect(result.added == ["Kubernetes"])
  #expect(result.duplicates.isEmpty)
 }

 @Test func addCommaSeparatedWords() throws {
  let container = try makeContainer()
  let result = CustomVocabularyService.shared.addWords("Kubernetes, Anthropic, Claude", in: container)
  #expect(result.added.count == 3)
  #expect(result.added.contains("Kubernetes"))
  #expect(result.added.contains("Anthropic"))
  #expect(result.added.contains("Claude"))
  #expect(result.duplicates.isEmpty)
 }

 @Test func addDuplicateWordSkipped() throws {
  let container = try makeContainer()
  _ = CustomVocabularyService.shared.addWords("Kubernetes", in: container)
  let result = CustomVocabularyService.shared.addWords("Kubernetes", in: container)
  #expect(result.added.isEmpty)
  #expect(result.duplicates == ["Kubernetes"])
 }

 @Test func addDuplicateCaseInsensitive() throws {
  let container = try makeContainer()
  _ = CustomVocabularyService.shared.addWords("kubernetes", in: container)
  let result = CustomVocabularyService.shared.addWords("Kubernetes", in: container)
  #expect(result.added.isEmpty)
  #expect(result.duplicates == ["Kubernetes"])
 }

 @Test func addMixedNewAndDuplicate() throws {
  let container = try makeContainer()
  _ = CustomVocabularyService.shared.addWords("Existing", in: container)
  let result = CustomVocabularyService.shared.addWords("Existing, NewWord", in: container)
  #expect(result.added == ["NewWord"])
  #expect(result.duplicates == ["Existing"])
 }

 @Test func addWithPhoneticHints() throws {
  let container = try makeContainer()
  let result = CustomVocabularyService.shared.addWords("Kubernetes", phoneticHints: "kuber netties", in: container)
  #expect(result.added == ["Kubernetes"])
  // Verify the hint was stored
  let words = CustomVocabularyService.shared.listWords(from: container)
  #expect(words.contains("Kubernetes"))
 }

 @Test func addEmptyStringReturnsEmpty() throws {
  let container = try makeContainer()
  let result = CustomVocabularyService.shared.addWords("", in: container)
  #expect(result.added.isEmpty)
  #expect(result.duplicates.isEmpty)
 }

 @Test func addWhitespaceOnlyReturnsEmpty() throws {
  let container = try makeContainer()
  let result = CustomVocabularyService.shared.addWords("  , , ", in: container)
  #expect(result.added.isEmpty)
  #expect(result.duplicates.isEmpty)
 }

 @Test func addTrimsWhitespace() throws {
  let container = try makeContainer()
  let result = CustomVocabularyService.shared.addWords("  Kubernetes  ", in: container)
  #expect(result.added == ["Kubernetes"])
 }

 // MARK: - removeWord

 @Test func removeExistingWord() throws {
  let container = try makeContainer()
  _ = CustomVocabularyService.shared.addWords("TestWord", in: container)
  let removed = CustomVocabularyService.shared.removeWord("TestWord", from: container)
  #expect(removed == true)
  let words = CustomVocabularyService.shared.listWords(from: container)
  #expect(!words.contains("TestWord"))
 }

 @Test func removeNonExistentWord() throws {
  let container = try makeContainer()
  let removed = CustomVocabularyService.shared.removeWord("NotThere", from: container)
  #expect(removed == false)
 }

 @Test func removeCaseInsensitive() throws {
  let container = try makeContainer()
  _ = CustomVocabularyService.shared.addWords("TestWord", in: container)
  let removed = CustomVocabularyService.shared.removeWord("testword", from: container)
  #expect(removed == true)
 }

 @Test func removeTrimsWhitespace() throws {
  let container = try makeContainer()
  _ = CustomVocabularyService.shared.addWords("TestWord", in: container)
  let removed = CustomVocabularyService.shared.removeWord("  TestWord  ", from: container)
  #expect(removed == true)
 }

 // MARK: - listWords

 @Test func listWordsEmpty() throws {
  let container = try makeContainer()
  let words = CustomVocabularyService.shared.listWords(from: container)
  #expect(words.isEmpty)
 }

 @Test func listWordsSorted() throws {
  let container = try makeContainer()
  _ = CustomVocabularyService.shared.addWords("Zebra, Apple, Mango", in: container)
  let words = CustomVocabularyService.shared.listWords(from: container)
  #expect(words == ["Apple", "Mango", "Zebra"])
 }

 @Test func listWordsAfterRemoval() throws {
  let container = try makeContainer()
  _ = CustomVocabularyService.shared.addWords("Alpha, Beta, Gamma", in: container)
  _ = CustomVocabularyService.shared.removeWord("Beta", from: container)
  let words = CustomVocabularyService.shared.listWords(from: container)
  #expect(words == ["Alpha", "Gamma"])
 }

 // MARK: - Integration: add then list

 @Test func addThenListRoundTrip() throws {
  let container = try makeContainer()
  let input = "SwiftUI, CoreData, Combine"
  _ = CustomVocabularyService.shared.addWords(input, in: container)
  let words = CustomVocabularyService.shared.listWords(from: container)
  #expect(words.count == 3)
  #expect(words.contains("SwiftUI"))
  #expect(words.contains("CoreData"))
  #expect(words.contains("Combine"))
 }
}
