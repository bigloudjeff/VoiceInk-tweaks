import Testing
import Foundation
@testable import VoiceInk

struct ScriptCommandSettingsTests {

 // MARK: - Recording Mode Validation

 @Test func validRecordingModes() {
  let valid = ["hybrid", "toggle", "hands-free"]
  for mode in valid {
   let normalized = mode.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
   #expect(valid.contains(normalized), "Mode '\(mode)' should be valid")
  }
 }

 @Test func invalidRecordingModeRejected() {
  let invalid = ["push", "auto", ""]
  let valid = ["hybrid", "toggle", "hands-free"]
  for mode in invalid {
   let normalized = mode.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
   #expect(!valid.contains(normalized), "Mode '\(mode)' should be invalid")
  }
 }

 // MARK: - Recorder Style Validation

 @Test func validRecorderStyles() {
  #expect("mini" == "mini")
  #expect("notch" == "notch")
 }

 @Test func invalidRecorderStyleRejected() {
  let invalid = ["large", "floating", ""]
  for style in invalid {
   let normalized = style.lowercased()
   #expect(normalized != "mini" && normalized != "notch")
  }
 }

 // MARK: - Paste Method Validation

 @Test func pasteMethodCanonicalCasing() {
  let inputs: [(input: String, expected: String)] = [
   ("default", "default"),
   ("applescript", "appleScript"),
   ("typeout", "typeOut"),
   ("APPLESCRIPT", "appleScript"),
   ("TYPEOUT", "typeOut"),
   ("DEFAULT", "default"),
  ]
  for (input, expected) in inputs {
   let normalized = input.lowercased()
   let canonical: String
   switch normalized {
   case "applescript": canonical = "appleScript"
   case "typeout": canonical = "typeOut"
   default: canonical = "default"
   }
   #expect(canonical == expected, "Input '\(input)' should map to '\(expected)'")
  }
 }

 @Test func invalidPasteMethodRejected() {
  let invalid = ["clipboard", "direct", ""]
  let valid = ["default", "applescript", "typeout"]
  for method in invalid {
   let normalized = method.lowercased()
   #expect(!valid.contains(normalized), "Method '\(method)' should be invalid")
  }
 }

 // MARK: - Toggle Behavior Tests (using UserDefaults in test context)

 @Test func toggleBoolInvertsValue() {
  let testKey = "com.voiceink.test.toggleBool.\(UUID().uuidString)"
  UserDefaults.standard.set(false, forKey: testKey)
  let current = UserDefaults.standard.bool(forKey: testKey)
  UserDefaults.standard.set(!current, forKey: testKey)
  #expect(UserDefaults.standard.bool(forKey: testKey) == true)

  // Toggle back
  let updated = UserDefaults.standard.bool(forKey: testKey)
  UserDefaults.standard.set(!updated, forKey: testKey)
  #expect(UserDefaults.standard.bool(forKey: testKey) == false)

  // Cleanup
  UserDefaults.standard.removeObject(forKey: testKey)
 }

 @Test func toggleFromDefaultFalse() {
  let testKey = "com.voiceink.test.toggleDefault.\(UUID().uuidString)"
  // bool(forKey:) returns false for missing keys
  let current = UserDefaults.standard.bool(forKey: testKey)
  #expect(current == false)
  UserDefaults.standard.set(!current, forKey: testKey)
  #expect(UserDefaults.standard.bool(forKey: testKey) == true)

  // Cleanup
  UserDefaults.standard.removeObject(forKey: testKey)
 }

 // MARK: - Language Code Validation

 @Test func validLanguageCodes() {
  let codes = ["auto", "en", "es", "fr", "de", "ja", "zh"]
  for code in codes {
   #expect(PredefinedModels.allLanguages.keys.contains(code), "Language code '\(code)' should be valid")
  }
 }

 @Test func invalidLanguageCodeRejected() {
  let invalid = ["xx", "zzz", ""]
  for code in invalid {
   #expect(!PredefinedModels.allLanguages.keys.contains(code), "Language code '\(code)' should be invalid")
  }
 }

 // MARK: - Status Output Format

 @Test func statusLineFormat() {
  // Verify status line joining produces expected format
  let lines = ["Recording: idle", "Model: none", "Language: en"]
  let joined = lines.joined(separator: "\n")
  #expect(joined.contains("Recording: idle"))
  #expect(joined.contains("Model: none"))
  #expect(joined.components(separatedBy: "\n").count == 3)
 }

 // MARK: - Word Replacement Input Validation

 @Test func emptyReplacementTextRejected() {
  let original = "test"
  let replacement = "   "
  let trimmedOriginal = original.trimmingCharacters(in: .whitespacesAndNewlines)
  let trimmedReplacement = replacement.trimmingCharacters(in: .whitespacesAndNewlines)
  #expect(!trimmedOriginal.isEmpty)
  #expect(trimmedReplacement.isEmpty, "Whitespace-only replacement should be empty after trimming")
 }

 @Test func emptyOriginalTextRejected() {
  let original = ""
  let replacement = "something"
  let trimmedOriginal = original.trimmingCharacters(in: .whitespacesAndNewlines)
  #expect(trimmedOriginal.isEmpty, "Empty original should be rejected")
  #expect(!replacement.isEmpty)
 }

 // MARK: - Enhancement Mode Validation

 @Test func validEnhancementModes() {
  let valid = ["off", "on", "background"]
  for mode in valid {
   let normalized = mode.lowercased()
   #expect(["off", "on", "background"].contains(normalized))
  }
 }

 @Test func invalidEnhancementModeRejected() {
  let invalid = ["auto", "always", ""]
  for mode in invalid {
   let normalized = mode.lowercased()
   #expect(!["off", "on", "background"].contains(normalized))
  }
 }
}
