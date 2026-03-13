import Foundation
import os
import SwiftData

@MainActor
enum VoiceInkURLHandler {
 private static let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "URLHandler")

 /// UserDefaults key for the URL scheme auth token.
 /// When set to a non-empty string, mutating URL actions require `?token=<value>`.
 static let tokenKey = "urlSchemeAuthToken"

 static func handle(_ url: URL, container: ModelContainer) {
  guard url.scheme == "voiceink",
        let host = url.host else { return }

  let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
  let params = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []

  // Safe (read-only) actions skip auth
  let isSafe = (host == "navigate") || (host == "status") ||
               (host == "vocabulary" && path == "list") ||
               (host == "replacement" && path == "list")

  if !isSafe && !validateToken(params: params) {
   notify("Unauthorized: invalid or missing token", type: .error)
   logger.warning("URL scheme auth failed for \(host, privacy: .public)/\(path, privacy: .public)")
   return
  }

  switch host {
  case "vocabulary":
   handleVocabulary(path: path, params: params, container: container)
  case "replacement":
   handleReplacement(path: path, params: params, container: container)
  case "recording":
   handleRecording(path: path, params: params)
  case "enhancement":
   handleEnhancement(path: path, params: params)
  case "settings":
   handleSettings(path: path, params: params)
  case "navigate":
   handleNavigate(path: path)
  case "status":
   handleStatus()
  default:
   notify("Unknown command: \(host)", type: .error)
  }
 }

 /// Validates the `token` parameter against the stored auth token.
 /// Returns true if no token is configured (opt-in security) or if token matches.
 private static func validateToken(params: [URLQueryItem]) -> Bool {
  let storedToken = UserDefaults.standard.string(forKey: tokenKey) ?? ""
  guard !storedToken.isEmpty else { return true }
  let providedToken = param("token", from: params) ?? ""
  // Constant-time comparison to prevent timing attacks
  guard storedToken.count == providedToken.count else { return false }
  var match = true
  for (a, b) in zip(storedToken.utf8, providedToken.utf8) {
   match = match && (a == b)
  }
  return match
 }

 // MARK: - Vocabulary

 private static func handleVocabulary(path: String, params: [URLQueryItem], container: ModelContainer) {
  let word = param("word", from: params)
  let hints = param("hints", from: params)

  switch path {
  case "add":
   guard let word, !word.isEmpty else { notify("Missing word parameter", type: .error); return }
   let result = CustomVocabularyService.shared.addWords(word, phoneticHints: hints, in: container)
   if !result.added.isEmpty {
    notify("Added: \(result.added.joined(separator: ", "))", type: .success)
   } else if !result.duplicates.isEmpty {
    notify("Already exists: \(result.duplicates.joined(separator: ", "))", type: .info)
   }
  case "remove":
   guard let word, !word.isEmpty else { notify("Missing word parameter", type: .error); return }
   if CustomVocabularyService.shared.removeWord(word, from: container) {
    notify("Removed: \(word)", type: .success)
   } else {
    notify("Not found: \(word)", type: .info)
   }
  case "list":
   navigateTo("Dictionary")
  default:
   notify("Unknown vocabulary action: \(path)", type: .error)
  }
 }

 // MARK: - Word Replacements

 private static func handleReplacement(path: String, params: [URLQueryItem], container: ModelContainer) {
  let original = param("from", from: params)
  let replacement = param("to", from: params)

  switch path {
  case "add":
   guard let original, !original.isEmpty, let replacement, !replacement.isEmpty else {
    notify("Missing from/to parameters", type: .error); return
   }
   let context = container.mainContext
   let descriptor = FetchDescriptor<WordReplacement>()
   let existing = context.safeFetch(descriptor, context: "url add replacement", logger: logger)
   if existing.contains(where: { $0.originalText.lowercased() == original.lowercased() }) {
    notify("Already exists: \(original)", type: .info); return
   }
   let entry = WordReplacement(originalText: original, replacementText: replacement)
   context.insert(entry)
   do {
    try context.save()
    WordReplacementService.shared.invalidateCache()
    notify("Added: \(original) -> \(replacement)", type: .success)
   } catch {
    context.rollback()
    notify("Failed to save", type: .error)
   }
  case "remove":
   guard let original, !original.isEmpty else { notify("Missing from parameter", type: .error); return }
   let context = container.mainContext
   let descriptor = FetchDescriptor<WordReplacement>()
   let items = context.safeFetch(descriptor, context: "url remove replacement", logger: logger)
   guard let match = items.first(where: { $0.originalText.lowercased() == original.lowercased() }) else {
    notify("Not found: \(original)", type: .info); return
   }
   context.delete(match)
   do {
    try context.save()
    WordReplacementService.shared.invalidateCache()
    notify("Removed: \(original)", type: .success)
   } catch {
    context.rollback()
    notify("Failed to save", type: .error)
   }
  case "list":
   navigateTo("Dictionary")
  default:
   notify("Unknown replacement action: \(path)", type: .error)
  }
 }

 // MARK: - Recording Control

 private static func handleRecording(path: String, params: [URLQueryItem]) {
  switch path {
  case "toggle":
   NotificationCenter.default.post(name: .toggleMiniRecorder, object: nil)
  case "dismiss":
   NotificationCenter.default.post(name: .dismissMiniRecorder, object: nil)
  case "mode":
   guard let value = param("value", from: params) else { notify("Missing value parameter", type: .error); return }
   let normalized = value.lowercased()
   guard ["hybrid", "toggle", "hands-free"].contains(normalized) else {
    notify("Invalid mode: \(value)", type: .error); return
   }
   UserDefaults.standard.set(normalized, forKey: UserDefaults.Keys.recordingMode)
   notify("Recording mode: \(normalized)", type: .success)
  case "style":
   guard let value = param("value", from: params) else { notify("Missing value parameter", type: .error); return }
   let normalized = value.lowercased()
   guard RecorderStyle(rawValue: normalized) != nil else {
    notify("Invalid style: \(value)", type: .error); return
   }
   UserDefaults.standard.set(normalized, forKey: UserDefaults.Keys.recorderType)
   notify("Recorder style: \(normalized)", type: .success)
  default:
   notify("Unknown recording action: \(path)", type: .error)
  }
 }

 // MARK: - Enhancement Control

 private static func handleEnhancement(path: String, params: [URLQueryItem]) {
  switch path {
  case "toggle":
   guard let service = AppServiceLocator.shared.enhancementService else { return }
   service.isEnhancementEnabled.toggle()
   notify("Enhancement \(service.isEnhancementEnabled ? "enabled" : "disabled")", type: .success)
  case "mode":
   guard let value = param("value", from: params) else { notify("Missing value parameter", type: .error); return }
   guard let service = AppServiceLocator.shared.enhancementService else { return }
   switch value.lowercased() {
   case "off": service.enhancementMode = .off
   case "on": service.enhancementMode = .on
   case "background":
    service.enhancementMode = .off
    service.backgroundEnhancementEnabled = true
   default: notify("Invalid mode: \(value)", type: .error); return
   }
   notify("Enhancement mode: \(value.lowercased())", type: .success)
  case "prompt":
   guard let name = param("name", from: params) else { notify("Missing name parameter", type: .error); return }
   guard let service = AppServiceLocator.shared.enhancementService else { return }
   let normalized = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
   if let prompt = service.allPrompts.first(where: { $0.title.lowercased() == normalized }) {
    service.selectedPromptId = prompt.id
    if !service.isEnhancementEnabled { service.enhancementMode = .on }
    notify("Prompt: \(prompt.title)", type: .success)
   } else {
    notify("Prompt not found: \(name)", type: .error)
   }
  case "screen":
   guard let service = AppServiceLocator.shared.enhancementService else { return }
   service.useScreenCaptureContext.toggle()
   notify("Screen context \(service.useScreenCaptureContext ? "enabled" : "disabled")", type: .success)
  case "clipboard":
   guard let service = AppServiceLocator.shared.enhancementService else { return }
   service.useClipboardContext.toggle()
   notify("Clipboard context \(service.useClipboardContext ? "enabled" : "disabled")", type: .success)
  default:
   notify("Unknown enhancement action: \(path)", type: .error)
  }
 }

 // MARK: - Settings Toggles

 private static func handleSettings(path: String, params: [URLQueryItem]) {
  switch path {
  case "sound":
   toggle(UserDefaults.Keys.isSoundFeedbackEnabled, label: "Sound feedback")
  case "mute":
   toggle(UserDefaults.Keys.isSystemMuteEnabled, label: "System mute")
  case "pause-media":
   toggle(UserDefaults.Keys.isPauseMediaEnabled, label: "Pause media")
  case "text-formatting":
   toggle(UserDefaults.Keys.isTextFormattingEnabled, label: "Text formatting")
  case "filler-removal":
   toggle(UserDefaults.Keys.removeFillerWords, label: "Filler removal")
  case "vad":
   toggle(UserDefaults.Keys.isVADEnabled, label: "VAD")
  case "menu-bar-only":
   let key = UserDefaults.Keys.isMenuBarOnly
   let current = UserDefaults.standard.bool(forKey: key)
   UserDefaults.standard.set(!current, forKey: key)
   AppServiceLocator.shared.menuBarManager?.isMenuBarOnly = !current
   notify("Menu bar only \(!current ? "enabled" : "disabled")", type: .success)
  case "paste":
   guard let value = param("value", from: params) else { notify("Missing value parameter", type: .error); return }
   let normalized = value.lowercased()
   let canonical: String
   switch normalized {
   case "applescript": canonical = "appleScript"
   case "typeout": canonical = "typeOut"
   case "default": canonical = "default"
   default: notify("Invalid paste method: \(value)", type: .error); return
   }
   UserDefaults.standard.set(canonical, forKey: UserDefaults.Keys.pasteMethod)
   notify("Paste method: \(canonical)", type: .success)
  case "language":
   guard let code = param("value", from: params) else { notify("Missing value parameter", type: .error); return }
   let trimmed = code.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
   guard PredefinedModels.allLanguages.keys.contains(trimmed) else {
    notify("Unknown language: \(code)", type: .error); return
   }
   UserDefaults.standard.set(trimmed, forKey: UserDefaults.Keys.selectedLanguage)
   NotificationCenter.default.post(name: .languageDidChange, object: nil)
   notify("Language: \(PredefinedModels.allLanguages[trimmed] ?? trimmed)", type: .success)
  default:
   notify("Unknown setting: \(path)", type: .error)
  }
 }

 // MARK: - Navigation

 private static func handleNavigate(path: String) {
  let destinations = [
   "dashboard": "Dashboard", "pipeline": "Pipeline",
   "history": "History", "models": "Pipeline",
   "enhancement": "Pipeline", "postprocessing": "Pipeline",
   "powermode": "Power Mode", "permissions": "Permissions",
   "audio": "Pipeline", "dictionary": "Pipeline",
   "settings": "Settings", "preferences": "Settings",
   "transcribe": "Transcribe Audio", "pro": "VoiceInk Pro"
  ]
  if let destination = destinations[path.lowercased()] {
   navigateTo(destination)
  } else if path == "history-window" {
   guard let container = AppServiceLocator.shared.modelContainer,
         let whisperState = AppServiceLocator.shared.whisperState else { return }
   HistoryWindowController.shared.showHistoryWindow(modelContainer: container, whisperState: whisperState)
  } else {
   notify("Unknown view: \(path)", type: .error)
  }
 }

 // MARK: - Status

 private static func handleStatus() {
  let locator = AppServiceLocator.shared
  var lines: [String] = []
  if let ws = locator.whisperState {
   lines.append("Recording: \(ws.recordingState)")
   lines.append("Model: \(ws.currentTranscriptionModel?.name ?? "none")")
  }
  if let es = locator.enhancementService {
   lines.append("Enhancement: \(es.enhancementMode.rawValue)")
  }
  notify(lines.joined(separator: " | "), type: .info)
 }

 // MARK: - Helpers

 private static func param(_ name: String, from params: [URLQueryItem]) -> String? {
  params.first(where: { $0.name == name })?.value
 }

 private static func toggle(_ key: String, label: String) {
  let current = UserDefaults.standard.bool(forKey: key)
  UserDefaults.standard.set(!current, forKey: key)
  notify("\(label) \(!current ? "enabled" : "disabled")", type: .success)
 }

 private static func navigateTo(_ destination: String) {
  guard let menuBarManager = AppServiceLocator.shared.menuBarManager else { return }
  menuBarManager.focusMainWindow()
  if let nav = NavigationDestination(legacyString: destination) {
   nav.post()
  }
 }

 private static func notify(_ message: String, type: AppNotificationView.NotificationType) {
  NotificationManager.shared.showNotification(title: message, type: type)
 }
}
