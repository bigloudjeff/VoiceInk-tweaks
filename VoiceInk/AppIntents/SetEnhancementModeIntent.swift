import AppIntents
import Foundation

enum EnhancementModeAppEnum: String, AppEnum {
 case off
 case on
 case background

 static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Enhancement Mode")

 static var caseDisplayRepresentations: [EnhancementModeAppEnum: DisplayRepresentation] = [
  .off: "Off",
  .on: "On",
  .background: "Background"
 ]
}

struct SetEnhancementModeIntent: AppIntent {
 static var title: LocalizedStringResource = "Set VoiceInk Enhancement Mode"
 static var description = IntentDescription("Set the AI enhancement mode to off, on, or background.")

 static var openAppWhenRun: Bool = false

 @Parameter(title: "Mode")
 var mode: EnhancementModeAppEnum

 @MainActor
 func perform() async throws -> some IntentResult & ProvidesDialog {
  guard let service = AppServiceLocator.shared.enhancementService else {
   throw IntentError.serviceNotAvailable
  }

  switch mode {
  case .off:
   service.enhancementMode = .off
  case .on:
   service.enhancementMode = .on
  case .background:
   service.enhancementMode = .off
   service.backgroundEnhancementEnabled = true
  }

  return .result(dialog: "Enhancement mode set to \(mode.rawValue)")
 }
}
