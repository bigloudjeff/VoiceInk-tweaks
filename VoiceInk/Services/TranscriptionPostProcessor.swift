import Foundation
import SwiftData

/// Consolidates the post-transcription text pipeline:
/// output filter -> trim -> text formatting -> word replacement.
///
/// All transcription paths (TranscriptionOrchestrator,
/// AudioTranscriptionManager) share
/// this identical sequence. Changes to the pipeline order or steps
/// only need to happen here.
struct TranscriptionPostProcessor {
 struct Result {
  let text: String
  /// The raw transcript before any processing.
  let rawTranscript: String
  /// Whether the output filter changed the text.
  let outputFilterApplied: Bool
 }

 static func process(_ text: String, modelContext: ModelContext) -> Result {
  let rawTranscript = text

  var processed = TranscriptionOutputFilter.filter(text)
  let outputFilterApplied = (processed != rawTranscript)

  processed = processed.trimmingCharacters(in: .whitespacesAndNewlines)

  if UserDefaults.standard.bool(forKey: UserDefaults.Keys.isTextFormattingEnabled) {
   processed = WhisperTextFormatter.format(processed)
  }

  processed = WordReplacementService.shared.applyReplacements(to: processed, using: modelContext)

  return Result(
   text: processed,
   rawTranscript: rawTranscript,
   outputFilterApplied: outputFilterApplied
  )
 }
}
