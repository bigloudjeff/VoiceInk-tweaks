import Foundation
import os

struct TranscriptionOutputFilter {
 private static let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "TranscriptionOutputFilter")

 private static let tagBlockRegex = try? NSRegularExpression(pattern: #"<([A-Za-z][A-Za-z0-9:_-]*)[^>]*>[\s\S]*?</\1>"#)
 private static let hallucinationRegexes: [NSRegularExpression] = {
  [#"\[.*?\]"#, #"\(.*?\)"#, #"\{.*?\}"#].compactMap { try? NSRegularExpression(pattern: $0) }
 }()

 private static var fillerWordRegexCache: [String: NSRegularExpression] = [:]

 static func invalidateFillerWordCache() {
  fillerWordRegexCache.removeAll()
 }

 static func filter(_ text: String, fillerWordProvider: FillerWordProviding = FillerWordManager.shared) -> String {
  var filteredText = text

  // Strip prompt echo -- whisper can echo the transcription prompt when there's
  // silence or very short audio.
  filteredText = stripPromptEcho(from: filteredText)

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

 /// Detect and strip whisper prompt echo from transcription output.
 static func stripPromptEcho(from text: String) -> String {
  let prompt = UserDefaults.standard.string(forKey: UserDefaults.Keys.transcriptionPrompt) ?? ""
  guard !prompt.isEmpty else { return text }

  let normalizedText = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
  let normalizedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

  guard !normalizedText.isEmpty else { return text }

  if normalizedText == normalizedPrompt {
   logger.notice("Stripped prompt echo (exact match)")
   return ""
  }

  if normalizedPrompt.contains(normalizedText) {
   logger.notice("Stripped prompt echo (output is substring of prompt)")
   return ""
  }

  if normalizedText.contains(normalizedPrompt) {
   let promptRatio = Double(normalizedPrompt.count) / Double(normalizedText.count)
   if promptRatio > 0.8 {
    let stripped = normalizedText.replacingOccurrences(of: normalizedPrompt, with: "")
     .trimmingCharacters(in: .whitespacesAndNewlines)
    logger.notice("Stripped prompt echo (prompt embedded in output, ratio: \(promptRatio, privacy: .public))")
    return stripped
   }
  }

  return text
 }

 /// Remove filler words from text. Parameterized for testability.
 static func removeFillerWords(from text: String, isEnabled: Bool, fillerWords: [String]) -> String {
  guard isEnabled, !fillerWords.isEmpty else { return text }
  var result = text
  for fillerWord in fillerWords {
   let regex: NSRegularExpression
   if let cached = fillerWordRegexCache[fillerWord] {
    regex = cached
   } else {
    let pattern = "\\b\(NSRegularExpression.escapedPattern(for: fillerWord))\\b[,.]?"
    guard let compiled = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
    fillerWordRegexCache[fillerWord] = compiled
    regex = compiled
   }
   let range = NSRange(result.startIndex..., in: result)
   result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "")
  }
  return result
 }
}
