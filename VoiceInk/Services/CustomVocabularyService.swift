import Foundation
import SwiftUI
import SwiftData

class CustomVocabularyService {
    static let shared = CustomVocabularyService()

    private init() {}

    func getCustomVocabulary(from context: ModelContext) -> String {
        let descriptor = FetchDescriptor<VocabularyWord>(sortBy: [SortDescriptor(\VocabularyWord.word)])
        guard let items = try? context.fetch(descriptor), !items.isEmpty else {
            return ""
        }

        let entries = items.map { item -> String in
            if !item.phoneticHints.isEmpty {
                return "\(item.word) (often heard as: \(item.phoneticHints))"
            }
            return item.word
        }

        return "Important Vocabulary: \(entries.joined(separator: ", "))"
    }

    func getTranscriptionVocabulary(from context: ModelContext) -> String {
        let descriptor = FetchDescriptor<VocabularyWord>(sortBy: [SortDescriptor(\VocabularyWord.word)])
        guard let items = try? context.fetch(descriptor), !items.isEmpty else {
            return ""
        }

        let words = items.map { $0.word }
        return words.joined(separator: ", ")
    }

    func existingWords(from context: ModelContext) -> Set<String> {
        let descriptor = FetchDescriptor<VocabularyWord>(sortBy: [SortDescriptor(\VocabularyWord.word)])
        guard let items = try? context.fetch(descriptor) else { return [] }
        return Set(items.map { $0.word.lowercased() })
    }

    func getUniqueTerms(from context: ModelContext, limit: Int? = nil) -> [String] {
        let descriptor = FetchDescriptor<VocabularyWord>(sortBy: [SortDescriptor(\VocabularyWord.word)])
        guard let vocabularyWords = try? context.fetch(descriptor) else {
            return []
        }
        var seen = Set<String>()
        var unique: [String] = []
        for word in vocabularyWords {
            let trimmed = word.word.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            if !seen.contains(key) {
                seen.insert(key)
                unique.append(trimmed)
            }
        }
        if let limit { return Array(unique.prefix(limit)) }
        return unique
    }

    private func getCustomVocabularyWords(from context: ModelContext) -> [String]? {
        let descriptor = FetchDescriptor<VocabularyWord>(sortBy: [SortDescriptor(\VocabularyWord.word)])

        do {
            let items = try context.fetch(descriptor)
            let words = items.map { $0.word }
            return words.isEmpty ? nil : words
        } catch {
            return nil
        }
    }
}
