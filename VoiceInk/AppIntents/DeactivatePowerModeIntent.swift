import AppIntents
import Foundation

struct DeactivatePowerModeIntent: AppIntent {
 static var title: LocalizedStringResource = "Deactivate VoiceInk Power Mode"
 static var description = IntentDescription("Deactivate the currently active Power Mode and restore previous settings.")

 static var openAppWhenRun: Bool = false

 @MainActor
 func perform() async throws -> some IntentResult & ProvidesDialog {
  let sessionManager = PowerModeSessionManager.shared

  guard sessionManager.hasActiveSession else {
   return .result(dialog: "No Power Mode is currently active")
  }

  guard let whisperState = AppServiceLocator.shared.whisperState,
        let enhancementService = AppServiceLocator.shared.enhancementService else {
   throw IntentError.serviceNotAvailable
  }

  sessionManager.configure(whisperState: whisperState, enhancementService: enhancementService)
  await sessionManager.endSession()
  PowerModeManager.shared.setActiveConfiguration(nil)

  return .result(dialog: "Power Mode deactivated")
 }
}
