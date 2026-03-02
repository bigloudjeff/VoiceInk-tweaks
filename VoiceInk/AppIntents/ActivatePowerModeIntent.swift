import AppIntents
import Foundation

struct ActivatePowerModeIntent: AppIntent {
 static var title: LocalizedStringResource = "Activate VoiceInk Power Mode"
 static var description = IntentDescription("Activate a Power Mode configuration by name.")

 static var openAppWhenRun: Bool = false

 @Parameter(title: "Power Mode Name")
 var name: String

 @MainActor
 func perform() async throws -> some IntentResult & ProvidesDialog {
  let manager = PowerModeManager.shared
  let normalizedInput = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

  guard let config = manager.configurations.first(where: { $0.name.lowercased() == normalizedInput }) else {
   let available = manager.configurations.map { $0.name }.joined(separator: ", ")
   return .result(dialog: "Power Mode \"\(name)\" not found. Available: \(available)")
  }

  guard let whisperState = AppServiceLocator.shared.whisperState,
        let enhancementService = AppServiceLocator.shared.enhancementService else {
   throw IntentError.serviceNotAvailable
  }

  let sessionManager = PowerModeSessionManager.shared
  sessionManager.configure(whisperState: whisperState, enhancementService: enhancementService)
  await sessionManager.beginSession(with: config)
  manager.setActiveConfiguration(config)

  return .result(dialog: "Power Mode \"\(config.name)\" activated")
 }
}
