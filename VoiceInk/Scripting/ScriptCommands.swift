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
   let manager = PowerModeManager.shared
   let normalized = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
   guard let config = manager.configurations.first(where: { $0.name.lowercased() == normalized }) else {
    let available = manager.configurations.map { $0.name }.joined(separator: ", ")
    return "Error: Power Mode \"\(name)\" not found. Available: \(available)"
   }
   guard let whisperState = AppServiceLocator.shared.whisperState,
         let enhancementService = AppServiceLocator.shared.enhancementService else {
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
   let sessionManager = PowerModeSessionManager.shared
   guard sessionManager.hasActiveSession else {
    return "No Power Mode active"
   }
   guard let whisperState = AppServiceLocator.shared.whisperState,
         let enhancementService = AppServiceLocator.shared.enhancementService else {
    return "Service not available"
   }
   sessionManager.configure(whisperState: whisperState, enhancementService: enhancementService)
   Task { @MainActor in
    await sessionManager.endSession()
    PowerModeManager.shared.setActiveConfiguration(nil)
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
  UserDefaults.standard.set(trimmed, forKey: UserDefaults.Keys.selectedLanguage)
  NotificationCenter.default.post(name: .languageDidChange, object: nil)
  return trimmed
 }
}
