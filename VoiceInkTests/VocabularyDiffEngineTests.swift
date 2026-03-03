import Testing
@testable import VoiceInk

struct VocabularyDiffEngineTests {

 // MARK: - Basic Extraction

 @Test func extractsSimpleWordCorrection() {
  let candidates = VocabularyDiffEngine.extractCandidates(
   raw: "I use klaud for coding",
   enhanced: "I use Claude for coding",
   commonWords: Set(["i", "use", "for"])
  )
  #expect(candidates.count == 1)
  #expect(candidates.first?.rawPhrase == "klaud")
  #expect(candidates.first?.correctedPhrase == "Claude")
 }

 @Test func returnsEmptyForIdenticalTexts() {
  let candidates = VocabularyDiffEngine.extractCandidates(
   raw: "Hello world",
   enhanced: "Hello world",
   commonWords: []
  )
  #expect(candidates.isEmpty)
 }

 @Test func returnsEmptyForEmptyInput() {
  #expect(VocabularyDiffEngine.extractCandidates(raw: "", enhanced: "", commonWords: []).isEmpty)
  #expect(VocabularyDiffEngine.extractCandidates(raw: "hello", enhanced: "", commonWords: []).isEmpty)
  #expect(VocabularyDiffEngine.extractCandidates(raw: "", enhanced: "hello", commonWords: []).isEmpty)
 }

 @Test func extractsMultipleCorrections() {
  let candidates = VocabularyDiffEngine.extractCandidates(
   raw: "open the klaud app and use chezmoy",
   enhanced: "open the Claude app and use chezmoi",
   commonWords: Set(["open", "the", "app", "and", "use"])
  )
  #expect(candidates.count == 2)
  let corrections = Set(candidates.map { $0.correctedPhrase })
  #expect(corrections.contains("Claude"))
  #expect(corrections.contains("chezmoi"))
 }

 // MARK: - Filters

 @Test func rejectsCaseOnlyDifference() {
  // "hello" vs "Hello" should be filtered (only capitalization change)
  let candidates = VocabularyDiffEngine.extractCandidates(
   raw: "test hello world",
   enhanced: "test Hello world",
   commonWords: []
  )
  #expect(candidates.isEmpty)
 }

 @Test func rejectsSingleCharTokens() {
  let candidates = VocabularyDiffEngine.extractCandidates(
   raw: "I a test",
   enhanced: "I b test",
   commonWords: []
  )
  #expect(candidates.isEmpty)
 }

 @Test func rejectsInflectionOnlyChange() {
  // "crashed" vs "crashes" should be filtered
  let candidates = VocabularyDiffEngine.extractCandidates(
   raw: "the app crashed today",
   enhanced: "the app crashes today",
   commonWords: Set(["the", "app", "today"])
  )
  #expect(candidates.isEmpty)
 }

 @Test func rejectsHyphenationChange() {
  // "Mac only" vs "Mac-only" should be filtered
  let candidates = VocabularyDiffEngine.extractCandidates(
   raw: "this is Mac only feature",
   enhanced: "this is Mac-only feature",
   commonWords: Set(["this", "is", "feature"])
  )
  #expect(candidates.isEmpty)
 }

 @Test func rejectsPossessiveChange() {
  let candidates = VocabularyDiffEngine.extractCandidates(
   raw: "the users data was lost",
   enhanced: "the user's data was lost",
   commonWords: Set(["the", "data", "was", "lost"])
  )
  #expect(candidates.isEmpty)
 }

 @Test func rejectsShorthandExpansion() {
  // "perf" -> "performance" should be filtered
  let candidates = VocabularyDiffEngine.extractCandidates(
   raw: "check the perf metrics",
   enhanced: "check the performance metrics",
   commonWords: Set(["check", "the", "metrics"])
  )
  #expect(candidates.isEmpty)
 }

 @Test func rejectsExtremeRatioDifference() {
  // Very different lengths should be filtered
  let candidates = VocabularyDiffEngine.extractCandidates(
   raw: "the x was good",
   enhanced: "the extraordinary was good",
   commonWords: Set(["the", "was", "good"])
  )
  #expect(candidates.isEmpty)
 }

 @Test func rejectsAllCommonWordsInCorrectedPhrase() {
  let candidates = VocabularyDiffEngine.extractCandidates(
   raw: "I went too the store",
   enhanced: "I went to the store",
   commonWords: Set(["i", "went", "to", "the", "store", "too"])
  )
  #expect(candidates.isEmpty)
 }

 @Test func rejectsLongRawRuns() {
  // Runs longer than 4 raw tokens should be filtered
  let candidates = VocabularyDiffEngine.extractCandidates(
   raw: "start one two three four five end",
   enhanced: "start alpha beta gamma delta epsilon end",
   commonWords: Set(["start", "end"])
  )
  #expect(candidates.isEmpty)
 }

 // MARK: - Compound Names

 @Test func extractsMultiWordProperNoun() {
  let candidates = VocabularyDiffEngine.extractCandidates(
   raw: "I use klaud kode daily",
   enhanced: "I use Claude Code daily",
   commonWords: Set(["i", "use", "daily"])
  )
  // Both words differ so they form a single correction pair
  let correctedPhrases = candidates.map { $0.correctedPhrase }
  #expect(correctedPhrases.contains("Claude Code"))
 }

 // MARK: - Common Word Trimming

 @Test func trimsLeadingCommonWords() {
  let candidates = VocabularyDiffEngine.extractCandidates(
   raw: "I like mack update app",
   enhanced: "I like MacUpdate app",
   commonWords: Set(["i", "like", "app"])
  )
  // Should find MacUpdate, not "like MacUpdate"
  if let candidate = candidates.first {
   #expect(candidate.correctedPhrase == "MacUpdate")
  }
 }

 // MARK: - Deduplication

 @Test func deduplicatesSameCorrection() {
  // Same correction appearing twice should be deduplicated
  let candidates = VocabularyDiffEngine.extractCandidates(
   raw: "use klaud and then klaud again",
   enhanced: "use Claude and then Claude again",
   commonWords: Set(["use", "and", "then", "again"])
  )
  let claudeCount = candidates.filter { $0.correctedPhrase == "Claude" }.count
  #expect(claudeCount == 1)
 }

 // MARK: - Markdown Stripping

 @Test func handlesMarkdownFormatting() {
  let candidates = VocabularyDiffEngine.extractCandidates(
   raw: "use **klaud** for coding",
   enhanced: "use **Claude** for coding",
   commonWords: Set(["use", "for"])
  )
  #expect(candidates.count == 1)
  #expect(candidates.first?.correctedPhrase == "Claude")
 }

 // MARK: - Diacritics

 @Test func handlesDiacriticInsensitiveMatching() {
  // Tokens are compared after diacritic folding
  let candidates = VocabularyDiffEngine.extractCandidates(
   raw: "the cafe is open",
   enhanced: "the caf\u{00E9} is open",
   commonWords: Set(["the", "is", "open"])
  )
  // "cafe" and "caf\u{00E9}" normalize the same, so this is a case/punctuation only change
  #expect(candidates.isEmpty)
 }

 // MARK: - Phonetic Similarity

 @Test func acceptsPhoneticallySimilarCorrection() {
  // "avalonya" is phonetically similar to "Avalonia" but not a prefix
  let candidates = VocabularyDiffEngine.extractCandidates(
   raw: "I need to use avalonya",
   enhanced: "I need to use Avalonia",
   commonWords: Set(["i", "need", "to", "use"])
  )
  #expect(candidates.count == 1)
  #expect(candidates.first?.correctedPhrase == "Avalonia")
 }

 @Test func rejectsNoPhoneticSimilarity() {
  // Words with no phonetic resemblance should be filtered
  let candidates = VocabularyDiffEngine.extractCandidates(
   raw: "the cat sat here",
   enhanced: "the zebra sat here",
   commonWords: Set(["the", "sat", "here"])
  )
  #expect(candidates.isEmpty)
 }

 // MARK: - Multi-token with word overlap

 @Test func acceptsMultiTokenWithWordOverlap() {
  let candidates = VocabularyDiffEngine.extractCandidates(
   raw: "use voice inc for dictation",
   enhanced: "use VoiceInk for dictation",
   commonWords: Set(["use", "for", "dictation"])
  )
  // "voice inc" -> "VoiceInk" should pass because there's word overlap
  #expect(!candidates.isEmpty)
 }

 // MARK: - Filler Word Rejection

 @Test func rejectsFillerWordsOnRawSide() {
  let candidates = VocabularyDiffEngine.extractCandidates(
   raw: "uh the app is um good",
   enhanced: "the app is good",
   commonWords: Set(["the", "app", "is", "good"])
  )
  // Filler words "uh"/"um" on raw side that don't map to corrections
  // (gap has only filler words but no corresponding enhanced gap)
  #expect(candidates.isEmpty)
 }
}
