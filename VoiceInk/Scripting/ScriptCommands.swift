import Cocoa
import Foundation
import os
import SwiftData

class ToggleRecordingCommand: NSScriptCommand {
 override func performDefaultImplementation() -> Any? {
  NotificationCenter.default.post(name: .toggleMiniRecorder, object: nil)
  return "Recorder toggled"
 }
}

class DismissRecorderCommand: NSScriptCommand {
 override func performDefaultImplementation() -> Any? {
  NotificationCenter.default.post(name: .dismissMiniRecorder, object: nil)
  return "Recorder dismissed"
 }
}

class ToggleEnhancementCommand: NSScriptCommand {
 override func performDefaultImplementation() -> Any? {
  return MainActor.assumeIsolated {
   guard let service = AppServiceLocator.shared.enhancementService else {
    return "Service not available"
   }
   service.isEnhancementEnabled.toggle()
   let state = service.isEnhancementEnabled ? "enabled" : "disabled"
   return "Enhancement \(state)"
  }
 }
}

class SetEnhancementModeCommand: NSScriptCommand {
 override func performDefaultImplementation() -> Any? {
  guard let modeStr = directParameter as? String else {
   return "Error: mode parameter required (off, on, background)"
  }
  return MainActor.assumeIsolated {
   guard let service = AppServiceLocator.shared.enhancementService else {
    return "Service not available"
   }
   switch modeStr.lowercased() {
   case "off":
    service.enhancementMode = .off
   case "on":
    service.enhancementMode = .on
   case "background":
    service.enhancementMode = .off
    service.backgroundEnhancementEnabled = true
   default:
    return "Error: invalid mode \"\(modeStr)\". Use off, on, or background."
   }
   return "Enhancement mode set to \(modeStr.lowercased())"
  }
 }
}

class SelectPromptCommand: NSScriptCommand {
 override func performDefaultImplementation() -> Any? {
  guard let promptName = directParameter as? String else {
   return "Error: prompt name parameter required"
  }
  return MainActor.assumeIsolated {
   guard let service = AppServiceLocator.shared.enhancementService else {
    return "Service not available"
   }
   let normalized = promptName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
   if let prompt = service.allPrompts.first(where: { $0.title.lowercased() == normalized }) {
    service.selectedPromptId = prompt.id
    if !service.isEnhancementEnabled {
     service.enhancementMode = .on
    }
    return prompt.title
   } else {
    let available = service.allPrompts.map { $0.title }.joined(separator: ", ")
    return "Error: prompt \"\(promptName)\" not found. Available: \(available)"
   }
  }
 }
}

class ActivatePowerModeCommand: NSScriptCommand {
 override func performDefaultImplementation() -> Any? {
  guard let name = directParameter as? String else {
   return "Error: Power Mode name parameter required"
  }
  return MainActor.assumeIsolated {
   let locator = AppServiceLocator.shared
   guard let manager = locator.powerModeProvider else {
    return "Service not available"
   }
   let normalized = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
   guard let config = manager.configurations.first(where: { $0.name.lowercased() == normalized }) else {
    let available = manager.configurations.map { $0.name }.joined(separator: ", ")
    return "Error: Power Mode \"\(name)\" not found. Available: \(available)"
   }
   guard let whisperState = locator.whisperState,
         let enhancementService = locator.enhancementService else {
    return "Service not available"
   }
   let sessionManager = PowerModeSessionManager.shared
   sessionManager.configure(whisperState: whisperState, enhancementService: enhancementService)
   Task { @MainActor in
    await sessionManager.beginSession(with: config)
    manager.setActiveConfiguration(config)
   }
   return "Power Mode \"\(config.name)\" activating"
  }
 }
}

class DeactivatePowerModeCommand: NSScriptCommand {
 override func performDefaultImplementation() -> Any? {
  return MainActor.assumeIsolated {
   let locator = AppServiceLocator.shared
   let sessionManager = PowerModeSessionManager.shared
   guard sessionManager.hasActiveSession else {
    return "No Power Mode active"
   }
   guard let whisperState = locator.whisperState,
         let enhancementService = locator.enhancementService else {
    return "Service not available"
   }
   sessionManager.configure(whisperState: whisperState, enhancementService: enhancementService)
   Task { @MainActor in
    await sessionManager.endSession()
    locator.powerModeProvider?.setActiveConfiguration(nil)
   }
   return "Power Mode deactivating"
  }
 }
}

class ToggleScreenContextCommand: NSScriptCommand {
 override func performDefaultImplementation() -> Any? {
  return MainActor.assumeIsolated {
   guard let service = AppServiceLocator.shared.enhancementService else {
    return "Service not available"
   }
   service.useScreenCaptureContext.toggle()
   let state = service.useScreenCaptureContext ? "enabled" : "disabled"
   return "Screen context \(state)"
  }
 }
}

class ToggleClipboardContextCommand: NSScriptCommand {
 override func performDefaultImplementation() -> Any? {
  return MainActor.assumeIsolated {
   guard let service = AppServiceLocator.shared.enhancementService else {
    return "Service not available"
   }
   service.useClipboardContext.toggle()
   let state = service.useClipboardContext ? "enabled" : "disabled"
   return "Clipboard context \(state)"
  }
 }
}

class GetLastTranscriptionCommand: NSScriptCommand {
 override func performDefaultImplementation() -> Any? {
  return MainActor.assumeIsolated {
   guard let container = AppServiceLocator.shared.modelContainer else {
    return "Service not available"
   }
   let context = container.mainContext
   guard let transcription = LastTranscriptionService.getLastTranscription(from: context) else {
    return "No transcriptions found"
   }
   return transcription.enhancedText ?? transcription.text
  }
 }
}

class SetLanguageCommand: NSScriptCommand {
 override func performDefaultImplementation() -> Any? {
  guard let code = directParameter as? String else {
   return "Error: language code parameter required"
  }
  let trimmed = code.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
  guard PredefinedModels.allLanguages.keys.contains(trimmed) else {
   return "Error: unknown language code \"\(trimmed)\". Use a valid ISO 639-1 code (e.g. en, es, fr, de, ja) or \"auto\"."
  }
  UserDefaults.standard.set(trimmed, forKey: UserDefaults.Keys.selectedLanguage)
  NotificationCenter.default.post(name: .languageDidChange, object: nil)
  return trimmed
 }
}

class ShowWindowCommand: NSScriptCommand {
 override func performDefaultImplementation() -> Any? {
  return MainActor.assumeIsolated {
   guard let menuBarManager = AppServiceLocator.shared.menuBarManager else {
    return "Service not available"
   }
   menuBarManager.focusMainWindow()
   if let destination = directParameter as? String, !destination.isEmpty {
    if let nav = NavigationDestination(legacyString: destination) {
     nav.post()
    }
    return "Showing \(destination)"
   }
   return "Main window shown"
  }
 }
}

class ShowHistoryCommand: NSScriptCommand {
 override func performDefaultImplementation() -> Any? {
  return MainActor.assumeIsolated {
   guard let container = AppServiceLocator.shared.modelContainer,
         let whisperState = AppServiceLocator.shared.whisperState else {
    return "Service not available"
   }
   HistoryWindowController.shared.showHistoryWindow(
    modelContainer: container,
    whisperState: whisperState
   )
   return "History window opened"
  }
 }
}

class AddVocabularyCommand: NSScriptCommand {
 override func performDefaultImplementation() -> Any? {
  guard let input = directParameter as? String else {
   return "Error: word parameter required"
  }
  return MainActor.assumeIsolated {
   guard let container = AppServiceLocator.shared.modelContainer else {
    return "Service not available"
   }
   let hints = evaluatedArguments?["phoneticHints"] as? String
   let result = CustomVocabularyService.shared.addWords(input, phoneticHints: hints, in: container)
   var parts: [String] = []
   if !result.added.isEmpty {
    parts.append("Added: \(result.added.joined(separator: ", "))")
   }
   if !result.duplicates.isEmpty {
    parts.append("Already exists: \(result.duplicates.joined(separator: ", "))")
   }
   return parts.isEmpty ? "No words to add" : parts.joined(separator: ". ")
  }
 }
}

class RemoveVocabularyCommand: NSScriptCommand {
 override func performDefaultImplementation() -> Any? {
  guard let word = directParameter as? String else {
   return "Error: word parameter required"
  }
  return MainActor.assumeIsolated {
   guard let container = AppServiceLocator.shared.modelContainer else {
    return "Service not available"
   }
   if CustomVocabularyService.shared.removeWord(word, from: container) {
    return "Removed: \(word)"
   } else {
    return "Not found: \(word)"
   }
  }
 }
}

class ListVocabularyCommand: NSScriptCommand {
 override func performDefaultImplementation() -> Any? {
  return MainActor.assumeIsolated {
   guard let container = AppServiceLocator.shared.modelContainer else {
    return "Service not available"
   }
   let words = CustomVocabularyService.shared.listWords(from: container)
   if words.isEmpty {
    return "No vocabulary words"
   }
   return words.joined(separator: ", ")
  }
 }
}

// MARK: - Query Commands

class ListPromptsCommand: NSScriptCommand {
 override func performDefaultImplementation() -> Any? {
  return MainActor.assumeIsolated {
   guard let service = AppServiceLocator.shared.enhancementService else {
    return "Service not available"
   }
   let names = service.allPrompts.map { $0.title }
   return names.isEmpty ? "No prompts" : names.joined(separator: ", ")
  }
 }
}

class ListPowerModesCommand: NSScriptCommand {
 override func performDefaultImplementation() -> Any? {
  return MainActor.assumeIsolated {
   guard let manager = AppServiceLocator.shared.powerModeProvider else {
    return "Service not available"
   }
   let names = manager.configurations.map { config in
    let status = config.isEnabled ? "" : " (disabled)"
    return "\(config.name)\(status)"
   }
   return names.isEmpty ? "No power modes" : names.joined(separator: ", ")
  }
 }
}

class ListModelsCommand: NSScriptCommand {
 override func performDefaultImplementation() -> Any? {
  return MainActor.assumeIsolated {
   guard let whisperState = AppServiceLocator.shared.whisperState else {
    return "Service not available"
   }
   let models = whisperState.allAvailableModels.map { $0.name }
   return models.isEmpty ? "No models" : models.joined(separator: ", ")
  }
 }
}

class ListLanguagesCommand: NSScriptCommand {
 override func performDefaultImplementation() -> Any? {
  let languages = PredefinedModels.allLanguages
   .sorted { $0.value < $1.value }
   .map { "\($0.key): \($0.value)" }
  return languages.joined(separator: ", ")
 }
}

class GetStatusCommand: NSScriptCommand {
 override func performDefaultImplementation() -> Any? {
  return MainActor.assumeIsolated {
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
   if let pm = locator.powerModeProvider?.activeConfiguration {
    lines.append("Power Mode: \(pm.name)")
   }
   let mode = UserDefaults.standard.string(forKey: UserDefaults.Keys.recordingMode) ?? "hybrid"
   lines.append("Recording Mode: \(mode)")
   let style = UserDefaults.standard.string(forKey: UserDefaults.Keys.recorderType) ?? RecorderStyle.mini.rawValue
   lines.append("Recorder: \(style)")
   let paste = UserDefaults.standard.string(forKey: UserDefaults.Keys.pasteMethod) ?? "default"
   lines.append("Paste: \(paste)")
   let sound = UserDefaults.standard.bool(forKey: UserDefaults.Keys.isSoundFeedbackEnabled)
   lines.append("Sound: \(sound ? "on" : "off")")
   return lines.joined(separator: "\n")
  }
 }
}

// MARK: - Settings Configuration Commands

class SetRecordingModeCommand: NSScriptCommand {
 override func performDefaultImplementation() -> Any? {
  guard let mode = directParameter as? String else {
   return "Error: mode parameter required (hybrid, toggle, hands-free)"
  }
  let normalized = mode.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
  let valid = ["hybrid", "toggle", "hands-free"]
  guard valid.contains(normalized) else {
   return "Error: invalid mode \"\(mode)\". Use: \(valid.joined(separator: ", "))"
  }
  UserDefaults.standard.set(normalized, forKey: UserDefaults.Keys.recordingMode)
  return "Recording mode set to \(normalized)"
 }
}

class SetRecorderStyleCommand: NSScriptCommand {
 override func performDefaultImplementation() -> Any? {
  guard let style = directParameter as? String else {
   return "Error: style parameter required (mini, notch)"
  }
  let normalized = style.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
  guard RecorderStyle(rawValue: normalized) != nil else {
   return "Error: invalid style \"\(style)\". Use: mini, notch"
  }
  UserDefaults.standard.set(normalized, forKey: UserDefaults.Keys.recorderType)
  return "Recorder style set to \(normalized)"
 }
}

class SetPasteMethodCommand: NSScriptCommand {
 override func performDefaultImplementation() -> Any? {
  guard let method = directParameter as? String else {
   return "Error: method parameter required (default, appleScript, typeOut)"
  }
  let normalized = method.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
  let valid = ["default", "applescript", "typeout"]
  guard valid.contains(normalized) else {
   return "Error: invalid method \"\(method)\". Use: default, appleScript, typeOut"
  }
  // Store with canonical casing
  let canonical: String
  switch normalized {
  case "applescript": canonical = "appleScript"
  case "typeout": canonical = "typeOut"
  default: canonical = "default"
  }
  UserDefaults.standard.set(canonical, forKey: UserDefaults.Keys.pasteMethod)
  return "Paste method set to \(canonical)"
 }
}

class ToggleSoundCommand: NSScriptCommand {
 override func performDefaultImplementation() -> Any? {
  let key = UserDefaults.Keys.isSoundFeedbackEnabled
  let current = UserDefaults.standard.bool(forKey: key)
  UserDefaults.standard.set(!current, forKey: key)
  return "Sound feedback \(!current ? "enabled" : "disabled")"
 }
}

class ToggleSystemMuteCommand: NSScriptCommand {
 override func performDefaultImplementation() -> Any? {
  let key = UserDefaults.Keys.isSystemMuteEnabled
  let current = UserDefaults.standard.bool(forKey: key)
  UserDefaults.standard.set(!current, forKey: key)
  return "System mute \(!current ? "enabled" : "disabled")"
 }
}

class TogglePauseMediaCommand: NSScriptCommand {
 override func performDefaultImplementation() -> Any? {
  let key = UserDefaults.Keys.isPauseMediaEnabled
  let current = UserDefaults.standard.bool(forKey: key)
  UserDefaults.standard.set(!current, forKey: key)
  return "Pause media \(!current ? "enabled" : "disabled")"
 }
}

class ToggleTextFormattingCommand: NSScriptCommand {
 override func performDefaultImplementation() -> Any? {
  let key = UserDefaults.Keys.isTextFormattingEnabled
  let current = UserDefaults.standard.bool(forKey: key)
  UserDefaults.standard.set(!current, forKey: key)
  return "Text formatting \(!current ? "enabled" : "disabled")"
 }
}

class ToggleFillerRemovalCommand: NSScriptCommand {
 override func performDefaultImplementation() -> Any? {
  let key = UserDefaults.Keys.removeFillerWords
  let current = UserDefaults.standard.bool(forKey: key)
  UserDefaults.standard.set(!current, forKey: key)
  return "Filler removal \(!current ? "enabled" : "disabled")"
 }
}

class ToggleVADCommand: NSScriptCommand {
 override func performDefaultImplementation() -> Any? {
  let key = UserDefaults.Keys.isVADEnabled
  let current = UserDefaults.standard.bool(forKey: key)
  UserDefaults.standard.set(!current, forKey: key)
  return "VAD \(!current ? "enabled" : "disabled")"
 }
}

class ToggleMenuBarOnlyCommand: NSScriptCommand {
 override func performDefaultImplementation() -> Any? {
  return MainActor.assumeIsolated {
   let key = UserDefaults.Keys.isMenuBarOnly
   let current = UserDefaults.standard.bool(forKey: key)
   UserDefaults.standard.set(!current, forKey: key)
   AppServiceLocator.shared.menuBarManager?.isMenuBarOnly = !current
   return "Menu bar only \(!current ? "enabled" : "disabled")"
  }
 }
}

// MARK: - Word Replacement Commands

class AddWordReplacementCommand: NSScriptCommand {
 override func performDefaultImplementation() -> Any? {
  guard let original = directParameter as? String else {
   return "Error: original text parameter required"
  }
  guard let replacement = evaluatedArguments?["replacementText"] as? String else {
   return "Error: replacement text parameter required (with replacement \"text\")"
  }
  return MainActor.assumeIsolated {
   guard let container = AppServiceLocator.shared.modelContainer else {
    return "Service not available"
   }
   let context = container.mainContext
   let trimmedOriginal = original.trimmingCharacters(in: .whitespacesAndNewlines)
   let trimmedReplacement = replacement.trimmingCharacters(in: .whitespacesAndNewlines)
   guard !trimmedOriginal.isEmpty, !trimmedReplacement.isEmpty else {
    return "Error: both original and replacement text must be non-empty"
   }
   // Check for duplicates
   let descriptor = FetchDescriptor<WordReplacement>()
   let existing = context.safeFetch(descriptor, context: "add word replacement", logger: Logger(subsystem: "com.prakashjoshipax.voiceink", category: "ScriptCommands"))
   if existing.contains(where: { $0.originalText.lowercased() == trimmedOriginal.lowercased() }) {
    return "Already exists: \(trimmedOriginal)"
   }
   let entry = WordReplacement(originalText: trimmedOriginal, replacementText: trimmedReplacement)
   context.insert(entry)
   do {
    try context.save()
    WordReplacementService.shared.invalidateCache()
    return "Added: \(trimmedOriginal) -> \(trimmedReplacement)"
   } catch {
    context.rollback()
    return "Error: \(error.localizedDescription)"
   }
  }
 }
}

class RemoveWordReplacementCommand: NSScriptCommand {
 override func performDefaultImplementation() -> Any? {
  guard let original = directParameter as? String else {
   return "Error: original text parameter required"
  }
  return MainActor.assumeIsolated {
   guard let container = AppServiceLocator.shared.modelContainer else {
    return "Service not available"
   }
   let context = container.mainContext
   let trimmed = original.trimmingCharacters(in: .whitespacesAndNewlines)
   let descriptor = FetchDescriptor<WordReplacement>()
   let items = context.safeFetch(descriptor, context: "remove word replacement", logger: Logger(subsystem: "com.prakashjoshipax.voiceink", category: "ScriptCommands"))
   guard let match = items.first(where: { $0.originalText.lowercased() == trimmed.lowercased() }) else {
    return "Not found: \(trimmed)"
   }
   context.delete(match)
   do {
    try context.save()
    WordReplacementService.shared.invalidateCache()
    return "Removed: \(trimmed)"
   } catch {
    context.rollback()
    return "Error: \(error.localizedDescription)"
   }
  }
 }
}

class ListWordReplacementsCommand: NSScriptCommand {
 override func performDefaultImplementation() -> Any? {
  return MainActor.assumeIsolated {
   guard let container = AppServiceLocator.shared.modelContainer else {
    return "Service not available"
   }
   let context = container.mainContext
   let descriptor = FetchDescriptor<WordReplacement>(sortBy: [SortDescriptor(\WordReplacement.originalText)])
   let items = context.safeFetch(descriptor, context: "list word replacements", logger: Logger(subsystem: "com.prakashjoshipax.voiceink", category: "ScriptCommands"))
   if items.isEmpty {
    return "No word replacements"
   }
   return items.map { "\($0.originalText) -> \($0.replacementText)\($0.isEnabled ? "" : " (disabled)")" }.joined(separator: ", ")
  }
 }
}

// MARK: - Transcription Management Commands

class CopyLastTranscriptionCommand: NSScriptCommand {
 override func performDefaultImplementation() -> Any? {
  return MainActor.assumeIsolated {
   guard let container = AppServiceLocator.shared.modelContainer else {
    return "Service not available"
   }
   let context = container.mainContext
   guard let transcription = LastTranscriptionService.getLastTranscription(from: context) else {
    return "No transcriptions found"
   }
   let text = transcription.enhancedText ?? transcription.text
   NSPasteboard.general.clearContents()
   NSPasteboard.general.setString(text, forType: .string)
   return "Copied to clipboard"
  }
 }
}

class GetTranscriptionCountCommand: NSScriptCommand {
 override func performDefaultImplementation() -> Any? {
  return MainActor.assumeIsolated {
   guard let container = AppServiceLocator.shared.modelContainer else {
    return "Service not available"
   }
   let context = container.mainContext
   let descriptor = FetchDescriptor<Transcription>()
   let items = context.safeFetch(descriptor, context: "transcription count", logger: Logger(subsystem: "com.prakashjoshipax.voiceink", category: "ScriptCommands"))
   return "\(items.count)"
  }
 }
}
