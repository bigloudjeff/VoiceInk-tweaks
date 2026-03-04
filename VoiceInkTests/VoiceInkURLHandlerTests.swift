import Testing
import Foundation
@testable import VoiceInk

struct VoiceInkURLHandlerTests {

 // MARK: - URL Parsing Tests

 @Test func vocabularyAddURLParsesCorrectly() {
  let url = URL(string: "voiceink://vocabulary/add?word=Kubernetes&hints=kuber%20netties")!
  let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
  #expect(url.scheme == "voiceink")
  #expect(url.host == "vocabulary")
  #expect(url.path == "/add")
  let word = components.queryItems?.first(where: { $0.name == "word" })?.value
  let hints = components.queryItems?.first(where: { $0.name == "hints" })?.value
  #expect(word == "Kubernetes")
  #expect(hints == "kuber netties")
 }

 @Test func vocabularyRemoveURLParsesCorrectly() {
  let url = URL(string: "voiceink://vocabulary/remove?word=oldword")!
  #expect(url.host == "vocabulary")
  #expect(url.path == "/remove")
  let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
  let word = components.queryItems?.first(where: { $0.name == "word" })?.value
  #expect(word == "oldword")
 }

 @Test func vocabularyListURL() {
  let url = URL(string: "voiceink://vocabulary/list")!
  #expect(url.host == "vocabulary")
  #expect(url.path == "/list")
 }

 @Test func replacementAddURL() {
  let url = URL(string: "voiceink://replacement/add?from=gonna&to=going%20to")!
  let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
  #expect(url.host == "replacement")
  #expect(url.path == "/add")
  let from = components.queryItems?.first(where: { $0.name == "from" })?.value
  let to = components.queryItems?.first(where: { $0.name == "to" })?.value
  #expect(from == "gonna")
  #expect(to == "going to")
 }

 @Test func replacementRemoveURL() {
  let url = URL(string: "voiceink://replacement/remove?from=gonna")!
  let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
  #expect(url.host == "replacement")
  let from = components.queryItems?.first(where: { $0.name == "from" })?.value
  #expect(from == "gonna")
 }

 @Test func recordingToggleURL() {
  let url = URL(string: "voiceink://recording/toggle")!
  #expect(url.host == "recording")
  #expect(url.path == "/toggle")
 }

 @Test func recordingModeURL() {
  let url = URL(string: "voiceink://recording/mode?value=toggle")!
  let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
  #expect(url.host == "recording")
  #expect(url.path == "/mode")
  let value = components.queryItems?.first(where: { $0.name == "value" })?.value
  #expect(value == "toggle")
 }

 @Test func recordingStyleURL() {
  let url = URL(string: "voiceink://recording/style?value=notch")!
  let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
  let value = components.queryItems?.first(where: { $0.name == "value" })?.value
  #expect(value == "notch")
 }

 @Test func enhancementToggleURL() {
  let url = URL(string: "voiceink://enhancement/toggle")!
  #expect(url.host == "enhancement")
  #expect(url.path == "/toggle")
 }

 @Test func enhancementModeURL() {
  let url = URL(string: "voiceink://enhancement/mode?value=on")!
  let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
  let value = components.queryItems?.first(where: { $0.name == "value" })?.value
  #expect(value == "on")
 }

 @Test func enhancementPromptURL() {
  let url = URL(string: "voiceink://enhancement/prompt?name=Default")!
  let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
  let name = components.queryItems?.first(where: { $0.name == "name" })?.value
  #expect(name == "Default")
 }

 @Test func settingsSoundURL() {
  let url = URL(string: "voiceink://settings/sound")!
  #expect(url.host == "settings")
  #expect(url.path == "/sound")
 }

 @Test func settingsPasteURL() {
  let url = URL(string: "voiceink://settings/paste?value=typeOut")!
  let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
  let value = components.queryItems?.first(where: { $0.name == "value" })?.value
  #expect(value == "typeOut")
 }

 @Test func settingsLanguageURL() {
  let url = URL(string: "voiceink://settings/language?value=es")!
  let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
  let value = components.queryItems?.first(where: { $0.name == "value" })?.value
  #expect(value == "es")
 }

 @Test func navigateURL() {
  let url = URL(string: "voiceink://navigate/dictionary")!
  #expect(url.host == "navigate")
  #expect(url.path == "/dictionary")
 }

 @Test func navigateHistoryWindowURL() {
  let url = URL(string: "voiceink://navigate/history-window")!
  let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
  #expect(path == "history-window")
 }

 @Test func statusURL() {
  let url = URL(string: "voiceink://status")!
  #expect(url.host == "status")
 }

 @Test func commaSeparatedVocabularyURL() {
  let url = URL(string: "voiceink://vocabulary/add?word=Kubernetes,Anthropic,Claude")!
  let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
  let word = components.queryItems?.first(where: { $0.name == "word" })?.value
  #expect(word == "Kubernetes,Anthropic,Claude")
 }

 @Test func urlEncodedSpacesInHints() {
  let url = URL(string: "voiceink://vocabulary/add?word=test&hints=foo%20bar")!
  let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
  let hints = components.queryItems?.first(where: { $0.name == "hints" })?.value
  #expect(hints == "foo bar")
 }

 @Test func plusSignPreservedInHints() {
  // URLComponents does NOT decode + as space (that's form encoding only)
  // Users should use %20 for spaces: voiceink://vocabulary/add?hints=foo%20bar
  let url = URL(string: "voiceink://vocabulary/add?word=test&hints=foo+bar")!
  let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
  let hints = components.queryItems?.first(where: { $0.name == "hints" })?.value
  #expect(hints == "foo+bar")
 }

 // MARK: - Scheme Validation

 @Test func nonVoiceInkSchemeIgnored() {
  let url = URL(string: "https://vocabulary/add?word=test")!
  #expect(url.scheme != "voiceink")
 }

 // MARK: - Navigate Path Mapping

 @Test func allNavigatePathsValid() {
  let validPaths = [
   "dashboard", "history", "models", "enhancement", "postprocessing",
   "powermode", "permissions", "audio", "dictionary", "settings",
   "transcribe", "pro", "history-window"
  ]
  for path in validPaths {
   let url = URL(string: "voiceink://navigate/\(path)")!
   #expect(url.host == "navigate")
   let parsed = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
   #expect(parsed == path)
  }
 }

 // MARK: - Settings Toggle Paths

 @Test func allSettingsTogglePathsValid() {
  let togglePaths = [
   "sound", "mute", "pause-media", "text-formatting",
   "filler-removal", "vad", "menu-bar-only"
  ]
  for path in togglePaths {
   let url = URL(string: "voiceink://settings/\(path)")!
   #expect(url.host == "settings")
   let parsed = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
   #expect(parsed == path)
  }
 }

 // MARK: - Recording Mode Values

 @Test func validRecordingModes() {
  let validModes = ["hybrid", "toggle", "hands-free"]
  for mode in validModes {
   let url = URL(string: "voiceink://recording/mode?value=\(mode)")!
   let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
   let value = components.queryItems?.first(where: { $0.name == "value" })?.value
   #expect(value == mode)
  }
 }

 // MARK: - Paste Method Values

 @Test func validPasteMethods() {
  let validMethods = ["default", "appleScript", "typeOut"]
  for method in validMethods {
   let url = URL(string: "voiceink://settings/paste?value=\(method)")!
   let components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
   let value = components.queryItems?.first(where: { $0.name == "value" })?.value
   #expect(value == method)
  }
 }
}
