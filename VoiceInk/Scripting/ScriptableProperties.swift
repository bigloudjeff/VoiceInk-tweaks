import Cocoa
import Foundation

extension NSApplication {
 @objc var scriptRecordingState: String {
  MainActor.assumeIsolated {
   guard let whisperState = AppServiceLocator.shared.whisperState else {
    return "unknown"
   }
   switch whisperState.recordingState {
   case .idle: return "idle"
   case .starting: return "starting"
   case .recording: return "recording"
   case .transcribing: return "transcribing"
   case .enhancing: return "enhancing"
   case .busy: return "busy"
   }
  }
 }

 @objc var scriptEnhancementEnabled: Bool {
  MainActor.assumeIsolated {
   guard let service = AppServiceLocator.shared.enhancementService else {
    return false
   }
   return service.isEnhancementEnabled
  }
 }

 @objc var scriptEnhancementMode: String {
  MainActor.assumeIsolated {
   guard let service = AppServiceLocator.shared.enhancementService else {
    return "unknown"
   }
   return service.enhancementMode.rawValue
  }
 }

 @objc var scriptActivePromptName: String {
  MainActor.assumeIsolated {
   guard let service = AppServiceLocator.shared.enhancementService else {
    return ""
   }
   return service.activePrompt?.title ?? ""
  }
 }

 @objc var scriptActivePowerMode: String {
  MainActor.assumeIsolated {
   return AppServiceLocator.shared.powerModeProvider?.activeConfiguration?.name ?? ""
  }
 }

 @objc var scriptCurrentModel: String {
  MainActor.assumeIsolated {
   return AppServiceLocator.shared.whisperState?.currentTranscriptionModel?.name ?? "none"
  }
 }

 @objc var scriptCurrentLanguage: String {
  UserDefaults.standard.string(forKey: UserDefaults.Keys.selectedLanguage) ?? "auto"
 }

 @objc var scriptRecordingMode: String {
  UserDefaults.standard.string(forKey: UserDefaults.Keys.recordingMode) ?? "hybrid"
 }

 @objc var scriptRecorderStyle: String {
  UserDefaults.standard.string(forKey: UserDefaults.Keys.recorderType) ?? RecorderStyle.mini.rawValue
 }

 @objc var scriptPasteMethod: String {
  UserDefaults.standard.string(forKey: UserDefaults.Keys.pasteMethod) ?? "default"
 }

 @objc var scriptSoundEnabled: Bool {
  UserDefaults.standard.bool(forKey: UserDefaults.Keys.isSoundFeedbackEnabled)
 }
}
