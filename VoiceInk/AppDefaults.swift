import Foundation

enum AppDefaults {
    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            // Onboarding & General
            "hasCompletedOnboarding": false,
            "enableAnnouncements": true,
            "autoUpdateCheck": true,

            // Clipboard
            UserDefaults.Keys.restoreClipboardAfterPaste: true,
            UserDefaults.Keys.clipboardRestoreDelay: 0.25,
            UserDefaults.Keys.useAppleScriptPaste: false,
            UserDefaults.Keys.pasteMethod: "default",
            "typeOutDelay": 3.0,

            // Audio & Media
            UserDefaults.Keys.isSystemMuteEnabled: true,
            UserDefaults.Keys.audioResumptionDelay: 0.0,
            UserDefaults.Keys.isPauseMediaEnabled: false,
            "isSoundFeedbackEnabled": true,

            // Recording & Transcription
            UserDefaults.Keys.isTextFormattingEnabled: true,
            UserDefaults.Keys.isVADEnabled: true,
            "RemoveFillerWords": true,
            UserDefaults.Keys.selectedLanguage: "en",
            UserDefaults.Keys.appendTrailingSpace: true,
            UserDefaults.Keys.recorderType: "mini",
            UserDefaults.Keys.recorderScreenSelection: "mouseCursor",
            "warnNoTextField": true,

            // Cleanup
            UserDefaults.Keys.isTranscriptionCleanupEnabled: false,
            "TranscriptionRetentionMinutes": 1440,
            UserDefaults.Keys.isAudioCleanupEnabled: false,
            UserDefaults.Keys.audioRetentionPeriod: 7,

            // UI & Behavior
            UserDefaults.Keys.isMenuBarOnly: false,
            "powerModeAutoRestoreEnabled": false,
            // Hotkey
            UserDefaults.Keys.recordingMode: "hybrid",
            UserDefaults.Keys.companionModifier1: "none",
            UserDefaults.Keys.companionModifier2: "none",
            UserDefaults.Keys.isMiddleClickToggleEnabled: false,
            UserDefaults.Keys.middleClickActivationDelay: 200,

            // Enhancement
            UserDefaults.Keys.enhancementMode: "off",
            UserDefaults.Keys.isToggleEnhancementShortcutEnabled: true,
            UserDefaults.Keys.backgroundEnhancementEnabled: false,
            UserDefaults.Keys.vocabularyExtractionEnabled: true,
            "autoGeneratePhoneticHints": false,

            // Model
            "PrewarmModelOnWake": true,
        ])
    }
}
