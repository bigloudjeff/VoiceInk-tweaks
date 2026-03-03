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
