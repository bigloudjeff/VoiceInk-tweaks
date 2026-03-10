import Foundation

struct TemplatePrompt: Identifiable {
 let id: UUID
 let title: String
 let promptText: String
 let icon: PromptIcon
 let description: String

 func toCustomPrompt() -> CustomPrompt {
  CustomPrompt(
   id: UUID(),
   title: title,
   promptText: promptText,
   icon: icon,
   description: description,
   isPredefined: false
  )
 }
}

enum PromptTemplates {
 static var all: [TemplatePrompt] {
  createTemplatePrompts()
 }

 private static func loadTemplate(_ filename: String, fallback: String) -> String {
  PromptFileManager.load(filename, subdirectory: "Templates") ?? fallback
 }

 static func createTemplatePrompts() -> [TemplatePrompt] {
  [
   TemplatePrompt(
    id: UUID(),
    title: "System Default",
    promptText: loadTemplate("system-default", fallback: "Clean up the transcript for clarity and natural flow."),
    icon: "checkmark.seal.fill",
    description: "Default system prompt"
   ),
   TemplatePrompt(
    id: UUID(),
    title: "Chat",
    promptText: loadTemplate("chat", fallback: "Rewrite as an informal chat message."),
    icon: "bubble.left.and.bubble.right.fill",
    description: "Casual chat-style formatting"
   ),
   TemplatePrompt(
    id: UUID(),
    title: "Email",
    promptText: loadTemplate("email", fallback: "Rewrite as a complete email with greeting and closing."),
    icon: "envelope.fill",
    description: "Professional email formatting"
   ),
   TemplatePrompt(
    id: UUID(),
    title: "Rewrite",
    promptText: loadTemplate("rewrite", fallback: "Rewrite with enhanced clarity and improved structure."),
    icon: "pencil.circle.fill",
    description: "Rewrites with better clarity."
   )
  ]
 }
}
