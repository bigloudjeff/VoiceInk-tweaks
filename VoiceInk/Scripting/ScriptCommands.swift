import Cocoa
import Foundation

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
    NotificationCenter.default.post(
     name: .navigateToDestination,
     object: nil,
     userInfo: ["destination": destination]
    )
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
