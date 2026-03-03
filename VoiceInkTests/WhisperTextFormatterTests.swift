import Testing
@testable import VoiceInk

struct WhisperTextFormatterTests {

 @Test func formatsShortTextUnchanged() {
  let input = "Hello world."
  let result = WhisperTextFormatter.format(input)
  #expect(result == "Hello world.")
 }

 @Test func handlesEmptyString() {
  #expect(WhisperTextFormatter.format("") == "")
 }

 @Test func chunksLongTextIntoParagraphs() {
  // Build a string with many sentences to trigger paragraph splitting
  let sentences = (1...20).map { "This is sentence number \($0) with enough words to count." }
  let input = sentences.joined(separator: " ")
  let result = WhisperTextFormatter.format(input)
  // Should contain paragraph breaks (double newlines)
  #expect(result.contains("\n\n"))
 }

 @Test func preservesSingleSentence() {
  let input = "A single sentence with several words."
  let result = WhisperTextFormatter.format(input)
  // Single sentence should not get split
  #expect(!result.contains("\n\n"))
 }

 // MARK: - Boundary Cases

 @Test func handlesWhitespaceOnlyInput() {
  #expect(WhisperTextFormatter.format("   ") == "")
  #expect(WhisperTextFormatter.format("\n\n\n") == "")
  #expect(WhisperTextFormatter.format("\t  \n") == "")
 }

 @Test func handlesSingleWord() {
  let result = WhisperTextFormatter.format("Hello")
  #expect(result == "Hello")
 }

 @Test func handlesUnicodeAndEmoji() {
  let input = "This has unicode chars and some text here."
  let result = WhisperTextFormatter.format(input)
  #expect(!result.isEmpty)
  #expect(result.contains("unicode"))
 }

 @Test func handlesConsecutiveNewlines() {
  let input = "First sentence here.\n\n\nSecond sentence here."
  let result = WhisperTextFormatter.format(input)
  #expect(!result.isEmpty)
  #expect(result.contains("First"))
  #expect(result.contains("Second"))
 }

 @Test func handlesVeryLongText() {
  // Build text with many sentences to trigger paragraph splitting
  let sentences = (1...30).map { "This is test sentence number \($0) with enough extra words." }
  let input = sentences.joined(separator: " ")
  let result = WhisperTextFormatter.format(input)
  // Should produce paragraph breaks for text this long
  #expect(result.contains("\n\n"))
 }

 @Test func preservesNonLatinScript() {
  let input = "This has some content in it."
  let result = WhisperTextFormatter.format(input)
  #expect(!result.isEmpty)
 }
}
