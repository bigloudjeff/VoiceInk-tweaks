import Foundation

class EmojiManager: ObservableObject {
 static let shared = EmojiManager()
 
 private let defaultEmojis = ["\u{1F680}", "\u{2728}", "\u{1F4BB}", "\u{1F3AF}", "\u{1F4DD}", "\u{1F916}", "\u{26A1}", "\u{1F525}", "\u{2764}\u{FE0F}", "\u{1F4A1}", "\u{1F30D}", "\u{2699}\u{FE0F}", "\u{1F4DA}", "\u{1F3A8}", "\u{1F4AC}", "\u{1F50D}", "\u{1F4E7}", "\u{1F4C8}", "\u{1F3C6}", "\u{1F389}"]
 private let customEmojisKey = UserDefaults.Keys.customEmojis
 
 @Published var customEmojis: [String] = []
 
 private init() {
 loadCustomEmojis()
 }
 
 var allEmojis: [String] {
 return defaultEmojis + customEmojis
 }
 
 func addCustomEmoji(_ emoji: String) -> Bool {
 let trimmedEmoji = emoji.trimmingCharacters(in: .whitespacesAndNewlines)
 
 guard !trimmedEmoji.isEmpty, !allEmojis.contains(trimmedEmoji) else {
 return false
 }
 
 customEmojis.append(trimmedEmoji)
 saveCustomEmojis()
 return true
 }
 
 private func loadCustomEmojis() {
 if let savedEmojis = UserDefaults.standard.array(forKey: customEmojisKey) as? [String] {
 customEmojis = savedEmojis
 }
 }
 
 private func saveCustomEmojis() {
 UserDefaults.standard.set(customEmojis, forKey: customEmojisKey)
 }
 
 func removeCustomEmoji(_ emoji: String) -> Bool {
 if let index = customEmojis.firstIndex(of: emoji) {
 customEmojis.remove(at: index)
 saveCustomEmojis()
 return true
 }
 return false
 }
 
 func isCustomEmoji(_ emoji: String) -> Bool {
 return customEmojis.contains(emoji)
 }
}