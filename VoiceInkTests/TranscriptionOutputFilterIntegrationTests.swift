import Testing
@testable import VoiceInk

// MARK: - Mock

private struct MockFillerWordProvider: FillerWordProviding {
 var isEnabled: Bool
 var fillerWords: [String]
}

struct TranscriptionOutputFilterIntegrationTests {

 private func enabledProvider(words: [String] = ["uh", "um"]) -> MockFillerWordProvider {
  MockFillerWordProvider(isEnabled: true, fillerWords: words)
 }

 private func disabledProvider() -> MockFillerWordProvider {
  MockFillerWordProvider(isEnabled: false, fillerWords: ["uh", "um"])
 }

 // MARK: - Filler + XML combined

 @Test func removesXMLTagsAndFillerWords() {
  let input = "<caption>noise</caption> Hello uh world"
  let result = TranscriptionOutputFilter.filter(input, fillerWordProvider: enabledProvider())
  #expect(result == "Hello world")
 }

 // MARK: - Bracket removal with fillers

 @Test func removesBracketsAndFillerWords() {
  let input = "Hello [music] um world (applause)"
  let result = TranscriptionOutputFilter.filter(input, fillerWordProvider: enabledProvider())
  #expect(result == "Hello world")
 }

 // MARK: - Whitespace normalization

 @Test func normalizesWhitespaceAfterRemovals() {
  let input = "Hello   uh   world   um   test"
  let result = TranscriptionOutputFilter.filter(input, fillerWordProvider: enabledProvider())
  #expect(result == "Hello world test")
 }

 // MARK: - Disabled fillers

 @Test func preservesFillerWordsWhenDisabled() {
  let input = "Hello uh world um test"
  let result = TranscriptionOutputFilter.filter(input, fillerWordProvider: disabledProvider())
  #expect(result == "Hello uh world um test")
 }

 // MARK: - Empty text

 @Test func handlesEmptyText() {
  let result = TranscriptionOutputFilter.filter("", fillerWordProvider: enabledProvider())
  #expect(result == "")
 }

 // MARK: - All filters active

 @Test func allFiltersActiveSimultaneously() {
  let input = "<tag>removed</tag> Hello [noise] uh world {applause} um test"
  let result = TranscriptionOutputFilter.filter(input, fillerWordProvider: enabledProvider())
  #expect(result == "Hello world test")
 }

 // MARK: - Content preservation

 @Test func preservesContentWithNoMatchingFilters() {
  let input = "This is clean text with no issues."
  let result = TranscriptionOutputFilter.filter(input, fillerWordProvider: enabledProvider())
  #expect(result == "This is clean text with no issues.")
 }

 // MARK: - Operation order (XML first, then brackets, then fillers, then whitespace)

 @Test func fillerInsideXMLTagIsRemovedWithTag() {
  // Filler word inside XML tag should be removed along with the tag
  let input = "<note>uh something</note> Hello world"
  let result = TranscriptionOutputFilter.filter(input, fillerWordProvider: enabledProvider())
  #expect(result == "Hello world")
 }
}
