import Testing
@testable import VoiceInk

struct PromptDetectionServiceTests {

 private func makeService() -> PromptDetectionService {
  PromptDetectionService()
 }

 // MARK: - stripLeadingTriggerWord

 @Test func stripsLeadingTriggerWord() {
  let service = makeService()
  let result = service.stripLeadingTriggerWord(from: "hey write me an email", triggerWord: "hey")
  #expect(result == "Write me an email")
 }

 @Test func leadingTriggerWordNotAtBoundary() {
  let service = makeService()
  // "heyday" starts with "hey" but is a different word
  let result = service.stripLeadingTriggerWord(from: "heyday is a word", triggerWord: "hey")
  #expect(result == nil)
 }

 @Test func leadingTriggerCaseInsensitive() {
  let service = makeService()
  let result = service.stripLeadingTriggerWord(from: "HEY write this", triggerWord: "hey")
  #expect(result == "Write this")
 }

 @Test func leadingTriggerIsEntireText() {
  let service = makeService()
  let result = service.stripLeadingTriggerWord(from: "hey", triggerWord: "hey")
  #expect(result == "")
 }

 // MARK: - stripTrailingTriggerWord

 @Test func stripsTrailingTriggerWord() {
  let service = makeService()
  let result = service.stripTrailingTriggerWord(from: "write me an email hey", triggerWord: "hey")
  #expect(result == "Write me an email")
 }

 @Test func trailingTriggerWordNotAtBoundary() {
  let service = makeService()
  let result = service.stripTrailingTriggerWord(from: "they said hello", triggerWord: "hey")
  #expect(result == nil)
 }

 @Test func trailingTriggerStripsTrailingPunctuation() {
  let service = makeService()
  let result = service.stripTrailingTriggerWord(from: "write this hey.", triggerWord: "hey")
  #expect(result == "Write this")
 }

 // MARK: - detectAndStripTriggerWord

 @Test func detectsAndStripsTriggerWord() {
  let service = makeService()
  let result = service.detectAndStripTriggerWord(from: "hey write me an email", triggerWords: ["hey", "yo"])
  #expect(result != nil)
  #expect(result?.0 == "hey")
  #expect(result?.1 == "Write me an email")
 }

 @Test func detectsLongestMatchFirst() {
  let service = makeService()
  // "hey siri" is longer than "hey" and should match first
  let result = service.detectAndStripTriggerWord(from: "hey siri write this", triggerWords: ["hey", "hey siri"])
  #expect(result?.0 == "hey siri")
 }

 @Test func returnsNilWhenNoTriggerFound() {
  let service = makeService()
  let result = service.detectAndStripTriggerWord(from: "just some text", triggerWords: ["hey", "yo"])
  #expect(result == nil)
 }

 @Test func handlesEmptyTriggerWords() {
  let service = makeService()
  let result = service.detectAndStripTriggerWord(from: "hey there", triggerWords: [])
  #expect(result == nil)
 }

 @Test func stripsBothLeadingAndTrailing() {
  let service = makeService()
  // Trigger word at both ends
  let result = service.detectAndStripTriggerWord(from: "hey write this hey", triggerWords: ["hey"])
  #expect(result != nil)
  #expect(result?.1 == "Write this")
 }
}
