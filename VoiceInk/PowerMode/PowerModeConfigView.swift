import SwiftUI
import KeyboardShortcuts

struct ConfigurationView: View {
 let mode: ConfigurationMode
 let powerModeManager: PowerModeManager
 @EnvironmentObject var enhancementService: AIEnhancementService
 @EnvironmentObject var aiService: AIService
 @Environment(\.presentationMode) private var presentationMode
 @FocusState private var isNameFieldFocused: Bool
 
 // State for configuration
 @State private var configName: String = "New Power Mode"
 @State private var selectedEmoji: String = ""
 @State private var isShowingEmojiPicker = false
 @State private var isShowingAppPicker = false
 @State private var isAIEnhancementEnabled: Bool
 @State private var selectedPromptId: UUID?
 @State private var selectedTranscriptionModelName: String?
 @State private var selectedLanguage: String?
 @State private var installedApps: [(url: URL, name: String, bundleId: String, icon: NSImage)] = []
 @State private var searchText = ""
 
 // Validation state
 @State private var validationErrors: [PowerModeValidationError] = []
 @State private var showValidationAlert = false
 
 // New state for AI provider and model
 @State private var selectedAIProvider: String?
 @State private var selectedAIModel: String?
 
 // App and Website configurations
 @State private var selectedAppConfigs: [AppConfig] = []
 @State private var websiteConfigs: [URLConfig] = []
 @State private var newWebsiteURL: String = ""
 
 // New state for context toggles
 @State private var useScreenCapture = false
 @State private var useClipboardContext = false
 @State private var isAutoSendEnabled = false
 @State private var isDefault = false
 @State private var systemInstructions: String? = nil
 
 @State private var isShowingDeleteConfirmation = false
 @State private var hasChanges = false

 // PowerMode hotkey configuration
 @State private var powerModeConfigId: UUID = UUID()

 private func languageSelectionDisabled() -> Bool {
 guard let selectedModelName = effectiveModelName,
 let model = whisperState.allAvailableModels.first(where: { $0.name == selectedModelName })
 else {
 return false
 }
 return model.provider == .parakeet || model.provider == .gemini
 }
 
 // Whisper state for model selection
 @EnvironmentObject private var whisperState: WhisperState
 
 // Computed property to check if current config is the default
 private var isCurrentConfigDefault: Bool {
 if case .edit(let config) = mode {
 return config.isDefault
 }
 return false
 }
 
 private var filteredApps: [(url: URL, name: String, bundleId: String, icon: NSImage)] {
 if searchText.isEmpty {
 return installedApps
 }
 return installedApps.filter { app in
 app.name.localizedCaseInsensitiveContains(searchText) ||
 app.bundleId.localizedCaseInsensitiveContains(searchText)
 }
 }
 
 // Simplified computed property for effective model name
 private var effectiveModelName: String? {
 if let model = selectedTranscriptionModelName {
 return model
 }
 return whisperState.currentTranscriptionModel?.name
 }
 
 init(mode: ConfigurationMode, powerModeManager: PowerModeManager) {
 self.mode = mode
 self.powerModeManager = powerModeManager

 // Always fetch the most current configuration data
 switch mode {
 case .add:
 let newId = UUID()
 _powerModeConfigId = State(initialValue: newId)
 _isAIEnhancementEnabled = State(initialValue: false)
 _selectedPromptId = State(initialValue: nil)
 _selectedTranscriptionModelName = State(initialValue: nil)
 _selectedLanguage = State(initialValue: nil)
 _configName = State(initialValue: "")
 _selectedEmoji = State(initialValue: "\u{2728}")
 _useScreenCapture = State(initialValue: false)
 _isAutoSendEnabled = State(initialValue: false)
 _isDefault = State(initialValue: false)
 // Default to current global AI provider/model for new configurations - use UserDefaults only
 _selectedAIProvider = State(initialValue: UserDefaults.standard.string(forKey: UserDefaults.Keys.selectedAIProvider))
 _selectedAIModel = State(initialValue: nil) // Initialize to nil and set it after view appears
 case .edit(let config):
 // Get the latest version of this config from PowerModeManager
 let latestConfig = powerModeManager.getConfiguration(with: config.id) ?? config
 _powerModeConfigId = State(initialValue: latestConfig.id)
 _isAIEnhancementEnabled = State(initialValue: latestConfig.isAIEnhancementEnabled)
 _selectedPromptId = State(initialValue: latestConfig.selectedPrompt.flatMap { UUID(uuidString: $0) })
 _selectedTranscriptionModelName = State(initialValue: latestConfig.selectedTranscriptionModelName)
 _selectedLanguage = State(initialValue: latestConfig.selectedLanguage)
 _configName = State(initialValue: latestConfig.name)
 _selectedEmoji = State(initialValue: latestConfig.emoji)
 _selectedAppConfigs = State(initialValue: latestConfig.appConfigs ?? [])
 _websiteConfigs = State(initialValue: latestConfig.urlConfigs ?? [])
 _useScreenCapture = State(initialValue: latestConfig.useScreenCapture)
 _useClipboardContext = State(initialValue: latestConfig.useClipboardContext)
 _isAutoSendEnabled = State(initialValue: latestConfig.isAutoSendEnabled)
 _isDefault = State(initialValue: latestConfig.isDefault)
 _selectedAIProvider = State(initialValue: latestConfig.selectedAIProvider)
 _selectedAIModel = State(initialValue: latestConfig.selectedAIModel)
 _systemInstructions = State(initialValue: latestConfig.systemInstructions)
 }
 }
 
 private var configForm: some View {
 Form {
  Section("General") {
   HStack(spacing: 12) {
    Button {
     isShowingEmojiPicker.toggle()
    } label: {
     Text(selectedEmoji)
      .font(.system(size: 22))
      .frame(width: 32, height: 32)
      .background(
       RoundedRectangle(cornerRadius: 8)
        .fill(Color(NSColor.controlBackgroundColor))
      )
    }
    .buttonStyle(.plain)
    .accessibilityIdentifier(AccessibilityID.PowerModeConfig.buttonEmoji)
    .popover(isPresented: $isShowingEmojiPicker, arrowEdge: .bottom) {
     EmojiPickerView(
      selectedEmoji: $selectedEmoji,
      isPresented: $isShowingEmojiPicker
     )
    }

    TextField("Name", text: $configName)
     .textFieldStyle(.roundedBorder)
     .focused($isNameFieldFocused)
     .accessibilityIdentifier(AccessibilityID.PowerModeConfig.fieldName)
   }
  }

  PowerModeTriggerSection(
   selectedAppConfigs: $selectedAppConfigs,
   websiteConfigs: $websiteConfigs,
   newWebsiteURL: $newWebsiteURL,
   isShowingAppPicker: $isShowingAppPicker,
   loadInstalledApps: loadInstalledApps,
   addWebsite: addWebsite
  )

  PowerModeTranscriptionSection(
   selectedTranscriptionModelName: $selectedTranscriptionModelName,
   selectedLanguage: $selectedLanguage,
   effectiveModelName: effectiveModelName,
   languageSelectionDisabled: languageSelectionDisabled()
  )

  PowerModeAIEnhancementSection(
   isAIEnhancementEnabled: $isAIEnhancementEnabled,
   selectedAIProvider: $selectedAIProvider,
   selectedAIModel: $selectedAIModel,
   selectedPromptId: $selectedPromptId,
   useScreenCapture: $useScreenCapture,
   useClipboardContext: $useClipboardContext,
   systemInstructions: $systemInstructions
  )

  PowerModeAdvancedSection(
   isDefault: $isDefault,
   isAutoSendEnabled: $isAutoSendEnabled,
   powerModeConfigId: powerModeConfigId
  )
 }
 .formStyle(.grouped)
 .scrollContentBackground(.hidden)
 .background(Color(NSColor.controlBackgroundColor))
 }

 var body: some View {
 configForm
 .navigationTitle(mode.title)
 .toolbar {
 ToolbarItem(placement: .primaryAction) {
 Button("Save") {
 saveConfiguration()
 }
 .accessibilityIdentifier(AccessibilityID.PowerModeConfig.buttonSave)
 .keyboardShortcut(.defaultAction)
 .disabled(!canSave)
 .buttonStyle(.bordered)
 .controlSize(.regular)
 .padding(.horizontal, 4)
 }

 if case .edit = mode {
 ToolbarItem {
 Button("Delete", role: .destructive) {
 isShowingDeleteConfirmation = true
 }
 .accessibilityIdentifier(AccessibilityID.PowerModeConfig.buttonDelete)
 .buttonStyle(.bordered)
 .controlSize(.regular)
 .padding(.horizontal, 4)
 }
 }
 }
 .confirmationDialog(
 "Delete Power Mode?",
 isPresented: $isShowingDeleteConfirmation,
 titleVisibility: .visible
 ) {
 if case .edit(let config) = mode {
 Button("Delete", role: .destructive) {
 powerModeManager.removeConfiguration(with: config.id)
 presentationMode.wrappedValue.dismiss()
 }
 }
 Button("Cancel", role: .cancel) { }
 } message: {
 if case .edit(let config) = mode {
 Text("Are you sure you want to delete the '\(config.name)' power mode? This action cannot be undone.")
 }
 }
 .sheet(isPresented: $isShowingAppPicker) {
 AppPickerSheet(
 installedApps: filteredApps,
 selectedAppConfigs: $selectedAppConfigs,
 searchText: $searchText,
 onDismiss: { isShowingAppPicker = false }
 )
 }
 .powerModeValidationAlert(errors: validationErrors, isPresented: $showValidationAlert)
 .onAppear {
 if case .add = mode {
 if selectedAIProvider == nil {
 selectedAIProvider = aiService.selectedProvider.rawValue
 }
 if selectedAIModel == nil || selectedAIModel?.isEmpty == true {
 selectedAIModel = aiService.currentModel
 }
 }
 if isAIEnhancementEnabled && selectedPromptId == nil {
 selectedPromptId = enhancementService.allPrompts.first?.id
 }
 DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
 isNameFieldFocused = true
 }
 }
 .modifier(ChangeTracker(
  configName: configName,
  selectedEmoji: selectedEmoji,
  isAIEnhancementEnabled: isAIEnhancementEnabled,
  selectedPromptId: selectedPromptId,
  selectedTranscriptionModelName: selectedTranscriptionModelName,
  selectedLanguage: selectedLanguage,
  selectedAIProvider: selectedAIProvider,
  selectedAIModel: selectedAIModel,
  useScreenCapture: useScreenCapture,
  useClipboardContext: useClipboardContext,
  isAutoSendEnabled: isAutoSendEnabled,
  isDefault: isDefault,
  appConfigCount: selectedAppConfigs.count,
  websiteConfigCount: websiteConfigs.count,
  systemInstructions: systemInstructions,
  onChanged: markChanged
 ))
 .onDisappear {
  powerModeManager.hasUnsavedEdits = false
 }
 .onReceive(NotificationCenter.default.publisher(for: .powerModeConfigSaveRequested)) { notification in
  saveConfiguration()
  if let nextView = notification.object as? ViewType {
   DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
    NavigationDestination.view(nextView).post()
   }
  }
 }
 }
 
 private var canSave: Bool {
 return !configName.isEmpty
 }

 private func markChanged() {
  hasChanges = true
  powerModeManager.hasUnsavedEdits = true
 }
 
 private func addWebsite() {
 guard !newWebsiteURL.isEmpty else { return }
 
 let cleanedURL = powerModeManager.cleanURL(newWebsiteURL)
 let urlConfig = URLConfig(url: cleanedURL)
 websiteConfigs.append(urlConfig)
 newWebsiteURL = ""
 }
 
 private func toggleAppSelection(_ app: (url: URL, name: String, bundleId: String, icon: NSImage)) {
 if let index = selectedAppConfigs.firstIndex(where: { $0.bundleIdentifier == app.bundleId }) {
 selectedAppConfigs.remove(at: index)
 } else {
 let appConfig = AppConfig(bundleIdentifier: app.bundleId, appName: app.name)
 selectedAppConfigs.append(appConfig)
 }
 }
 
 private func getConfigForForm() -> PowerModeConfig {
 let shortcut = KeyboardShortcuts.getShortcut(for: .powerMode(id: powerModeConfigId))
 let hotkeyString = shortcut != nil ? "configured" : nil

 switch mode {
 case .add:
 return PowerModeConfig(
 id: powerModeConfigId,
 name: configName,
 emoji: selectedEmoji,
 appConfigs: selectedAppConfigs.isEmpty ? nil : selectedAppConfigs,
 urlConfigs: websiteConfigs.isEmpty ? nil : websiteConfigs,
 isAIEnhancementEnabled: isAIEnhancementEnabled,
 selectedPrompt: selectedPromptId?.uuidString,
 selectedTranscriptionModelName: selectedTranscriptionModelName,
 selectedLanguage: selectedLanguage,
 useScreenCapture: useScreenCapture,
 useClipboardContext: useClipboardContext,
 selectedAIProvider: selectedAIProvider,
 selectedAIModel: selectedAIModel,
 isAutoSendEnabled: isAutoSendEnabled,
 systemInstructions: systemInstructions,
 isDefault: isDefault,
 hotkeyShortcut: hotkeyString
 )
 case .edit(let config):
 var updatedConfig = config
 updatedConfig.name = configName
 updatedConfig.emoji = selectedEmoji
 updatedConfig.isAIEnhancementEnabled = isAIEnhancementEnabled
 updatedConfig.selectedPrompt = selectedPromptId?.uuidString
 updatedConfig.selectedTranscriptionModelName = selectedTranscriptionModelName
 updatedConfig.selectedLanguage = selectedLanguage
 updatedConfig.appConfigs = selectedAppConfigs.isEmpty ? nil : selectedAppConfigs
 updatedConfig.urlConfigs = websiteConfigs.isEmpty ? nil : websiteConfigs
 updatedConfig.useScreenCapture = useScreenCapture
 updatedConfig.useClipboardContext = useClipboardContext
 updatedConfig.isAutoSendEnabled = isAutoSendEnabled
 updatedConfig.selectedAIProvider = selectedAIProvider
 updatedConfig.selectedAIModel = selectedAIModel
 updatedConfig.systemInstructions = systemInstructions
 updatedConfig.isDefault = isDefault
 updatedConfig.hotkeyShortcut = hotkeyString
 return updatedConfig
 }
 }
 
 private func loadInstalledApps() {
 // Get both user-installed and system applications
 let userAppURLs = FileManager.default.urls(for: .applicationDirectory, in: .userDomainMask)
 let localAppURLs = FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask)
 let systemAppURLs = FileManager.default.urls(for: .applicationDirectory, in: .systemDomainMask)
 let allAppURLs = userAppURLs + localAppURLs + systemAppURLs
 
 var allApps: [URL] = []
 
 func scanDirectory(_ baseURL: URL, depth: Int = 0) {
 // Prevent infinite recursion in case of circular symlinks
 guard depth < 5 else { return }
 
 guard let enumerator = FileManager.default.enumerator(
 at: baseURL,
 includingPropertiesForKeys: [.isApplicationKey, .isDirectoryKey, .isSymbolicLinkKey],
 options: [.skipsHiddenFiles]
 ) else { return }
 
 for item in enumerator {
 guard let url = item as? URL else { continue }
 
 let resolvedURL = url.resolvingSymlinksInPath()
 
 // If it's an app, add it and skip descending into it
 if resolvedURL.pathExtension == "app" {
 allApps.append(resolvedURL)
 enumerator.skipDescendants()
 continue
 }
 
 // Check if this is a symlinked directory we should traverse manually
 var isDirectory: ObjCBool = false
 if url != resolvedURL && 
 FileManager.default.fileExists(atPath: resolvedURL.path, isDirectory: &isDirectory) && 
 isDirectory.boolValue {
 // This is a symlinked directory - traverse it manually
 enumerator.skipDescendants()
 scanDirectory(resolvedURL, depth: depth + 1)
 }
 }
 }
 
 // Scan all app directories
 for baseURL in allAppURLs {
 scanDirectory(baseURL)
 }
 
 installedApps = allApps.compactMap { url in
 guard let bundle = Bundle(url: url),
 let bundleId = bundle.bundleIdentifier,
 let name = (bundle.infoDictionary?["CFBundleName"] as? String) ??
 (bundle.infoDictionary?["CFBundleDisplayName"] as? String) else {
 return nil
 }
 
 let icon = NSWorkspace.shared.icon(forFile: url.path)
 return (url: url, name: name, bundleId: bundleId, icon: icon)
 }
 .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
 }
 
 private func saveConfiguration() {
 
 
 let config = getConfigForForm()
 
 // Only validate when the user explicitly tries to save
 let validator = PowerModeValidator(powerModeManager: powerModeManager)
 validationErrors = validator.validateForSave(config: config, mode: mode)
 
 if !validationErrors.isEmpty {
 showValidationAlert = true
 return
 }
 
 if isDefault {
 powerModeManager.setAsDefault(configId: config.id, skipSave: true)
 }

 switch mode {
 case .add:
 powerModeManager.addConfiguration(config)
 case .edit:
 powerModeManager.updateConfiguration(config)
 }

 hasChanges = false
 powerModeManager.hasUnsavedEdits = false
 presentationMode.wrappedValue.dismiss()
 }
}

private struct ChangeTracker: ViewModifier {
 let configName: String
 let selectedEmoji: String
 let isAIEnhancementEnabled: Bool
 let selectedPromptId: UUID?
 let selectedTranscriptionModelName: String?
 let selectedLanguage: String?
 let selectedAIProvider: String?
 let selectedAIModel: String?
 let useScreenCapture: Bool
 let useClipboardContext: Bool
 let isAutoSendEnabled: Bool
 let isDefault: Bool
 let appConfigCount: Int
 let websiteConfigCount: Int
 let systemInstructions: String?
 let onChanged: () -> Void

 @State private var isInitialized = false

 func body(content: Content) -> some View {
  content
   .onChange(of: changeSignature) { _, _ in
    if isInitialized { onChanged() }
   }
   .onAppear {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
     isInitialized = true
    }
   }
 }

 private var changeSignature: String {
  "\(configName)|\(selectedEmoji)|\(isAIEnhancementEnabled)|\(selectedPromptId?.uuidString ?? "")|\(selectedTranscriptionModelName ?? "")|\(selectedLanguage ?? "")|\(selectedAIProvider ?? "")|\(selectedAIModel ?? "")|\(useScreenCapture)|\(useClipboardContext)|\(isAutoSendEnabled)|\(isDefault)|\(appConfigCount)|\(websiteConfigCount)|\(systemInstructions ?? "")"
 }
}
