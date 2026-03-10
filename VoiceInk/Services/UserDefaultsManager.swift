import Foundation

extension UserDefaults {
    enum Keys {
        static let audioInputMode = "audioInputMode"
        static let selectedAudioDeviceUID = "selectedAudioDeviceUID"
        static let prioritizedDevices = "prioritizedDevices"
        static let affiliatePromotionDismissed = "VoiceInkAffiliatePromotionDismissed"

        // Language & Transcription
        static let selectedLanguage = "SelectedLanguage"
        static let transcriptionPrompt = "TranscriptionPrompt"
        static let currentTranscriptionModel = "CurrentTranscriptionModel"
        static let isTranscriptionCleanupEnabled = "IsTranscriptionCleanupEnabled"

        // AI Provider & Enhancement
        static let selectedAIProvider = "selectedAIProvider"
        static let enhancementMode = "enhancementMode"
        static let backgroundEnhancementEnabled = "backgroundEnhancementEnabled"
        static let isToggleEnhancementShortcutEnabled = "isToggleEnhancementShortcutEnabled"
        static let selectedPromptId = "selectedPromptId"
        static let customPrompts = "customPrompts"
        static let systemInstructionsTemplate = "systemInstructionsTemplate"

        // Ollama
        static let ollamaSelectedModel = "ollamaSelectedModel"
        static let ollamaBaseURL = "ollamaBaseURL"

        // Custom Provider
        static let customProviderModel = "customProviderModel"
        static let customProviderBaseURL = "customProviderBaseURL"

        // OpenRouter
        static let openRouterModels = "openRouterModels"

        // Paste & Clipboard
        static let useAppleScriptPaste = "useAppleScriptPaste"
        static let restoreClipboardAfterPaste = "restoreClipboardAfterPaste"
        static let clipboardRestoreDelay = "clipboardRestoreDelay"
        static let pasteMethod = "pasteMethod"
        static let appendTrailingSpace = "AppendTrailingSpace"

        // License & Activation
        static let licenseRequiresActivation = "VoiceInkLicenseRequiresActivation"
        static let license = "VoiceInkLicense"
        static let deviceIdentifier = "VoiceInkDeviceIdentifier"
        static let activationsLimit = "VoiceInkActivationsLimit"
        static let activationId = "VoiceInkActivationId"

        // App Settings
        static let hasLaunchedBefore = "VoiceInkHasLaunchedBefore"
        static let isMenuBarOnly = "IsMenuBarOnly"
        static let isExperimentalFeaturesEnabled = "isExperimentalFeaturesEnabled"
        static let isTextFormattingEnabled = "IsTextFormattingEnabled"

        // Hotkeys & Shortcuts
        static let selectedHotkey1 = "selectedHotkey1"
        static let selectedHotkey2 = "selectedHotkey2"
        static let companionModifier1 = "companionModifier1"
        static let companionModifier2 = "companionModifier2"

        // Power Mode
        static let powerModeUIFlag = "powerModeUIFlag"

        // Vocabulary
        static let vocabularyExtractionEnabled = "vocabularyExtractionEnabled"
        static let vocabularySortMode = "vocabularySortMode"
        static let wordReplacementSortMode = "wordReplacementSortMode"

        // Screen & Context
        static let useScreenCaptureContext = "useScreenCaptureContext"
        static let useClipboardContext = "useClipboardContext"

        // Recording & Audio
        static let recordingMode = "recordingMode"
        static let recorderType = "RecorderType"
        static let recorderScreenSelection = "recorderScreenSelection"
        static let isSystemMuteEnabled = "isSystemMuteEnabled"
        static let isPauseMediaEnabled = "isPauseMediaEnabled"
        static let audioResumptionDelay = "audioResumptionDelay"
        static let audioRetentionPeriod = "AudioRetentionPeriod"
        static let isAudioCleanupEnabled = "IsAudioCleanupEnabled"
        static let lastUsedMicrophoneDeviceID = "lastUsedMicrophoneDeviceID"
        static let isVADEnabled = "IsVADEnabled"

        // Middle Click
        static let isMiddleClickToggleEnabled = "isMiddleClickToggleEnabled"
        static let middleClickActivationDelay = "middleClickActivationDelay"

        // Onboarding & Announcements
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let enableAnnouncements = "enableAnnouncements"
        static let autoUpdateCheck = "autoUpdateCheck"
        static let dismissedAnnouncementIds = "dismissedAnnouncementIds"

        // Sound & UI
        static let isSoundFeedbackEnabled = "isSoundFeedbackEnabled"
        static let typeOutDelay = "typeOutDelay"
        static let warnNoTextField = "warnNoTextField"

        // AI Enhancement (additional)
        static let isAIEnhancementEnabled = "isAIEnhancementEnabled"
        static let autoGeneratePhoneticHints = "autoGeneratePhoneticHints"

        // Transcription Cleanup
        static let transcriptionRetentionMinutes = "TranscriptionRetentionMinutes"
        static let removeFillerWords = "RemoveFillerWords"
        static let fillerWords = "FillerWords"
        static let removeTagBlocks = "RemoveTagBlocks"
        static let removeBracketedContent = "RemoveBracketedContent"

        // Model Prewarm
        static let prewarmModelOnWake = "PrewarmModelOnWake"
        static let prewarmEnhancementModel = "PrewarmEnhancementModel"
        static let prewarmInactivityThreshold = "PrewarmInactivityThreshold"

        // Power Mode (additional)
        static let powerModeAutoRestoreEnabled = "powerModeAutoRestoreEnabled"
        static let powerModeConfigurations = "powerModeConfigurationsV2"
        static let activeConfigurationId = "activeConfigurationId"
        static let powerModeActiveSession = "powerModeActiveSession.v1"

        // Custom Data
        static let customCloudModels = "customCloudModels"
        static let customEmojis = "userAddedEmojis"
        static let customLanguagePrompts = "CustomLanguagePrompts"
        static let predefinedPrompts = "PredefinedPrompts"

        // Migration Keys
        static let licenseKeychainMigrationCompleted = "LicenseKeychainMigrationCompleted"
        static let apiKeyMigrationCompleted = "APIKeyMigrationToKeychainCompleted_v2"
        static let dictionaryMigrationCompleted = "HasMigratedDictionaryToSwiftData_v2"
        static let dictionaryItems = "CustomVocabularyItems"
        static let wordReplacements = "wordReplacements"

        // Log Exporter
        static let logExporterSessions = "logExporter.sessionStartDates.v1"
    }

    // MARK: - Audio Input Mode
    var audioInputModeRawValue: String? {
        get { string(forKey: Keys.audioInputMode) }
        set { setValue(newValue, forKey: Keys.audioInputMode) }
    }

    // MARK: - Selected Audio Device UID
    var selectedAudioDeviceUID: String? {
        get { string(forKey: Keys.selectedAudioDeviceUID) }
        set { setValue(newValue, forKey: Keys.selectedAudioDeviceUID) }
    }

    // MARK: - Prioritized Devices
    var prioritizedDevicesData: Data? {
        get { data(forKey: Keys.prioritizedDevices) }
        set { setValue(newValue, forKey: Keys.prioritizedDevices) }
    }

    // MARK: - Affiliate Promotion Dismissal
    var affiliatePromotionDismissed: Bool {
        get { bool(forKey: Keys.affiliatePromotionDismissed) }
        set { setValue(newValue, forKey: Keys.affiliatePromotionDismissed) }
    }
}
