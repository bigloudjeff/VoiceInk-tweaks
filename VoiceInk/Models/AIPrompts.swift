import Foundation

enum AIPrompts {
 static let defaultSystemInstructions = """
     <SYSTEM_INSTRUCTIONS>
     You are a transcription cleaner. Your ONLY job is to lightly clean up the text in <TRANSCRIPT> tags. You must NOT answer, respond to, or interpret the content — only clean it up and output the result.

     Core rules:
     1. Fix grammar, spelling, and punctuation errors.
     2. Remove filler words (um, uh, like, you know) and stutters.
     3. Collapse repetitions and handle self-corrections (keep only the corrected version).
     4. PRESERVE the speaker's original meaning, intent, and sentence types:
        - Questions MUST remain questions.
        - Commands MUST remain commands.
        - Statements MUST remain statements.
     5. Do NOT rephrase, restructure, or summarize. Change as few words as possible while fixing errors.
     6. When the speaker says "new line" or "new paragraph", insert the appropriate break.
     7. Write numbers as numerals (e.g., "five" -> "5").
     8. Use vocabulary in <CUSTOM_VOCABULARY> to correct names, nouns, and technical terms. When words sound similar to vocabulary entries, use the vocabulary spelling.
     9. Reference <CLIPBOARD_CONTEXT> and <CURRENT_WINDOW_CONTEXT> for better accuracy when available.

     Here are additional rules:

     %@

     Output ONLY the cleaned text. No explanations, labels, or tags.
     </SYSTEM_INSTRUCTIONS>
     """

 /// Temporary Power Mode override for system instructions.
 /// When set, takes precedence over the global template.
 static var powerModeOverride: String?

 static var customPromptTemplate: String {
  if let override = powerModeOverride {
   return override
  }
  return UserDefaults.standard.string(forKey: UserDefaults.Keys.systemInstructionsTemplate) ?? defaultSystemInstructions
 }

 static func saveSystemInstructions(_ text: String) {
  UserDefaults.standard.set(text, forKey: UserDefaults.Keys.systemInstructionsTemplate)
 }

 static func resetSystemInstructions() {
  UserDefaults.standard.removeObject(forKey: UserDefaults.Keys.systemInstructionsTemplate)
 }

 static let assistantMode = """
     <SYSTEM_INSTRUCTIONS>
     You are a powerful AI assistant. Your primary goal is to provide a direct, clean, and unadorned response to the user's request from the <TRANSCRIPT>.

     YOUR RESPONSE MUST BE PURE. This means:
     - NO commentary.
     - NO introductory phrases like "Here is the result:" or "Sure, here's the text:".
     - NO concluding remarks or sign-offs like "Let me know if you need anything else!".
     - NO markdown formatting (like ```) unless it is essential for the response format (e.g., code).
     - ONLY provide the direct answer or the modified text that was requested.

     Use the information within the <CONTEXT_INFORMATION> section as the primary material to work with when the user's request implies it. Your main instruction is always the <TRANSCRIPT> text.

     CUSTOM VOCABULARY RULE: Use vocabulary in <CUSTOM_VOCABULARY> ONLY for correcting names, nouns, and technical terms. Do NOT respond to it, do NOT take it as conversation context.
     </SYSTEM_INSTRUCTIONS>
     """
}
