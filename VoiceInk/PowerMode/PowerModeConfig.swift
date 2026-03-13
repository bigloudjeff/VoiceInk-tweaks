import Foundation
import KeyboardShortcuts
import os

struct PowerModeConfig: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var emoji: String
    var appConfigs: [AppConfig]?
    var urlConfigs: [URLConfig]?
    var isAIEnhancementEnabled: Bool
    var selectedPrompt: String?
    var selectedTranscriptionModelName: String?
    var selectedLanguage: String?
    var useScreenCapture: Bool
    var useClipboardContext: Bool
    var selectedAIProvider: String?
    var selectedAIModel: String?
    var isAutoSendEnabled: Bool = false
    var systemInstructions: String? = nil
    var isEnabled: Bool = true
    var isDefault: Bool = false
    var hotkeyShortcut: String? = nil
        
    enum CodingKeys: String, CodingKey {
        case id, name, emoji, appConfigs, urlConfigs, isAIEnhancementEnabled, selectedPrompt, selectedLanguage, useScreenCapture, useClipboardContext, selectedAIProvider, selectedAIModel, isAutoSendEnabled, systemInstructions, isEnabled, isDefault, hotkeyShortcut
        case selectedWhisperModel
        case selectedTranscriptionModelName
    }
    
    init(id: UUID = UUID(), name: String, emoji: String, appConfigs: [AppConfig]? = nil,
         urlConfigs: [URLConfig]? = nil, isAIEnhancementEnabled: Bool, selectedPrompt: String? = nil,
         selectedTranscriptionModelName: String? = nil, selectedLanguage: String? = nil, useScreenCapture: Bool = false, useClipboardContext: Bool = false,
         selectedAIProvider: String? = nil, selectedAIModel: String? = nil, isAutoSendEnabled: Bool = false,
         systemInstructions: String? = nil, isEnabled: Bool = true, isDefault: Bool = false, hotkeyShortcut: String? = nil) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.appConfigs = appConfigs
        self.urlConfigs = urlConfigs
        self.isAIEnhancementEnabled = isAIEnhancementEnabled
        self.selectedPrompt = selectedPrompt
        self.useScreenCapture = useScreenCapture
        self.useClipboardContext = useClipboardContext
        self.isAutoSendEnabled = isAutoSendEnabled
        self.systemInstructions = systemInstructions
        self.selectedAIProvider = selectedAIProvider
        self.selectedAIModel = selectedAIModel
        self.selectedTranscriptionModelName = selectedTranscriptionModelName
        self.selectedLanguage = selectedLanguage
        self.isEnabled = isEnabled
        self.isDefault = isDefault
        self.hotkeyShortcut = hotkeyShortcut
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        emoji = try container.decode(String.self, forKey: .emoji)
        appConfigs = try container.decodeIfPresent([AppConfig].self, forKey: .appConfigs)
        urlConfigs = try container.decodeIfPresent([URLConfig].self, forKey: .urlConfigs)
        isAIEnhancementEnabled = try container.decode(Bool.self, forKey: .isAIEnhancementEnabled)
        selectedPrompt = try container.decodeIfPresent(String.self, forKey: .selectedPrompt)
        selectedLanguage = try container.decodeIfPresent(String.self, forKey: .selectedLanguage)
        useScreenCapture = try container.decode(Bool.self, forKey: .useScreenCapture)
        useClipboardContext = try container.decodeIfPresent(Bool.self, forKey: .useClipboardContext) ?? false
        selectedAIProvider = try container.decodeIfPresent(String.self, forKey: .selectedAIProvider)
        selectedAIModel = try container.decodeIfPresent(String.self, forKey: .selectedAIModel)
        isAutoSendEnabled = try container.decodeIfPresent(Bool.self, forKey: .isAutoSendEnabled) ?? false
        systemInstructions = try container.decodeIfPresent(String.self, forKey: .systemInstructions)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        isDefault = try container.decodeIfPresent(Bool.self, forKey: .isDefault) ?? false
        hotkeyShortcut = try container.decodeIfPresent(String.self, forKey: .hotkeyShortcut)

        if let newModelName = try container.decodeIfPresent(String.self, forKey: .selectedTranscriptionModelName) {
            selectedTranscriptionModelName = newModelName
        } else if let oldModelName = try container.decodeIfPresent(String.self, forKey: .selectedWhisperModel) {
            selectedTranscriptionModelName = oldModelName
        } else {
            selectedTranscriptionModelName = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(emoji, forKey: .emoji)
        try container.encodeIfPresent(appConfigs, forKey: .appConfigs)
        try container.encodeIfPresent(urlConfigs, forKey: .urlConfigs)
        try container.encode(isAIEnhancementEnabled, forKey: .isAIEnhancementEnabled)
        try container.encodeIfPresent(selectedPrompt, forKey: .selectedPrompt)
        try container.encodeIfPresent(selectedLanguage, forKey: .selectedLanguage)
        try container.encode(useScreenCapture, forKey: .useScreenCapture)
        try container.encode(useClipboardContext, forKey: .useClipboardContext)
        try container.encodeIfPresent(selectedAIProvider, forKey: .selectedAIProvider)
        try container.encodeIfPresent(selectedAIModel, forKey: .selectedAIModel)
        try container.encode(isAutoSendEnabled, forKey: .isAutoSendEnabled)
        try container.encodeIfPresent(systemInstructions, forKey: .systemInstructions)
        try container.encodeIfPresent(selectedTranscriptionModelName, forKey: .selectedTranscriptionModelName)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(isDefault, forKey: .isDefault)
        try container.encodeIfPresent(hotkeyShortcut, forKey: .hotkeyShortcut)
    }

}


struct AppConfig: Codable, Identifiable, Equatable {
    let id: UUID
    var bundleIdentifier: String
    var appName: String
    
    init(id: UUID = UUID(), bundleIdentifier: String, appName: String) {
        self.id = id
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
    }

}

struct URLConfig: Codable, Identifiable, Equatable {
    let id: UUID
    var url: String
    
    init(id: UUID = UUID(), url: String) {
        self.id = id
        self.url = url
    }

}

class PowerModeManager: ObservableObject, PowerModeProviding {
    static let shared = PowerModeManager()
    private let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "PowerModeManager")
    @Published var configurations: [PowerModeConfig] = []
    @Published var activeConfiguration: PowerModeConfig?
    /// Set to true when a Power Mode config is being edited with unsaved changes.
    @Published var hasUnsavedEdits = false

    private let configKey = UserDefaults.Keys.powerModeConfigurations
    private let activeConfigIdKey = UserDefaults.Keys.activeConfigurationId

    private init() {
        loadConfigurations()

        if let activeConfigIdString = UserDefaults.standard.string(forKey: activeConfigIdKey),
           let activeConfigId = UUID(uuidString: activeConfigIdString) {
            activeConfiguration = configurations.first { $0.id == activeConfigId }
        } else {
            activeConfiguration = nil
        }
    }

    private func loadConfigurations() {
        guard let data = UserDefaults.standard.data(forKey: configKey) else { return }
        do {
            configurations = try JSONDecoder().decode([PowerModeConfig].self, from: data)
        } catch {
            logger.error("Failed to decode power mode configurations: \(error.localizedDescription, privacy: .public)")
        }
    }

    func saveConfigurations() {
        do {
            let data = try JSONEncoder().encode(configurations)
            UserDefaults.standard.set(data, forKey: configKey)
        } catch {
            logger.error("Failed to encode power mode configurations: \(error.localizedDescription, privacy: .public)")
        }
        NotificationCenter.default.post(name: .powerModeConfigurationsDidChange, object: nil)
    }

    func addConfiguration(_ config: PowerModeConfig) {
        if !configurations.contains(where: { $0.id == config.id }) {
            configurations.append(config)
            saveConfigurations()
        }
    }

    func removeConfiguration(with id: UUID) {
        KeyboardShortcuts.setShortcut(nil, for: .powerMode(id: id))
        configurations.removeAll { $0.id == id }
        saveConfigurations()
    }

    func getConfiguration(with id: UUID) -> PowerModeConfig? {
        return configurations.first { $0.id == id }
    }

    func updateConfiguration(_ config: PowerModeConfig) {
        if let index = configurations.firstIndex(where: { $0.id == config.id }) {
            configurations[index] = config
            saveConfigurations()
        }
    }

    func moveConfigurations(fromOffsets: IndexSet, toOffset: Int) {
        configurations.move(fromOffsets: fromOffsets, toOffset: toOffset)
        saveConfigurations()
    }

    func getConfigurationForURL(_ url: String) -> PowerModeConfig? {
        PowerModeManager.matchURL(url, in: configurations)
    }

    /// Pure URL matching: find the first enabled config whose URL pattern matches at a domain boundary.
    static func matchURL(_ url: String, in configs: [PowerModeConfig]) -> PowerModeConfig? {
        let cleanedURL = cleanURL(url)
        for config in configs where config.isEnabled {
            if let urlConfigs = config.urlConfigs {
                for urlConfig in urlConfigs {
                    if urlMatchesPattern(cleanedURL, pattern: cleanURL(urlConfig.url)) {
                        return config
                    }
                }
            }
        }
        return nil
    }

    /// Check if a cleaned URL matches a pattern at domain boundaries.
    /// Prevents "evil-example.com" from matching a pattern of "example.com".
    static func urlMatchesPattern(_ url: String, pattern: String) -> Bool {
        guard !pattern.isEmpty else { return false }
        // Match at start: exact match or pattern followed by path/query/fragment
        if url.hasPrefix(pattern) {
            let rest = url.dropFirst(pattern.count)
            if rest.isEmpty || rest.first == "/" || rest.first == "?" || rest.first == "#" {
                return true
            }
        }
        // Match after subdomain boundary (e.g. "sub.example.com" matches "example.com")
        let dotPattern = "." + pattern
        if let range = url.range(of: dotPattern) {
            let rest = url[range.upperBound...]
            if rest.isEmpty || rest.first == "/" || rest.first == "?" || rest.first == "#" {
                return true
            }
        }
        return false
    }
    
    func getConfigurationForApp(_ bundleId: String) -> PowerModeConfig? {
        for config in configurations.filter({ $0.isEnabled }) {
            if let appConfigs = config.appConfigs {
                if appConfigs.contains(where: { $0.bundleIdentifier == bundleId }) {
                    return config
                }
            }
        }
        return nil
    }
    
    func getDefaultConfiguration() -> PowerModeConfig? {
        return configurations.first { $0.isEnabled && $0.isDefault }
    }
    
    func hasDefaultConfiguration() -> Bool {
        return configurations.contains { $0.isDefault }
    }
    
    func setAsDefault(configId: UUID, skipSave: Bool = false) {
        for index in configurations.indices {
            configurations[index].isDefault = false
        }

        if let index = configurations.firstIndex(where: { $0.id == configId }) {
            configurations[index].isDefault = true
        }

        if !skipSave {
            saveConfigurations()
        }
    }
    
    func enableConfiguration(with id: UUID) {
        if let index = configurations.firstIndex(where: { $0.id == id }) {
            configurations[index].isEnabled = true
            saveConfigurations()
        }
    }
    
    func disableConfiguration(with id: UUID) {
        if let index = configurations.firstIndex(where: { $0.id == id }) {
            configurations[index].isEnabled = false
            saveConfigurations()
        }
    }
    
    var enabledConfigurations: [PowerModeConfig] {
        return configurations.filter { $0.isEnabled }
    }

    func addAppConfig(_ appConfig: AppConfig, to config: PowerModeConfig) {
        if var updatedConfig = configurations.first(where: { $0.id == config.id }) {
            var configs = updatedConfig.appConfigs ?? []
            configs.append(appConfig)
            updatedConfig.appConfigs = configs
            updateConfiguration(updatedConfig)
        }
    }

    func removeAppConfig(_ appConfig: AppConfig, from config: PowerModeConfig) {
        if var updatedConfig = configurations.first(where: { $0.id == config.id }) {
            updatedConfig.appConfigs?.removeAll(where: { $0.id == appConfig.id })
            updateConfiguration(updatedConfig)
        }
    }

    func addURLConfig(_ urlConfig: URLConfig, to config: PowerModeConfig) {
        if var updatedConfig = configurations.first(where: { $0.id == config.id }) {
            var configs = updatedConfig.urlConfigs ?? []
            configs.append(urlConfig)
            updatedConfig.urlConfigs = configs
            updateConfiguration(updatedConfig)
        }
    }

    func removeURLConfig(_ urlConfig: URLConfig, from config: PowerModeConfig) {
        if var updatedConfig = configurations.first(where: { $0.id == config.id }) {
            updatedConfig.urlConfigs?.removeAll(where: { $0.id == urlConfig.id })
            updateConfiguration(updatedConfig)
        }
    }

    static func cleanURL(_ url: String) -> String {
        url.lowercased()
            .replacingOccurrences(of: "https://", with: "")
            .replacingOccurrences(of: "http://", with: "")
            .replacingOccurrences(of: "www.", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func cleanURL(_ url: String) -> String {
        Self.cleanURL(url)
    }

    func setActiveConfiguration(_ config: PowerModeConfig?) {
        activeConfiguration = config
        UserDefaults.standard.set(config?.id.uuidString, forKey: activeConfigIdKey)
        self.objectWillChange.send()
    }

    var currentActiveConfiguration: PowerModeConfig? {
        return activeConfiguration
    }

    func getAllAvailableConfigurations() -> [PowerModeConfig] {
        return configurations
    }

    func isEmojiInUse(_ emoji: String) -> Bool {
        return configurations.contains { $0.emoji == emoji }
    }
} 