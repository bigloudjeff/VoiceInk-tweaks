import Foundation
import os

struct TranscriptionOutputFilter {
 private static let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "TranscriptionOutputFilter")

 private static let tagBlockRegex = try? NSRegularExpression(pattern: #"<([A-Za-z][A-Za-z0-9:_-]*)[^>]*>[\s\S]*?</\1>"#)
 private static let hallucinationRegexes: [NSRegularExpression] = {
  [#"\[.*?\]"#, #"\(.*?\)"#, #"\{.*?\}"#].compactMap { try? NSRegularExpression(pattern: $0) }
 }()

 static func filter(_ text: String, fillerWordProvider: FillerWordProviding = FillerWordManager.shared) -> String {
  var filteredText = text

  // Remove <TAG>...</TAG> blocks (if enabled)
  if UserDefaults.standard.bool(forKey: UserDefaults.Keys.removeTagBlocks),
     let regex = tagBlockRegex {
   let range = NSRange(filteredText.startIndex..., in: filteredText)
   filteredText = regex.stringByReplacingMatches(in: filteredText, options: [], range: range, withTemplate: "")
  }

  // Remove bracketed hallucinations (if enabled)
  if UserDefaults.standard.bool(forKey: UserDefaults.Keys.removeBracketedContent) {
   for regex in hallucinationRegexes {
    let range = NSRange(filteredText.startIndex..., in: filteredText)
    filteredText = regex.stringByReplacingMatches(in: filteredText, options: [], range: range, withTemplate: "")
   }
  }

  // Remove filler words (if enabled)
  filteredText = removeFillerWords(from: filteredText, isEnabled: fillerWordProvider.isEnabled, fillerWords: fillerWordProvider.fillerWords)

  // Clean whitespace
  filteredText = filteredText.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
  filteredText = filteredText.trimmingCharacters(in: .whitespacesAndNewlines)

  // Log results
  if filteredText != text {
   logger.notice(" Output filter result: \(filteredText, privacy: .private)")
  } else {
   logger.notice(" Output filter result (unchanged): \(filteredText, privacy: .private)")
  }

  return filteredText
 }

 /// Remove filler words from text. Parameterized for testability.
 static func removeFillerWords(from text: String, isEnabled: Bool, fillerWords: [String]) -> String {
  guard isEnabled, !fillerWords.isEmpty else { return text }
  var result = text
  for fillerWord in fillerWords {
   let pattern = "\\b\(NSRegularExpression.escapedPattern(for: fillerWord))\\b[,.]?"
   if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
    let range = NSRange(result.startIndex..., in: result)
    result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "")
   }
  }
  return result
 }
}
