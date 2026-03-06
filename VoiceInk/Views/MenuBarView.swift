import SwiftUI
import LaunchAtLogin

struct MenuBarView: View {
    @EnvironmentObject var whisperState: WhisperState
    @EnvironmentObject var hotkeyManager: HotkeyManager
    @EnvironmentObject var menuBarManager: MenuBarManager
    @EnvironmentObject var updaterViewModel: UpdaterViewModel
    @EnvironmentObject var enhancementService: AIEnhancementService
    @EnvironmentObject var aiService: AIService
    @ObservedObject var audioDeviceManager = AudioDeviceManager.shared
    @State private var launchAtLoginEnabled = LaunchAtLogin.isEnabled
    @State private var menuRefreshTrigger = false
    @State private var isHovered = false
    
    var body: some View {
        VStack {
            Button("Toggle Recorder") {
                whisperState.handleToggleMiniRecorder()
            }
            .accessibilityIdentifier(AccessibilityID.MenuBar.buttonToggleRecorder)

            Divider()

            Menu {
                ForEach(whisperState.usableModels, id: \.id) { model in
                    Button {
                        Task {
                            await whisperState.setDefaultTranscriptionModel(model)
                        }
                    } label: {
                        HStack {
                            Text(model.displayName)
                            if whisperState.currentTranscriptionModel?.id == model.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
                
                Divider()
                
                Button("Manage Models") {
                    menuBarManager.openMainWindowAndNavigate(to: "AI Models")
                }
                .accessibilityIdentifier(AccessibilityID.MenuBar.buttonManageModels)
            } label: {
                HStack {
                    Text("Transcription Model: \(whisperState.currentTranscriptionModel?.displayName ?? "None")")
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10))
                }
            }
            .accessibilityIdentifier(AccessibilityID.MenuBar.menuTranscriptionModel)

            Divider()
            
            Toggle("AI Enhancement", isOn: $enhancementService.isEnhancementEnabled)
            .accessibilityIdentifier(AccessibilityID.MenuBar.toggleAIEnhancement)
            
            Menu {
                ForEach(enhancementService.allPrompts) { prompt in
                    Button {
                        enhancementService.setActivePrompt(prompt)
                    } label: {
                        HStack {
                            Image(systemName: prompt.icon)
                                .foregroundColor(.accentColor)
                            Text(prompt.title)
                            if enhancementService.selectedPromptId == prompt.id {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text("Prompt: \(enhancementService.activePrompt?.title ?? "None")")
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10))
                }
            }
            .accessibilityIdentifier(AccessibilityID.MenuBar.menuPrompt)

            Menu {
                ForEach(aiService.connectedProviders, id: \.self) { provider in
                    Button {
                        aiService.selectedProvider = provider
                    } label: {
                        HStack {
                            Text(provider.rawValue)
                            if aiService.selectedProvider == provider {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }

                if aiService.connectedProviders.isEmpty {
                    Text("No providers connected")
                        .foregroundColor(.secondary)
                }
            } label: {
                HStack {
                    Text("AI Provider: \(aiService.selectedProvider.rawValue)")
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10))
                }
            }
            .accessibilityIdentifier(AccessibilityID.MenuBar.menuAIProvider)

            Menu {
                ForEach(aiService.availableModels, id: \.self) { model in
                    Button {
                        aiService.selectModel(model)
                    } label: {
                        HStack {
                            Text(model)
                            if aiService.currentModel == model {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }

                if aiService.availableModels.isEmpty {
                    Text("No models available")
                        .foregroundColor(.secondary)
                }
            } label: {
                HStack {
                    Text("AI Model: \(aiService.currentModel)")
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10))
                }
            }
            .accessibilityIdentifier(AccessibilityID.MenuBar.menuAIModel)

            LanguageSelectionView(whisperState: whisperState, displayMode: .menuItem, whisperPrompt: whisperState.whisperPrompt)

            Menu {
                ForEach(audioDeviceManager.availableDevices, id: \.id) { device in
                    Button {
                        audioDeviceManager.selectDeviceAndSwitchToCustomMode(id: device.id)
                    } label: {
                        HStack {
                            Text(device.name)
                            if audioDeviceManager.getCurrentDevice() == device.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }

                if audioDeviceManager.availableDevices.isEmpty {
                    Text("No devices available")
                        .foregroundColor(.secondary)
                }
            } label: {
                HStack {
                    Text("Audio Input")
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10))
                }
            }
            .accessibilityIdentifier(AccessibilityID.MenuBar.menuAudioInput)

            Menu("Additional") {
                Button {
                    enhancementService.useClipboardContext.toggle()
                    menuRefreshTrigger.toggle()
                } label: {
                    HStack {
                        Text("Clipboard Context")
                        Spacer()
                        if enhancementService.useClipboardContext {
                            Image(systemName: "checkmark")
                        }
                    }
                }

                Button {
                    enhancementService.useScreenCaptureContext.toggle()
                    menuRefreshTrigger.toggle()
                } label: {
                    HStack {
                        Text("Context Awareness")
                        Spacer()
                        if enhancementService.useScreenCaptureContext {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
            .accessibilityIdentifier(AccessibilityID.MenuBar.menuAdditional)
            .id("additional-menu-\(menuRefreshTrigger)")
            
            Divider()

            Button("Retry Last Transcription") {
                LastTranscriptionService.retryLastTranscription(from: whisperState.modelContext, whisperState: whisperState)
            }
            .accessibilityIdentifier(AccessibilityID.MenuBar.buttonRetryLastTranscription)
            
            Button("Copy Last Transcription") {
                LastTranscriptionService.copyLastTranscription(from: whisperState.modelContext)
            }
            .accessibilityIdentifier(AccessibilityID.MenuBar.buttonCopyLastTranscription)
            .keyboardShortcut("c", modifiers: [.command, .shift])

            Button("Type Last Transcription") {
                LastTranscriptionService.typeLastTranscription(from: whisperState.modelContext)
            }
            .accessibilityIdentifier(AccessibilityID.MenuBar.buttonTypeLastTranscription)
            
            Button("History") {
                menuBarManager.openHistoryWindow()
            }
            .accessibilityIdentifier(AccessibilityID.MenuBar.buttonHistory)
            .keyboardShortcut("h", modifiers: [.command, .shift])
            
            Button("Settings") {
                menuBarManager.focusMainWindow()
            }
            .accessibilityIdentifier(AccessibilityID.MenuBar.buttonSettings)
            .keyboardShortcut(",", modifiers: .command)
            
            Button(menuBarManager.isMenuBarOnly ? "Show Dock Icon" : "Hide Dock Icon") {
                menuBarManager.toggleMenuBarOnly()
            }
            .accessibilityIdentifier(AccessibilityID.MenuBar.buttonToggleDockIcon)
            .keyboardShortcut("d", modifiers: [.command, .shift])
            
            Toggle("Launch at Login", isOn: $launchAtLoginEnabled)
                .accessibilityIdentifier(AccessibilityID.MenuBar.toggleLaunchAtLogin)
                .onChange(of: launchAtLoginEnabled) { oldValue, newValue in
                    LaunchAtLogin.isEnabled = newValue
                }
            
            Divider()
            
            Button("Check for Updates") {
                updaterViewModel.checkForUpdates()
            }
            .accessibilityIdentifier(AccessibilityID.MenuBar.buttonCheckForUpdates)
            .disabled(!updaterViewModel.canCheckForUpdates)
            
            Button("Help and Support") {
                EmailSupport.openSupportEmail()
            }
            .accessibilityIdentifier(AccessibilityID.MenuBar.buttonHelpAndSupport)
            
            Divider()

            Button("Quit VoiceInk") {
                NSApplication.shared.terminate(nil)
            }
            .accessibilityIdentifier(AccessibilityID.MenuBar.buttonQuit)
        }
    }
}