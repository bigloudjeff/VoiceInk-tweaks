import AppIntents
import Foundation

struct SelectPromptIntent: AppIntent {
 static var title: LocalizedStringResource = "Select VoiceInk Prompt"
 static var description = IntentDescription("Select an AI enhancement prompt by name.")

 static var openAppWhenRun: Bool = false

 @Parameter(title: "Prompt Name")
 var promptName: String

 @MainActor
 func perform() async throws -> some IntentResult & ProvidesDialog {
  guard let service = AppServiceLocator.shared.enhancementService else {
   throw IntentError.serviceNotAvailable
  }

  let normalizedInput = promptName.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
  guard let prompt = service.allPrompts.first(where: { $0.title.lowercased() == normalizedInput }) else {
   let available = service.allPrompts.map { $0.title }.joined(separator: ", ")
   return .result(dialog: "Prompt \"\(promptName)\" not found. Available: \(available)")
  }

  service.selectedPromptId = prompt.id
  if !service.isEnhancementEnabled {
   service.enhancementMode = .on
  }
  return .result(dialog: "Prompt set to \"\(prompt.title)\"")
 }
}
