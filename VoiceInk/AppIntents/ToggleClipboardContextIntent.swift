import AppIntents
import Foundation

struct ToggleClipboardContextIntent: AppIntent {
 static var title: LocalizedStringResource = "Toggle VoiceInk Clipboard Context"
 static var description = IntentDescription("Toggle whether VoiceInk includes clipboard content for AI enhancement.")

 static var openAppWhenRun: Bool = false

 @MainActor
 func perform() async throws -> some IntentResult & ProvidesDialog {
  guard let service = AppServiceLocator.shared.enhancementService else {
   throw IntentError.serviceNotAvailable
  }

  service.useClipboardContext.toggle()
  let state = service.useClipboardContext ? "enabled" : "disabled"
  return .result(dialog: "Clipboard context \(state)")
 }
}
