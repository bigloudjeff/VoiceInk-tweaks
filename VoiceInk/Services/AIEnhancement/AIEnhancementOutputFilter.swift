import Foundation

struct AIEnhancementOutputFilter {
    private static let thinkingRegexes: [NSRegularExpression] = {
        [
            #"(?s)<thinking>(.*?)</thinking>"#,
            #"(?s)<think>(.*?)</think>"#,
            #"(?s)<reasoning>(.*?)</reasoning>"#
        ].compactMap { try? NSRegularExpression(pattern: $0) }
    }()

    static func filter(_ text: String) -> String {
        var processedText = text

        for regex in thinkingRegexes {
            let range = NSRange(processedText.startIndex..., in: processedText)
            processedText = regex.stringByReplacingMatches(in: processedText, options: [], range: range, withTemplate: "")
        }
        
        return processedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
} 