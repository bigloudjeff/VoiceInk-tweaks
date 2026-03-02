import Foundation

struct VocabularyCandidate: Hashable {
 let rawPhrase: String
 let correctedPhrase: String
}

struct VocabularyDiffEngine {

 static func extractCandidates(raw: String, enhanced: String, commonWords: Set<String>) -> [VocabularyCandidate] {
  let rawTokens = tokenize(raw)
  let enhancedTokens = tokenize(enhanced)

  guard !rawTokens.isEmpty, !enhancedTokens.isEmpty else { return [] }

  let lcsIndices = longestCommonSubsequence(rawTokens.map { $0.normalized }, enhancedTokens.map { $0.normalized })

  var corrections = extractCorrections(rawTokens: rawTokens, enhancedTokens: enhancedTokens, lcs: lcsIndices)

  expandCompoundNames(corrections: &corrections, enhancedTokens: enhancedTokens, lcs: lcsIndices)

  // Trim leading/trailing common words from corrections
  if !commonWords.isEmpty {
   trimCommonWords(corrections: &corrections, commonWords: commonWords)
  }

  var seen = Set<String>()
  return corrections.compactMap { correction -> VocabularyCandidate? in
   let rawPhrase = correction.raw.map { $0.cleaned }.joined(separator: " ")
   let correctedPhrase = correction.enhanced.map { $0.cleaned }.joined(separator: " ")

   guard !rawPhrase.isEmpty, !correctedPhrase.isEmpty else { return nil }

   guard passesFilters(raw: correction.raw, enhanced: correction.enhanced, rawPhrase: rawPhrase, correctedPhrase: correctedPhrase, commonWords: commonWords) else {
    return nil
   }

   let key = correctedPhrase.lowercased()
   guard !seen.contains(key) else { return nil }
   seen.insert(key)

   return VocabularyCandidate(rawPhrase: rawPhrase, correctedPhrase: correctedPhrase)
  }
 }

 // MARK: - Tokenization

 private struct Token {
  let original: String
  let normalized: String // lowercased, stripped of punctuation (for comparison)
  let cleaned: String    // original casing, stripped of leading/trailing punctuation (for output)
 }

 private static func tokenize(_ text: String) -> [Token] {
  let stripped = stripMarkdownFormatting(text)
  return stripped.split(omittingEmptySubsequences: true, whereSeparator: { $0.isWhitespace })
   .map { substring -> Token in
    let original = String(substring)
    let normalized = original
     .lowercased()
     .trimmingCharacters(in: .punctuationCharacters)
    let cleaned = original
     .trimmingCharacters(in: .punctuationCharacters)
    return Token(original: original, normalized: normalized, cleaned: cleaned)
   }
   .filter { !$0.normalized.isEmpty }
 }

 private static func stripMarkdownFormatting(_ text: String) -> String {
  var result = text
  // Remove bullet points (*, -, bullet) at start of lines
  result = result.replacingOccurrences(of: "(?m)^\\s*[*\\-\u{2022}]\\s+", with: " ", options: .regularExpression)
  // Remove numbered list markers at start of lines
  result = result.replacingOccurrences(of: "(?m)^\\s*\\d+\\.\\s+", with: " ", options: .regularExpression)
  // Remove markdown bold/italic markers
  result = result.replacingOccurrences(of: "[*_]{1,3}", with: "", options: .regularExpression)
  return result
 }

 // MARK: - LCS

 private struct LCSPair {
  let rawIndex: Int
  let enhancedIndex: Int
 }

 private static func longestCommonSubsequence(_ a: [String], _ b: [String]) -> [LCSPair] {
  let m = a.count
  let n = b.count
  guard m > 0, n > 0 else { return [] }
  var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)

  for i in 1...m {
   for j in 1...n {
    if a[i - 1] == b[j - 1] {
     dp[i][j] = dp[i - 1][j - 1] + 1
    } else {
     dp[i][j] = max(dp[i - 1][j], dp[i][j - 1])
    }
   }
  }

  var pairs: [LCSPair] = []
  var i = m, j = n
  while i > 0 && j > 0 {
   if a[i - 1] == b[j - 1] {
    pairs.append(LCSPair(rawIndex: i - 1, enhancedIndex: j - 1))
    i -= 1
    j -= 1
   } else if dp[i - 1][j] > dp[i][j - 1] {
    i -= 1
   } else {
    j -= 1
   }
  }

  return pairs.reversed()
 }

 // MARK: - Correction Extraction

 private struct CorrectionPair {
  var raw: [Token]
  var enhanced: [Token]
  var enhancedStartIndex: Int
 }

 private static func extractCorrections(rawTokens: [Token], enhancedTokens: [Token], lcs: [LCSPair]) -> [CorrectionPair] {
  var corrections: [CorrectionPair] = []
  var rawPos = 0
  var enhancedPos = 0

  for pair in lcs {
   let rawGap = Array(rawTokens[rawPos..<pair.rawIndex])
   let enhancedGap = Array(enhancedTokens[enhancedPos..<pair.enhancedIndex])

   if !rawGap.isEmpty && !enhancedGap.isEmpty {
    corrections.append(CorrectionPair(raw: rawGap, enhanced: enhancedGap, enhancedStartIndex: enhancedPos))
   }

   rawPos = pair.rawIndex + 1
   enhancedPos = pair.enhancedIndex + 1
  }

  let rawGap = Array(rawTokens[rawPos...])
  let enhancedGap = Array(enhancedTokens[enhancedPos...])
  if !rawGap.isEmpty && !enhancedGap.isEmpty {
   corrections.append(CorrectionPair(raw: rawGap, enhanced: enhancedGap, enhancedStartIndex: enhancedPos))
  }

  return corrections
 }

 // MARK: - Compound Name Expansion

 /// When a correction produces a capitalized word like "Claude", check if the
 /// next LCS-matched token is also capitalized (e.g. "Code") and absorb it
 /// to form the full proper noun "Claude Code".
 private static func expandCompoundNames(corrections: inout [CorrectionPair], enhancedTokens: [Token], lcs: [LCSPair]) {
  let matchedEnhancedIndices = Set(lcs.map { $0.enhancedIndex })

  for i in corrections.indices {
   let correction = corrections[i]

   // Only expand if the corrected phrase contains at least one capitalized word
   guard correction.enhanced.contains(where: { $0.cleaned.first?.isUppercase == true }) else { continue }

   // Look at tokens immediately following this correction in the enhanced text
   let enhancedEndIndex = correction.enhancedStartIndex + correction.enhanced.count
   var expandedEnhanced = correction.enhanced
   var nextIndex = enhancedEndIndex

   while nextIndex < enhancedTokens.count {
    // Stop at sentence boundaries -- if the last token ends with . ! ? then the
    // next capitalized word is a new sentence, not part of a compound name
    if let lastOriginal = expandedEnhanced.last?.original,
       let lastChar = lastOriginal.last,
       ".!?".contains(lastChar) {
     break
    }
    let nextToken = enhancedTokens[nextIndex]
    // Only absorb LCS-matched tokens that continue a proper noun phrase (capitalized)
    guard matchedEnhancedIndices.contains(nextIndex),
          nextToken.cleaned.first?.isUppercase == true else { break }
    expandedEnhanced.append(nextToken)
    nextIndex += 1
   }

   if expandedEnhanced.count > correction.enhanced.count {
    corrections[i].enhanced = expandedEnhanced
   }
  }
 }

 // MARK: - Common Word Trimming

 /// Strips leading and trailing common words from corrections so that
 /// "like MacUpdate" becomes just "MacUpdate" and "for there's Mac update"
 /// gets cleaned up on the raw side too.
 private static func trimCommonWords(corrections: inout [CorrectionPair], commonWords: Set<String>) {
  for i in corrections.indices {
   var enhanced = corrections[i].enhanced
   var raw = corrections[i].raw

   // Trim leading common words from enhanced side
   while enhanced.count > 1, commonWords.contains(enhanced[0].normalized) {
    enhanced.removeFirst()
   }
   // Trim trailing common words from enhanced side
   while enhanced.count > 1, commonWords.contains(enhanced[enhanced.count - 1].normalized) {
    enhanced.removeLast()
   }
   // Trim leading common words from raw side
   while raw.count > 1, commonWords.contains(raw[0].normalized) {
    raw.removeFirst()
   }
   // Trim trailing common words from raw side
   while raw.count > 1, commonWords.contains(raw[raw.count - 1].normalized) {
    raw.removeLast()
   }

   corrections[i].enhanced = enhanced
   corrections[i].raw = raw
  }
 }

 // MARK: - Filters

 private static let fillerWords: Set<String> = Set(FillerWordManager.defaultFillerWords)

 private static func passesFilters(raw: [Token], enhanced: [Token], rawPhrase: String, correctedPhrase: String, commonWords: Set<String>) -> Bool {
  // Skip if raw and corrected are identical (case-insensitive)
  if rawPhrase.lowercased() == correctedPhrase.lowercased() {
   return false
  }

  // Skip runs longer than 4 raw tokens or 6 enhanced tokens
  // (enhanced limit is higher to accommodate compound proper nouns from expansion)
  if raw.count > 4 || enhanced.count > 6 {
   return false
  }

  // Skip single-character tokens (both sides)
  if raw.count == 1 && raw[0].normalized.count <= 1 {
   return false
  }
  if enhanced.count == 1 && enhanced[0].normalized.count <= 1 {
   return false
  }

  // Skip if raw tokens are all common filler words
  if raw.allSatisfy({ fillerWords.contains($0.normalized) }) {
   return false
  }

  // Skip if correction is only punctuation/capitalization difference
  if isOnlyPunctuationOrCapitalizationChange(raw: raw, enhanced: enhanced) {
   return false
  }

  // Skip if the only difference is hyphenation (e.g. "Mac only" vs "Mac-only")
  if isOnlyHyphenationChange(raw: raw, enhanced: enhanced) {
   return false
  }

  // Skip if the only difference is possessive form (e.g. "users" vs "user's")
  if isOnlyPossessiveChange(raw: raw, enhanced: enhanced) {
   return false
  }

  // Skip if ALL words in the corrected phrase are common words.
  // Vocabulary suggestions should be for terms Whisper doesn't know --
  // proper nouns, brand names, technical jargon -- not common rephrasing.
  if !commonWords.isEmpty && enhanced.allSatisfy({ commonWords.contains($0.normalized) }) {
   return false
  }

  // Skip if ALL words in the raw phrase are common words.
  // If Whisper produced only common words, it didn't mishear a
  // vocabulary term -- the AI is just rephrasing or inserting content.
  if !commonWords.isEmpty && raw.allSatisfy({ commonWords.contains($0.normalized) }) {
   return false
  }

  // Skip inflection-only changes (updates/update, crashed/crashes, clicking/click)
  if isOnlyInflectionChange(raw: raw, enhanced: enhanced) {
   return false
  }

  // Skip shorthand expansion -- when a single raw word is a prefix of the
  // corrected word, the AI is expanding an abbreviation (perf -> performance),
  // not correcting a mishearing. Real corrections change the word, not extend it.
  if raw.count == 1 && enhanced.count == 1 && isShorthandExpansion(raw: raw[0], enhanced: enhanced[0]) {
   return false
  }

  // Skip when raw and corrected have no phonetic resemblance --
  // this means the AI rewrote the sentence rather than correcting a mishearing
  if raw.count <= 2 && enhanced.count <= 2 && !hasPhoneticSimilarity(rawPhrase: rawPhrase, correctedPhrase: correctedPhrase) {
   return false
  }

  // Skip multi-token corrections where raw and enhanced share no words --
  // this indicates the AI rewrote the phrase rather than correcting a mishearing.
  // Allow through if the overall phrases are phonetically similar (e.g. "Quinn3B" -> "Qwen 3B").
  if (raw.count + enhanced.count) >= 3 && !hasWordOverlap(raw: raw, enhanced: enhanced) && !hasPhoneticSimilarity(rawPhrase: rawPhrase, correctedPhrase: correctedPhrase) {
   return false
  }

  // Skip when character length ratio is extreme (e.g. "easily" vs "within the Espanzo plugin")
  let rawLen = rawPhrase.count
  let correctedLen = correctedPhrase.count
  if rawLen > 0 && correctedLen > 0 {
   let ratio = Double(max(rawLen, correctedLen)) / Double(min(rawLen, correctedLen))
   if ratio > 3.0 {
    return false
   }
  }

  return true
 }

 private static func isOnlyPunctuationOrCapitalizationChange(raw: [Token], enhanced: [Token]) -> Bool {
  guard raw.count == enhanced.count else { return false }
  for (r, e) in zip(raw, enhanced) {
   if r.normalized != e.normalized {
    return false
   }
  }
  return true
 }

 /// Detects "Mac only" vs "Mac-only" or "platform specific" vs "platform-specific"
 private static func isOnlyHyphenationChange(raw: [Token], enhanced: [Token]) -> Bool {
  let rawJoined = raw.map { $0.normalized.replacingOccurrences(of: "-", with: "") }.joined()
  let enhancedJoined = enhanced.map { $0.normalized.replacingOccurrences(of: "-", with: "") }.joined()
  return rawJoined == enhancedJoined
 }

 /// Detects "users" vs "user's" or "apps" vs "app's"
 private static func isOnlyPossessiveChange(raw: [Token], enhanced: [Token]) -> Bool {
  guard raw.count == 1, enhanced.count == 1 else { return false }
  let r = raw[0].normalized
  let e = enhanced[0].normalized.replacingOccurrences(of: "'s", with: "s")
  return r == e
 }

 /// Detects inflection-only changes by comparing word stems.
 /// Catches: crashed/crashes, quantify/quantified, improved/improvements,
 /// auto-detecting/auto-detection, click/clicking.
 private static func isOnlyInflectionChange(raw: [Token], enhanced: [Token]) -> Bool {
  guard raw.count == 1, enhanced.count == 1 else { return false }
  let r = raw[0].normalized.replacingOccurrences(of: "-", with: "")
  let e = enhanced[0].normalized.replacingOccurrences(of: "-", with: "")
  guard r != e else { return false }

  let rStems = Set(inflectionalStems(r))
  let eStems = Set(inflectionalStems(e))
  return !rStems.isDisjoint(with: eStems)
 }

 private static func inflectionalStems(_ word: String) -> [String] {
  var stems = [word]
  let suffixes = ["ments", "ment", "ation", "tion", "sion", "ion",
                  "ness", "ings", "ing", "ied", "ies", "ers",
                  "ed", "es", "er", "ly", "s", "d"]
  for suffix in suffixes {
   guard word.hasSuffix(suffix), word.count - suffix.count >= 3 else { continue }
   let stem = String(word.dropLast(suffix.count))
   stems.append(stem)
   stems.append(stem + "e")
   if suffix == "ied" || suffix == "ies" {
    stems.append(stem + "y")
   }
  }
  return stems
 }

 /// Detects shorthand expansion: raw word is a prefix of the corrected word
 /// (e.g. "perf" -> "performance", "repro" -> "reproduce").
 /// Excludes cases where the raw word is very short (<=2 chars) since those
 /// could be genuine mishearings, and cases where the corrected word has
 /// different casing (proper nouns like "Inator" -> "Typinator").
 private static func isShorthandExpansion(raw: Token, enhanced: Token) -> Bool {
  let r = raw.normalized
  let e = enhanced.normalized
  guard r.count > 2 else { return false }

  // If the corrected word starts with the raw word, it's likely expansion
  if e.hasPrefix(r) && e.count > r.count {
   // Exception: if the corrected word has internal capitalization
   // it's a proper noun (e.g. "Voice" -> "VoiceInk")
   if enhanced.cleaned.dropFirst().contains(where: { $0.isUppercase }) {
    return false
   }
   return true
  }
  return false
 }

 /// Checks if raw and corrected phrases share enough phonetic resemblance
 /// to suggest a genuine mishearing rather than an AI rewrite.
 private static func hasPhoneticSimilarity(rawPhrase: String, correctedPhrase: String) -> Bool {
  let r = rawPhrase.lowercased()
  let e = correctedPhrase.lowercased()

  if r.count >= 2 && e.count >= 2 && r.prefix(2) == e.prefix(2) {
   return true
  }

  if r.count >= 3 && e.contains(r) {
   return true
  }
  if e.count >= 3 && r.contains(e) {
   return true
  }

  let distance = levenshteinDistance(r, e)
  let maxLen = max(r.count, e.count)
  if maxLen > 0 && Double(distance) / Double(maxLen) < 0.6 {
   return true
  }

  return false
 }

 /// Checks if any word from the raw side overlaps with any word from
 /// the enhanced side (same word, shared stem, substring, or close phonetic match).
 private static func hasWordOverlap(raw: [Token], enhanced: [Token]) -> Bool {
  for r in raw {
   for e in enhanced {
    if r.normalized == e.normalized { return true }
    if r.normalized.count >= 3 && e.normalized.contains(r.normalized) { return true }
    if e.normalized.count >= 3 && r.normalized.contains(e.normalized) { return true }
    let rStems = Set(inflectionalStems(r.normalized))
    let eStems = Set(inflectionalStems(e.normalized))
    if !rStems.isDisjoint(with: eStems) { return true }
    // Per-word phonetic similarity (tight threshold to avoid false positives)
    if r.normalized.count >= 3 && e.normalized.count >= 3 {
     let dist = levenshteinDistance(r.normalized, e.normalized)
     let maxLen = max(r.normalized.count, e.normalized.count)
     if maxLen > 0 && Double(dist) / Double(maxLen) < 0.4 { return true }
    }
   }
  }
  return false
 }

 private static func levenshteinDistance(_ a: String, _ b: String) -> Int {
  let a = Array(a)
  let b = Array(b)
  let m = a.count
  let n = b.count

  if m == 0 { return n }
  if n == 0 { return m }

  var prev = Array(0...n)
  var curr = Array(repeating: 0, count: n + 1)

  for i in 1...m {
   curr[0] = i
   for j in 1...n {
    let cost = a[i - 1] == b[j - 1] ? 0 : 1
    curr[j] = min(prev[j] + 1, curr[j - 1] + 1, prev[j - 1] + cost)
   }
   prev = curr
  }
  return prev[n]
 }
}
