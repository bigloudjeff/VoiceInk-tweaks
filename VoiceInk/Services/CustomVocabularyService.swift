import Foundation
import SwiftUI
import SwiftData
import os

class CustomVocabularyService {
    static let shared = CustomVocabularyService()
    private let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "CustomVocabularyService")

    private init() {}

    func getCustomVocabulary(from context: ModelContext) -> String {
        let descriptor = FetchDescriptor<VocabularyWord>(sortBy: [SortDescriptor(\VocabularyWord.word)])
        let items = context.safeFetch(descriptor, context: "custom vocabulary", logger: logger)
        guard !items.isEmpty else {
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
        let items = context.safeFetch(descriptor, context: "transcription vocabulary", logger: logger)
        guard !items.isEmpty else {
            return ""
        }

        let words = items.map { $0.word }
        return words.joined(separator: ", ")
    }

    func existingWords(from context: ModelContext) -> Set<String> {
        let descriptor = FetchDescriptor<VocabularyWord>(sortBy: [SortDescriptor(\VocabularyWord.word)])
        let items = context.safeFetch(descriptor, context: "existing words", logger: logger)
        return Set(items.map { $0.word.lowercased() })
    }

    func getUniqueTerms(from context: ModelContext, limit: Int? = nil) -> [String] {
        let descriptor = FetchDescriptor<VocabularyWord>(sortBy: [SortDescriptor(\VocabularyWord.word)])
        let vocabularyWords = context.safeFetch(descriptor, context: "unique terms", logger: logger)
        guard !vocabularyWords.isEmpty else {
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

    /// Parse comma-separated input, check for duplicates, insert new words.
    /// Returns lists of added words and skipped duplicates.
    @MainActor
    func addWords(_ input: String, phoneticHints: String? = nil, in container: ModelContainer) -> (added: [String], duplicates: [String]) {
        let context = container.mainContext
        let parts = input
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !parts.isEmpty else { return ([], []) }

        let existing = existingWords(from: context)
        var added: [String] = []
        var duplicates: [String] = []

        for word in parts {
            if existing.contains(word.lowercased()) {
                duplicates.append(word)
            } else {
                let hints = phoneticHints?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let entry = VocabularyWord(word: word, phoneticHints: hints)
                context.insert(entry)
                added.append(word)
            }
        }

        if !added.isEmpty {
            do {
                try context.save()
                NotificationCenter.default.post(name: .promptDidChange, object: nil)
            } catch {
                logger.error("Failed to save vocabulary words: \(error.localizedDescription, privacy: .public)")
                // Rollback inserted words
                context.rollback()
                return ([], [])
            }
        }

        return (added, duplicates)
    }

    /// Remove a word (case-insensitive match). Returns true if found and deleted.
    @MainActor
    func removeWord(_ word: String, from container: ModelContainer) -> Bool {
        let context = container.mainContext
        let trimmed = word.trimmingCharacters(in: .whitespacesAndNewlines)
        let descriptor = FetchDescriptor<VocabularyWord>(sortBy: [SortDescriptor(\VocabularyWord.word)])
        let items = context.safeFetch(descriptor, context: "remove vocabulary word", logger: logger)

        guard let match = items.first(where: { $0.word.lowercased() == trimmed.lowercased() }) else {
            return false
        }

        context.delete(match)
        do {
            try context.save()
            NotificationCenter.default.post(name: .promptDidChange, object: nil)
            return true
        } catch {
            logger.error("Failed to remove vocabulary word: \(error.localizedDescription, privacy: .public)")
            context.rollback()
            return false
        }
    }

    /// List all vocabulary words sorted alphabetically.
    @MainActor
    func listWords(from container: ModelContainer) -> [String] {
        let context = container.mainContext
        let descriptor = FetchDescriptor<VocabularyWord>(sortBy: [SortDescriptor(\VocabularyWord.word)])
        let items = context.safeFetch(descriptor, context: "list vocabulary words", logger: logger)
        return items.map { $0.word }
    }

    private func getCustomVocabularyWords(from context: ModelContext) -> [String]? {
        let descriptor = FetchDescriptor<VocabularyWord>(sortBy: [SortDescriptor(\VocabularyWord.word)])
        let items = context.safeFetch(descriptor, context: "custom vocabulary words", logger: logger)
        let words = items.map { $0.word }
        return words.isEmpty ? nil : words
    }
}
