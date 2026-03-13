import AppIntents
import AppKit
import Foundation
import os
import SwiftData

struct SetRecordingModeIntent: AppIntent {
 static var title: LocalizedStringResource = "Set VoiceInk Recording Mode"
 static var description = IntentDescription("Set the recording mode: hybrid (hold-to-record), toggle, or hands-free.")

 static var openAppWhenRun: Bool = false

 @Parameter(title: "Mode")
 var mode: String

 @MainActor
 func perform() async throws -> some IntentResult & ProvidesDialog {
  let normalized = mode.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
  let valid = ["hybrid", "toggle", "hands-free"]
  guard valid.contains(normalized) else {
   return .result(dialog: "Invalid mode \"\(mode)\". Use: hybrid, toggle, or hands-free")
  }
  UserDefaults.standard.set(normalized, forKey: UserDefaults.Keys.recordingMode)
  return .result(dialog: "Recording mode set to \(normalized)")
 }
}

struct SetRecorderStyleIntent: AppIntent {
 static var title: LocalizedStringResource = "Set VoiceInk Recorder Style"
 static var description = IntentDescription("Set the recorder style: mini (floating pill) or notch (extends from notch).")

 static var openAppWhenRun: Bool = false

 @Parameter(title: "Style")
 var style: String

 @MainActor
 func perform() async throws -> some IntentResult & ProvidesDialog {
  let normalized = style.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
  guard RecorderStyle(rawValue: normalized) != nil else {
   return .result(dialog: "Invalid style \"\(style)\". Use: mini or notch")
  }
  UserDefaults.standard.set(normalized, forKey: UserDefaults.Keys.recorderType)
  return .result(dialog: "Recorder style set to \(normalized)")
 }
}

struct SetPasteMethodIntent: AppIntent {
 static var title: LocalizedStringResource = "Set VoiceInk Paste Method"
 static var description = IntentDescription("Set the paste method: default, appleScript, or typeOut.")

 static var openAppWhenRun: Bool = false

 @Parameter(title: "Method")
 var method: String

 @MainActor
 func perform() async throws -> some IntentResult & ProvidesDialog {
  let normalized = method.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
  let valid = ["default", "applescript", "typeout"]
  guard valid.contains(normalized) else {
   return .result(dialog: "Invalid method \"\(method)\". Use: default, appleScript, or typeOut")
  }
  let canonical: String
  switch normalized {
  case "applescript": canonical = "appleScript"
  case "typeout": canonical = "typeOut"
  default: canonical = "default"
  }
  UserDefaults.standard.set(canonical, forKey: UserDefaults.Keys.pasteMethod)
  return .result(dialog: "Paste method set to \(canonical)")
 }
}

struct GetStatusIntent: AppIntent {
 static var title: LocalizedStringResource = "Get VoiceInk Status"
 static var description = IntentDescription("Get a summary of current VoiceInk state.")

 static var openAppWhenRun: Bool = false

 @MainActor
 func perform() async throws -> some IntentResult & ProvidesDialog {
  let locator = AppServiceLocator.shared
  var lines: [String] = []
  if let ws = locator.whisperState {
   lines.append("Recording: \(ws.recordingState)")
   lines.append("Model: \(ws.currentTranscriptionModel?.name ?? "none")")
  }
  let lang = UserDefaults.standard.string(forKey: UserDefaults.Keys.selectedLanguage) ?? "auto"
  lines.append("Language: \(lang)")
  if let es = locator.enhancementService {
   lines.append("Enhancement: \(es.enhancementMode.rawValue)")
   lines.append("Prompt: \(es.activePrompt?.title ?? "none")")
  }
  let mode = UserDefaults.standard.string(forKey: UserDefaults.Keys.recordingMode) ?? "hybrid"
  lines.append("Mode: \(mode)")
  return .result(dialog: "\(lines.joined(separator: ", "))")
 }
}

struct ListPromptsIntent: AppIntent {
 static var title: LocalizedStringResource = "List VoiceInk Prompts"
 static var description = IntentDescription("List all available enhancement prompts.")

 static var openAppWhenRun: Bool = false

 @MainActor
 func perform() async throws -> some IntentResult & ProvidesDialog {
  guard let service = AppServiceLocator.shared.enhancementService else {
   throw IntentError.serviceNotAvailable
  }
  let names = service.allPrompts.map { $0.title }
  if names.isEmpty {
   return .result(dialog: "No prompts configured")
  }
  return .result(dialog: "\(names.count) prompts: \(names.joined(separator: ", "))")
 }
}

struct ListPowerModesIntent: AppIntent {
 static var title: LocalizedStringResource = "List VoiceInk Power Modes"
 static var description = IntentDescription("List all available Power Modes.")

 static var openAppWhenRun: Bool = false

 @MainActor
 func perform() async throws -> some IntentResult & ProvidesDialog {
  guard let manager = AppServiceLocator.shared.powerModeProvider else {
   throw IntentError.serviceNotAvailable
  }
  let names = manager.configurations.map { $0.name }
  if names.isEmpty {
   return .result(dialog: "No power modes configured")
  }
  return .result(dialog: "\(names.count) power modes: \(names.joined(separator: ", "))")
 }
}

struct AddWordReplacementIntent: AppIntent {
 static var title: LocalizedStringResource = "Add VoiceInk Word Replacement"
 static var description = IntentDescription("Add a word replacement rule.")

 static var openAppWhenRun: Bool = false

 @Parameter(title: "Original Text")
 var originalText: String

 @Parameter(title: "Replacement Text")
 var replacementText: String

 @MainActor
 func perform() async throws -> some IntentResult & ProvidesDialog {
  guard let container = AppServiceLocator.shared.modelContainer else {
   throw IntentError.serviceNotAvailable
  }
  let context = container.mainContext
  let trimmedOriginal = originalText.trimmingCharacters(in: .whitespacesAndNewlines)
  let trimmedReplacement = replacementText.trimmingCharacters(in: .whitespacesAndNewlines)
  guard !trimmedOriginal.isEmpty, !trimmedReplacement.isEmpty else {
   return .result(dialog: "Both original and replacement text must be non-empty")
  }
  let descriptor = FetchDescriptor<WordReplacement>()
  let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "Intents")
  let existing = context.safeFetch(descriptor, context: "add word replacement", logger: logger)
  if existing.contains(where: { $0.originalText.lowercased() == trimmedOriginal.lowercased() }) {
   return .result(dialog: "Already exists: \(trimmedOriginal)")
  }
  let entry = WordReplacement(originalText: trimmedOriginal, replacementText: trimmedReplacement)
  context.insert(entry)
  try context.save()
  WordReplacementService.shared.invalidateCache()
  return .result(dialog: "Added: \(trimmedOriginal) -> \(trimmedReplacement)")
 }
}

struct RemoveWordReplacementIntent: AppIntent {
 static var title: LocalizedStringResource = "Remove VoiceInk Word Replacement"
 static var description = IntentDescription("Remove a word replacement rule.")

 static var openAppWhenRun: Bool = false

 @Parameter(title: "Original Text")
 var originalText: String

 @MainActor
 func perform() async throws -> some IntentResult & ProvidesDialog {
  guard let container = AppServiceLocator.shared.modelContainer else {
   throw IntentError.serviceNotAvailable
  }
  let context = container.mainContext
  let trimmed = originalText.trimmingCharacters(in: .whitespacesAndNewlines)
  let descriptor = FetchDescriptor<WordReplacement>()
  let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "Intents")
  let items = context.safeFetch(descriptor, context: "remove word replacement", logger: logger)
  guard let match = items.first(where: { $0.originalText.lowercased() == trimmed.lowercased() }) else {
   return .result(dialog: "Not found: \(trimmed)")
  }
  context.delete(match)
  try context.save()
  WordReplacementService.shared.invalidateCache()
  return .result(dialog: "Removed: \(trimmed)")
 }
}

struct CopyLastTranscriptionIntent: AppIntent {
 static var title: LocalizedStringResource = "Copy Last VoiceInk Transcription"
 static var description = IntentDescription("Copy the most recent transcription to clipboard.")

 static var openAppWhenRun: Bool = false

 @MainActor
 func perform() async throws -> some IntentResult & ProvidesDialog {
  guard let container = AppServiceLocator.shared.modelContainer else {
   throw IntentError.serviceNotAvailable
  }
  let context = container.mainContext
  guard let transcription = LastTranscriptionService.getLastTranscription(from: context) else {
   return .result(dialog: "No transcriptions found")
  }
  let text = transcription.enhancedText ?? transcription.text
  NSPasteboard.general.clearContents()
  NSPasteboard.general.setString(text, forType: .string)
  return .result(dialog: "Copied to clipboard")
 }
}
