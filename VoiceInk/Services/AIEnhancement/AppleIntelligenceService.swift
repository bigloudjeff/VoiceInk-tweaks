import Foundation
import os

#if canImport(FoundationModels)
import FoundationModels
#endif

@available(macOS 26.0, *)
class AppleIntelligenceService {
 private let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "AppleIntelligenceService")

 static let shared = AppleIntelligenceService()

 /// Approximate character limit per chunk.
 /// The on-device model has a 4,096 token context window.
 /// System prompt consumes ~800-1200 tokens, leaving ~2800-3200 for input+output.
 /// At ~4 chars/token, that's ~11,200 chars for input, but we need room for
 /// output too, so we target ~6,000 chars per chunk to be safe.
 private let maxCharsPerChunk = 6000

 var isAvailable: Bool {
  SystemLanguageModel.default.isAvailable
 }

 var availabilityDescription: String {
  switch SystemLanguageModel.default.availability {
  case .available:
   return "Available"
  case .unavailable(let reason):
   switch reason {
   case .deviceNotEligible:
    return "Device not eligible for Apple Intelligence"
   case .appleIntelligenceNotEnabled:
    return "Apple Intelligence is not enabled in System Settings"
   case .modelNotReady:
    return "Model is downloading or not ready"
   @unknown default:
    return "Not available"
   }
  @unknown default:
   return "Unknown availability status"
  }
 }

 func enhance(text: String, systemPrompt: String) async throws -> String {
  guard isAvailable else {
   throw AppleIntelligenceError.notAvailable(availabilityDescription)
  }

  // If text fits in a single chunk, process directly
  if text.count <= maxCharsPerChunk {
   return try await processChunk(text: text, systemPrompt: systemPrompt)
  }

  // Split into chunks at sentence boundaries and process each
  let chunks = splitIntoChunks(text)
  logger.info("Splitting text into \(chunks.count, privacy: .public) chunks for Apple Intelligence")

  var results: [String] = []
  for (index, chunk) in chunks.enumerated() {
   let chunkPrompt = chunks.count > 1
    ? "This is part \(index + 1) of \(chunks.count) of a longer transcript. Clean it up the same way.\n\n\(chunk)"
    : chunk
   let result = try await processChunk(text: chunkPrompt, systemPrompt: systemPrompt)
   results.append(result)
  }

  return results.joined(separator: "\n\n")
 }

 private func processChunk(text: String, systemPrompt: String) async throws -> String {
  let session = LanguageModelSession(
   instructions: Instructions(systemPrompt)
  )
  let response = try await session.respond(to: Prompt(text))
  return response.content
 }

 /// Splits text into chunks at sentence boundaries, respecting maxCharsPerChunk.
 private func splitIntoChunks(_ text: String) -> [String] {
  // Extract content inside <TRANSCRIPT> tags if present
  let content: String
  let hasTranscriptTags: Bool
  if let startRange = text.range(of: "<TRANSCRIPT>"),
     let endRange = text.range(of: "</TRANSCRIPT>") {
   content = String(text[startRange.upperBound..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
   hasTranscriptTags = true
  } else {
   content = text
   hasTranscriptTags = false
  }

  guard content.count > maxCharsPerChunk else {
   return [text]
  }

  // Split on sentence-ending punctuation followed by whitespace
  var chunks: [String] = []
  var currentChunk = ""

  let sentences = content.components(separatedBy: ". ")
  for sentence in sentences {
   let candidate = currentChunk.isEmpty ? sentence : currentChunk + ". " + sentence
   if candidate.count > maxCharsPerChunk && !currentChunk.isEmpty {
    let wrapped = hasTranscriptTags ? "\n<TRANSCRIPT>\n\(currentChunk)\n</TRANSCRIPT>" : currentChunk
    chunks.append(wrapped)
    currentChunk = sentence
   } else {
    currentChunk = candidate
   }
  }

  if !currentChunk.isEmpty {
   let wrapped = hasTranscriptTags ? "\n<TRANSCRIPT>\n\(currentChunk)\n</TRANSCRIPT>" : currentChunk
   chunks.append(wrapped)
  }

  return chunks
 }
}

@available(macOS 26.0, *)
enum AppleIntelligenceError: LocalizedError {
 case notAvailable(String)

 var errorDescription: String? {
  switch self {
  case .notAvailable(let reason):
   return "Apple Intelligence: \(reason)"
  }
 }
}
