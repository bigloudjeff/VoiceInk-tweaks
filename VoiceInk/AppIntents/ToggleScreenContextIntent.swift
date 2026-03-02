import AppIntents
import Foundation

struct ToggleScreenContextIntent: AppIntent {
 static var title: LocalizedStringResource = "Toggle VoiceInk Screen Context"
 static var description = IntentDescription("Toggle whether VoiceInk captures screen context for AI enhancement.")

 static var openAppWhenRun: Bool = false

 @MainActor
 func perform() async throws -> some IntentResult & ProvidesDialog {
  guard let service = AppServiceLocator.shared.enhancementService else {
   throw IntentError.serviceNotAvailable
  }

  service.useScreenCaptureContext.toggle()
  let state = service.useScreenCaptureContext ? "enabled" : "disabled"
  return .result(dialog: "Screen context \(state)")
 }
}
