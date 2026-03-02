import AppIntents
import Foundation

struct ToggleEnhancementIntent: AppIntent {
 static var title: LocalizedStringResource = "Toggle VoiceInk Enhancement"
 static var description = IntentDescription("Toggle AI enhancement on or off for VoiceInk transcriptions.")

 static var openAppWhenRun: Bool = false

 @MainActor
 func perform() async throws -> some IntentResult & ProvidesDialog {
  guard let service = AppServiceLocator.shared.enhancementService else {
   throw IntentError.serviceNotAvailable
  }

  service.isEnhancementEnabled.toggle()
  let state = service.isEnhancementEnabled ? "enabled" : "disabled"
  return .result(dialog: "Enhancement \(state)")
 }
}
