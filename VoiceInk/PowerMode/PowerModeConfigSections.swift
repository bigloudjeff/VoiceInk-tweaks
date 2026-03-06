import SwiftUI
import KeyboardShortcuts

// MARK: - Trigger Scenarios Section

struct PowerModeTriggerSection: View {
 @Binding var selectedAppConfigs: [AppConfig]
 @Binding var websiteConfigs: [URLConfig]
 @Binding var newWebsiteURL: String
 @Binding var isShowingAppPicker: Bool
 let loadInstalledApps: () -> Void
 let addWebsite: () -> Void

 var body: some View {
  Section("Trigger Scenarios") {
   VStack(alignment: .leading, spacing: 10) {
    HStack {
     Text("Applications")
     Spacer()
     AddIconButton(helpText: "Add application") {
      loadInstalledApps()
      isShowingAppPicker = true
     }
    }

    if selectedAppConfigs.isEmpty {
     Text("No applications added")
      .foregroundColor(.secondary)
      .font(.subheadline)
    } else {
     LazyVGrid(columns: [GridItem(.adaptive(minimum: 44, maximum: 50), spacing: 10)], spacing: 10) {
      ForEach(selectedAppConfigs) { appConfig in
       ZStack(alignment: .topTrailing) {
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: appConfig.bundleIdentifier) {
         Image(nsImage: NSWorkspace.shared.icon(forFile: appURL.path))
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(width: 44, height: 44)
          .clipShape(RoundedRectangle(cornerRadius: 10))
        } else {
         Image(systemName: "app.fill")
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(width: 26, height: 26)
          .frame(width: 44, height: 44)
          .background(
           RoundedRectangle(cornerRadius: 10)
            .fill(Color(NSColor.controlBackgroundColor))
          )
        }

        Button {
         selectedAppConfigs.removeAll(where: { $0.id == appConfig.id })
        } label: {
         Image(systemName: "xmark.circle.fill")
          .font(.system(size: 14))
          .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
        .offset(x: 6, y: -6)
       }
      }
     }
     .padding(.vertical, 2)
    }
   }
   .padding(.vertical, 2)

   VStack(alignment: .leading, spacing: 10) {
    Text("Websites")

    HStack {
     TextField("Enter website URL (e.g., google.com)", text: $newWebsiteURL)
      .textFieldStyle(.roundedBorder)
      .onSubmit { addWebsite() }

     AddIconButton(helpText: "Add website", isDisabled: newWebsiteURL.isEmpty) {
      addWebsite()
     }
    }

    if websiteConfigs.isEmpty {
     Text("No websites added")
      .foregroundColor(.secondary)
      .font(.subheadline)
    } else {
     LazyVGrid(columns: [GridItem(.adaptive(minimum: 140, maximum: 220), spacing: 10)], spacing: 10) {
      ForEach(websiteConfigs) { urlConfig in
       HStack(spacing: 6) {
        Image(systemName: "globe")
         .foregroundColor(.secondary)
        Text(urlConfig.url)
         .lineLimit(1)
        Spacer(minLength: 0)
        Button {
         websiteConfigs.removeAll(where: { $0.id == urlConfig.id })
        } label: {
         Image(systemName: "xmark.circle.fill")
          .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
       }
       .padding(.horizontal, 8)
       .padding(.vertical, 6)
       .background(
        RoundedRectangle(cornerRadius: 8)
         .fill(Color(NSColor.controlBackgroundColor))
       )
      }
     }
     .padding(.vertical, 2)
    }
   }
   .padding(.vertical, 2)
  }
 }
}

// MARK: - Transcription Section

struct PowerModeTranscriptionSection: View {
 @Binding var selectedTranscriptionModelName: String?
 @Binding var selectedLanguage: String?
 let effectiveModelName: String?
 let languageSelectionDisabled: Bool
 @EnvironmentObject private var whisperState: WhisperState

 var body: some View {
  Section("Transcription") {
   if whisperState.usableModels.isEmpty {
    Text("No transcription models available. Please connect to a cloud service or download a local model in the AI Models tab.")
     .foregroundColor(.secondary)
   } else {
    let modelBinding = Binding<String?>(
     get: { selectedTranscriptionModelName ?? whisperState.currentTranscriptionModel?.name },
     set: { selectedTranscriptionModelName = $0 }
    )

    Picker("Model", selection: modelBinding) {
     ForEach(whisperState.usableModels, id: \.name) { model in
      Text(model.displayName).tag(model.name as String?)
     }
    }
    .onChange(of: selectedTranscriptionModelName) { _, newModelName in
     if let modelName = newModelName ?? whisperState.currentTranscriptionModel?.name,
        let model = whisperState.allAvailableModels.first(where: { $0.name == modelName }),
        model.provider == .parakeet || model.provider == .gemini {
      selectedLanguage = "auto"
     }
    }
   }

   if languageSelectionDisabled {
    LabeledContent("Language") {
     Text("Autodetected")
      .foregroundColor(.secondary)
    }
    .onAppear {
     selectedLanguage = "auto"
    }
   } else if let selectedModel = effectiveModelName,
             let modelInfo = whisperState.allAvailableModels.first(where: { $0.name == selectedModel }),
             modelInfo.isMultilingualModel {
    let languageBinding = Binding<String?>(
     get: { selectedLanguage ?? UserDefaults.standard.string(forKey: UserDefaults.Keys.selectedLanguage) ?? "auto" },
     set: { selectedLanguage = $0 }
    )

    Picker("Language", selection: languageBinding) {
     ForEach(modelInfo.supportedLanguages.sorted(by: {
      if $0.key == "auto" { return true }
      if $1.key == "auto" { return false }
      return $0.value < $1.value
     }), id: \.key) { key, value in
      Text(value).tag(key as String?)
     }
    }
   } else if let selectedModel = effectiveModelName,
             let modelInfo = whisperState.allAvailableModels.first(where: { $0.name == selectedModel }),
             !modelInfo.isMultilingualModel {
    EmptyView()
     .onAppear {
      if selectedLanguage == nil {
       selectedLanguage = "en"
      }
     }
   }
  }
 }
}

// MARK: - AI Enhancement Section

struct PowerModeAIEnhancementSection: View {
 @Binding var isAIEnhancementEnabled: Bool
 @Binding var selectedAIProvider: String?
 @Binding var selectedAIModel: String?
 @Binding var selectedPromptId: UUID?
 @Binding var useScreenCapture: Bool
 @Binding var useClipboardContext: Bool
 @Binding var systemInstructions: String?
 @EnvironmentObject var enhancementService: AIEnhancementService
 @EnvironmentObject var aiService: AIService
 @State private var isSystemInstructionsExpanded = false
 @State private var instructionsText = ""

 var body: some View {
  Section("AI Enhancement") {
   Toggle("Enable AI Enhancement", isOn: $isAIEnhancementEnabled)
    .accessibilityIdentifier(AccessibilityID.PowerModeConfig.toggleAIEnhancement)
    .onChange(of: isAIEnhancementEnabled) { _, newValue in
     if newValue {
      if selectedAIProvider == nil {
       selectedAIProvider = aiService.selectedProvider.rawValue
      }
      if selectedAIModel == nil {
       selectedAIModel = aiService.currentModel
      }
      if selectedPromptId == nil {
       selectedPromptId = enhancementService.allPrompts.first?.id
      }
     }
    }

   let providerBinding = Binding<AIProvider>(
    get: {
     if let providerName = selectedAIProvider,
        let provider = AIProvider(rawValue: providerName) {
      return provider
     }
     return aiService.selectedProvider
    },
    set: { newValue in
     selectedAIProvider = newValue.rawValue
     aiService.selectedProvider = newValue
     selectedAIModel = nil
    }
   )

   if isAIEnhancementEnabled {
    if aiService.connectedProviders.isEmpty {
     LabeledContent("AI Provider") {
      Text("No providers connected")
       .foregroundColor(.secondary)
       .italic()
     }
    } else {
     Picker("AI Provider", selection: providerBinding) {
      ForEach(aiService.connectedProviders.filter { $0 != .elevenLabs && $0 != .deepgram }, id: \.self) { provider in
       Text(provider.rawValue).tag(provider)
      }
     }
     .onChange(of: selectedAIProvider) { _, newValue in
      if let provider = newValue.flatMap({ AIProvider(rawValue: $0) }) {
       selectedAIModel = provider.defaultModel
      }
     }
    }

    let providerName = selectedAIProvider ?? aiService.selectedProvider.rawValue
    if let provider = AIProvider(rawValue: providerName),
       provider != .custom {
     if aiService.availableModels.isEmpty {
      LabeledContent("AI Model") {
       Text(provider == .openRouter ? "No models loaded" : "No models available")
        .foregroundColor(.secondary)
        .italic()
      }
     } else {
      let modelBinding = Binding<String>(
       get: {
        if let model = selectedAIModel, !model.isEmpty { return model }
        return aiService.currentModel
       },
       set: { newModelValue in
        selectedAIModel = newModelValue
        aiService.selectModel(newModelValue)
       }
      )

      let models = provider == .openRouter ? aiService.availableModels : (provider == .ollama ? aiService.availableModels : provider.availableModels)

      Picker("AI Model", selection: modelBinding) {
       ForEach(models, id: \.self) { model in
        Text(model).tag(model)
       }
      }

      if provider == .openRouter {
       Button("Refresh Models") {
        Task { await aiService.fetchOpenRouterModels() }
       }
       .help("Refresh models")
      }
     }
    }

    if enhancementService.allPrompts.isEmpty {
     LabeledContent("Enhancement Prompt") {
      Text("No prompts available")
       .foregroundColor(.secondary)
     }
    } else {
     Picker("Enhancement Prompt", selection: $selectedPromptId) {
      ForEach(enhancementService.allPrompts) { prompt in
       Text(prompt.title).tag(prompt.id as UUID?)
      }
     }
    }

    Toggle("Screen Context", isOn: $useScreenCapture)
     .accessibilityIdentifier(AccessibilityID.PowerModeConfig.toggleContextAwareness)

    Toggle("Clipboard Context", isOn: $useClipboardContext)

    DisclosureGroup("System Instructions", isExpanded: $isSystemInstructionsExpanded) {
     VStack(alignment: .leading, spacing: 8) {
      Toggle("Override global system instructions", isOn: Binding(
       get: { systemInstructions != nil },
       set: { enabled in
        if enabled {
         instructionsText = AIPrompts.customPromptTemplate
         systemInstructions = instructionsText
        } else {
         systemInstructions = nil
         instructionsText = ""
        }
       }
      ))

      if systemInstructions != nil {
       Text("Custom system instructions for this Power Mode. The `%@` placeholder is where the selected prompt's rules get inserted.")
        .font(.caption)
        .foregroundColor(.secondary)

       TextEditor(text: $instructionsText)
        .font(.system(.body, design: .monospaced))
        .frame(minHeight: 200)
        .padding(4)
        .background(Color(NSColor.textBackgroundColor))
        .cornerRadius(8)
        .overlay(
         RoundedRectangle(cornerRadius: 8)
          .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
        )
        .onChange(of: instructionsText) { _, newValue in
         systemInstructions = newValue
        }

       Button("Reset to Global Default") {
        instructionsText = AIPrompts.customPromptTemplate
        systemInstructions = instructionsText
       }
       .font(.caption)
      }
     }
    }
    .onAppear {
     if let instructions = systemInstructions {
      instructionsText = instructions
      isSystemInstructionsExpanded = true
     }
    }
   }
  }
 }
}

// MARK: - Advanced Section

struct PowerModeAdvancedSection: View {
 @Binding var isDefault: Bool
 @Binding var isAutoSendEnabled: Bool
 let powerModeConfigId: UUID

 var body: some View {
  Section("Advanced") {
   Toggle(isOn: $isDefault) {
    HStack(spacing: 6) {
     Text("Set as default")
     InfoTip("Default power mode is used when no specific app or website matches are found.")
    }
   }
   .accessibilityIdentifier(AccessibilityID.PowerModeConfig.toggleDefault)

   Toggle(isOn: $isAutoSendEnabled) {
    HStack(spacing: 6) {
     Text("Auto Send")
     InfoTip("Automatically presses the Return/Enter key after pasting text. Useful for chat applications or forms.")
    }
   }
   .accessibilityIdentifier(AccessibilityID.PowerModeConfig.toggleAutoSend)

   HStack {
    Text("Keyboard Shortcut")
    InfoTip("Assign a unique keyboard shortcut to instantly activate this Power Mode and start recording.")

    Spacer()

    KeyboardShortcuts.Recorder(for: .powerMode(id: powerModeConfigId))
     .controlSize(.regular)
     .frame(minHeight: 28)
   }
  }
 }
}
