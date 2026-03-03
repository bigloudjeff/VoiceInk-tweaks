import AppIntents
import Foundation

struct SetLanguageIntent: AppIntent {
 static var title: LocalizedStringResource = "Set VoiceInk Language"
 static var description = IntentDescription("Set the transcription language (e.g. \"en\", \"fr\", \"auto\").")

 static var openAppWhenRun: Bool = false

 @Parameter(title: "Language Code")
 var languageCode: String

 @MainActor
 func perform() async throws -> some IntentResult & ProvidesDialog {
  let code = languageCode.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
  UserDefaults.standard.set(code, forKey: UserDefaults.Keys.selectedLanguage)
  NotificationCenter.default.post(name: .languageDidChange, object: nil)
  return .result(dialog: "Language set to \"\(code)\"")
 }
}
