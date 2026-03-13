import Foundation

/// Type-safe navigation destination for .navigateToDestination notifications.
/// Post via `NavigationDestination.post(.settings)` instead of raw strings.
enum NavigationDestination {
 case view(ViewType)
 case pipelineStage(PipelineStage)
 case historyWindow

 static let userInfoKey = "typedDestination"

 func post() {
  NotificationCenter.default.post(
   name: .navigateToDestination,
   object: nil,
   userInfo: [Self.userInfoKey: self]
  )
 }

 /// Convenience initializer from legacy string destinations.
 init?(legacyString: String) {
  switch legacyString {
  case "Settings", "Preferences": self = .view(.settings)
  case "AI Models": self = .pipelineStage(.speechToText)
  case "VoiceInk Pro": self = .view(.license)
  case "History": self = .historyWindow
  case "Permissions": self = .view(.permissions)
  case "Enhancement": self = .pipelineStage(.aiEnhancement)
  case "Post Processing": self = .pipelineStage(.textFormatting)
  case "Pipeline": self = .view(.pipeline)
  case "Transcribe Audio": self = .view(.transcribeAudio)
  case "Power Mode": self = .view(.powerMode)
  case "Dashboard": self = .view(.metrics)
  case "Dictionary": self = .pipelineStage(.wordReplacement)
  case "Audio Input": self = .pipelineStage(.recording)
  default: return nil
  }
 }
}

extension Notification.Name {
    static let AppSettingsDidChange = Notification.Name("appSettingsDidChange")
    static let languageDidChange = Notification.Name("languageDidChange")
    static let promptDidChange = Notification.Name("promptDidChange")
    static let toggleMiniRecorder = Notification.Name("toggleMiniRecorder")
    static let dismissMiniRecorder = Notification.Name("dismissMiniRecorder")
    static let didChangeModel = Notification.Name("didChangeModel")
    static let aiProviderKeyChanged = Notification.Name("aiProviderKeyChanged")
    static let licenseStatusChanged = Notification.Name("licenseStatusChanged")
    static let navigateToDestination = Notification.Name("navigateToDestination")
    static let promptSelectionChanged = Notification.Name("promptSelectionChanged")
    static let powerModeConfigurationApplied = Notification.Name("powerModeConfigurationApplied")
    static let transcriptionCreated = Notification.Name("transcriptionCreated")
    static let transcriptionCompleted = Notification.Name("transcriptionCompleted")
    static let transcriptionDeleted = Notification.Name("transcriptionDeleted")
    static let enhancementToggleChanged = Notification.Name("enhancementToggleChanged")
    static let openFileForTranscription = Notification.Name("openFileForTranscription")
    static let audioDeviceSwitchRequired = Notification.Name("audioDeviceSwitchRequired")
    static let backgroundEnhancementCompleted = Notification.Name("backgroundEnhancementCompleted")
    static let backgroundEnhancementFailed = Notification.Name("backgroundEnhancementFailed")
    static let vocabularySuggestionsUpdated = Notification.Name("vocabularySuggestionsUpdated")
    static let audioDeviceChanged = Notification.Name("AudioDeviceChanged")
    static let powerModeConfigurationsDidChange = Notification.Name("PowerModeConfigurationsDidChange")
    static let customSoundsChanged = Notification.Name("CustomSoundsChanged")
    static let powerModeConfigSaveRequested = Notification.Name("powerModeConfigSaveRequested")
    static let enhancementShortcutSettingChanged = Notification.Name("enhancementShortcutSettingChanged")
}
