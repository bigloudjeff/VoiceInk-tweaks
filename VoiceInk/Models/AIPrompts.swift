import Foundation

enum AIPrompts {
 /// Hard-coded fallback, used only if both bundle resource and user override are missing.
 private static let fallbackSystemInstructions = """
  You are a transcription cleaner. Clean up the text in <TRANSCRIPT> tags. \
  Fix grammar, remove filler words (um, uh), fix stutters, preserve meaning. \
  Output ONLY the cleaned text.

  %@
  """

 /// The default system instructions loaded from bundle resource.
 static var defaultSystemInstructions: String {
  PromptFileManager.load("system-instructions") ?? fallbackSystemInstructions
 }

 /// Temporary Power Mode override for system instructions.
 /// When set, takes precedence over the global template.
 static var powerModeOverride: String?

 static var customPromptTemplate: String {
  if let override = powerModeOverride {
   return override
  }
  // Check user override file, then bundle resource
  if PromptFileManager.hasUserOverride("system-instructions") {
   return PromptFileManager.load("system-instructions") ?? defaultSystemInstructions
  }
  return defaultSystemInstructions
 }

 static func saveSystemInstructions(_ text: String) {
  PromptFileManager.saveUserOverride("system-instructions", content: text)
 }

 static func resetSystemInstructions() {
  PromptFileManager.removeUserOverride("system-instructions")
 }

 /// The assistant mode prompt loaded from bundle resource.
 static var assistantMode: String {
  PromptFileManager.load("assistant-mode") ?? """
   You are a powerful AI assistant. Provide a direct response to the user's request \
   from the <TRANSCRIPT>. No commentary, no introductory phrases, no sign-offs.
   """
 }
}
