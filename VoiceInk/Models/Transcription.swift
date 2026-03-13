import Foundation
import SwiftData

enum TranscriptionStatus: String, Codable {
    case pending
    case completed
    case failed
}

@Model
final class Transcription {
    var id: UUID
    var text: String
    var enhancedText: String?
    var timestamp: Date
    var duration: TimeInterval
    var audioFileURL: String?
    var transcriptionModelName: String?
    var aiEnhancementModelName: String?
    var promptName: String?
    var transcriptionDuration: TimeInterval?
    var enhancementDuration: TimeInterval?
    var aiRequestSystemMessage: String?
    var aiRequestUserMessage: String?
    var powerModeName: String?
    var powerModeEmoji: String?
    var transcriptionStatus: String?
    var isPinned: Bool = false
    var enhancementSource: String?
    var sttPrompt: String?
    var extractedVocabulary: String?
    var targetAppName: String?
    var targetAppBundleId: String?

    // MARK: - Forensic fields
    var rawTranscript: String?
    var aiProviderName: String?
    var promptText: String?
    var systemInstructionsSource: String?
    var powerModeSystemInstructions: String?
    var powerModePromptName: String?
    var fillerWordRemovalEnabled: Bool = false
    var fillerWordList: String?
    var screenCaptureEnabled: Bool = false
    var clipboardContextEnabled: Bool = false
    var outputFilterApplied: Bool = false

    init(text: String,
         duration: TimeInterval,
         enhancedText: String? = nil,
         audioFileURL: String? = nil,
         transcriptionModelName: String? = nil,
         aiEnhancementModelName: String? = nil,
         promptName: String? = nil,
         transcriptionDuration: TimeInterval? = nil,
         enhancementDuration: TimeInterval? = nil,
         aiRequestSystemMessage: String? = nil,
         aiRequestUserMessage: String? = nil,
         powerModeName: String? = nil,
         powerModeEmoji: String? = nil,
         transcriptionStatus: TranscriptionStatus = .pending) {
        self.id = UUID()
        self.text = text
        self.enhancedText = enhancedText
        self.timestamp = Date()
        self.duration = duration
        self.audioFileURL = audioFileURL
        self.transcriptionModelName = transcriptionModelName
        self.aiEnhancementModelName = aiEnhancementModelName
        self.promptName = promptName
        self.transcriptionDuration = transcriptionDuration
        self.enhancementDuration = enhancementDuration
        self.aiRequestSystemMessage = aiRequestSystemMessage
        self.aiRequestUserMessage = aiRequestUserMessage
        self.powerModeName = powerModeName
        self.powerModeEmoji = powerModeEmoji
        self.transcriptionStatus = transcriptionStatus.rawValue
    }

    /// Strips sensitive transient context (screen OCR, clipboard content) from a
    /// system message before persisting. The `screenCaptureEnabled` and
    /// `clipboardContextEnabled` booleans still record whether context was used.
    static func redactSensitiveContext(_ message: String?) -> String? {
        guard var text = message else { return nil }
        // Redact <CURRENT_WINDOW_CONTEXT>...</CURRENT_WINDOW_CONTEXT>
        if let range = text.range(of: #"<CURRENT_WINDOW_CONTEXT>[\s\S]*?</CURRENT_WINDOW_CONTEXT>"#, options: .regularExpression) {
            text.replaceSubrange(range, with: "<CURRENT_WINDOW_CONTEXT>[redacted]</CURRENT_WINDOW_CONTEXT>")
        }
        // Redact <CLIPBOARD_CONTEXT>...</CLIPBOARD_CONTEXT>
        if let range = text.range(of: #"<CLIPBOARD_CONTEXT>[\s\S]*?</CLIPBOARD_CONTEXT>"#, options: .regularExpression) {
            text.replaceSubrange(range, with: "<CLIPBOARD_CONTEXT>[redacted]</CLIPBOARD_CONTEXT>")
        }
        return text
    }
}
