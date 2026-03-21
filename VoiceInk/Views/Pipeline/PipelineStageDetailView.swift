import SwiftUI
import KeyboardShortcuts

struct PipelineStageDetailView: View {
 let stage: PipelineStage
 @Binding var selectedView: ViewType?

 var body: some View {
  ScrollView {
   VStack(alignment: .leading, spacing: 12) {
    stageContent
   }
   .padding(16)
  }
 }

 @ViewBuilder
 private var stageContent: some View {
  switch stage {
  case .recording:
   RecordingStageContent()
  case .speechToText:
   SpeechToTextStageContent(selectedView: $selectedView)
  case .outputFilters:
   OutputFiltersStageContent()
  case .textFormatting:
   TextFormattingStageContent()
  case .wordReplacement:
   WordReplacementStageContent()
  case .aiEnhancement:
   AIEnhancementStageContent()
  case .pasteOutput:
   PasteOutputStageContent()
  }
 }
}

// MARK: - Stage 1: Recording

private struct RecordingStageContent: View {
 @EnvironmentObject private var hotkeyManager: HotkeyManager
 @EnvironmentObject private var whisperState: WhisperState
 @ObservedObject private var soundManager = SoundManager.shared
 @Bindable private var mediaController = MediaController.shared
 @Bindable private var playbackController = PlaybackController.shared

 @State private var isCustomCancelEnabled = KeyboardShortcuts.getShortcut(for: .cancelRecorder) != nil
 @State private var isCustomCancelExpanded = false
 @State private var isMiddleClickExpanded = false
 @State private var isSoundFeedbackExpanded = false
 @State private var isMuteSystemExpanded = false
 @State private var isPauseMediaExpanded = false

 var body: some View {
  VStack(alignment: .leading, spacing: 20) {
   // Hotkeys
   sectionLabel("Hotkeys")
   Form {
    Section {
     LabeledContent("Hotkey 1") {
      HStack(spacing: 8) {
       hotkeyPicker(binding: $hotkeyManager.selectedHotkey1)
       if hotkeyManager.selectedHotkey1 == .custom {
        KeyboardShortcuts.Recorder(for: .toggleMiniRecorder)
         .controlSize(.small)
       }
       if hotkeyManager.selectedHotkey1.isModifierKey {
        Text("+")
         .foregroundColor(.secondary)
        companionModifierPicker(
         binding: $hotkeyManager.companionModifier1,
         excluding: hotkeyManager.selectedHotkey1
        )
       }
      }
     }

     if hotkeyManager.selectedHotkey2 != .none {
      LabeledContent("Hotkey 2") {
       HStack(spacing: 8) {
        hotkeyPicker(binding: $hotkeyManager.selectedHotkey2)
        if hotkeyManager.selectedHotkey2 == .custom {
         KeyboardShortcuts.Recorder(for: .toggleMiniRecorder2)
          .controlSize(.small)
        }
        if hotkeyManager.selectedHotkey2.isModifierKey {
         Text("+")
          .foregroundColor(.secondary)
         companionModifierPicker(
          binding: $hotkeyManager.companionModifier2,
          excluding: hotkeyManager.selectedHotkey2
         )
        }
        Button {
         withAnimation { hotkeyManager.selectedHotkey2 = .none }
        } label: {
         Image(systemName: "minus.circle.fill")
          .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
       }
      }
     }

     if hotkeyManager.selectedHotkey1 != .none && hotkeyManager.selectedHotkey2 == .none {
      Button("Add Second Hotkey") {
       withAnimation { hotkeyManager.selectedHotkey2 = .rightOption }
      }
     }

     Picker("Recording Mode", selection: $hotkeyManager.recordingMode) {
      ForEach(HotkeyManager.RecordingMode.allCases, id: \.self) { mode in
       Text(mode.displayName).tag(mode)
      }
     }
    }
   }
   .formStyle(.grouped)
   .scrollContentBackground(.hidden)
   .fixedSize(horizontal: false, vertical: true)

   // Additional Shortcuts
   sectionLabel("Additional Shortcuts")
   Form {
    Section {
     LabeledContent("Paste Last (Original)") {
      KeyboardShortcuts.Recorder(for: .pasteLastTranscription)
       .controlSize(.small)
     }
     LabeledContent("Paste Last (Enhanced)") {
      KeyboardShortcuts.Recorder(for: .pasteLastEnhancement)
       .controlSize(.small)
     }
     LabeledContent("Retry Last Transcription") {
      KeyboardShortcuts.Recorder(for: .retryLastTranscription)
       .controlSize(.small)
     }
     LabeledContent("Type Last Transcription") {
      KeyboardShortcuts.Recorder(for: .typeLastTranscription)
       .controlSize(.small)
     }

     ExpandableSettingsRow(
      isExpanded: $isCustomCancelExpanded,
      isEnabled: $isCustomCancelEnabled,
      label: "Custom Cancel Shortcut"
     ) {
      LabeledContent("Shortcut") {
       KeyboardShortcuts.Recorder(for: .cancelRecorder)
        .controlSize(.small)
      }
     }
     .onChange(of: isCustomCancelEnabled) { _, newValue in
      if !newValue {
       KeyboardShortcuts.setShortcut(nil, for: .cancelRecorder)
       isCustomCancelExpanded = false
      }
     }

     ExpandableSettingsRow(
      isExpanded: $isMiddleClickExpanded,
      isEnabled: $hotkeyManager.isMiddleClickToggleEnabled,
      label: "Middle-Click Recording"
     ) {
      LabeledContent("Activation Delay") {
       HStack {
        TextField("", value: $hotkeyManager.middleClickActivationDelay, formatter: {
         let formatter = NumberFormatter()
         formatter.minimum = 0
         return formatter
        }())
        .textFieldStyle(.roundedBorder)
        .frame(width: 60)
        Text("ms")
         .foregroundColor(.secondary)
       }
      }
     }
    }
   }
   .formStyle(.grouped)
   .scrollContentBackground(.hidden)
   .fixedSize(horizontal: false, vertical: true)

   // Recording Feedback
   sectionLabel("Recording Feedback")
   Form {
    Section {
     ExpandableSettingsRow(
      isExpanded: $isSoundFeedbackExpanded,
      isEnabled: $soundManager.isEnabled,
      label: "Sound Feedback"
     ) {
      CustomSoundSettingsView()
     }

     ExpandableSettingsRow(
      isExpanded: $isMuteSystemExpanded,
      isEnabled: $mediaController.isSystemMuteEnabled,
      label: "Mute Audio While Recording"
     ) {
      Picker("Resume Delay", selection: $mediaController.audioResumptionDelay) {
       Text("0s").tag(0.0)
       Text("1s").tag(1.0)
       Text("2s").tag(2.0)
       Text("3s").tag(3.0)
       Text("4s").tag(4.0)
       Text("5s").tag(5.0)
      }
     }

     ExpandableSettingsRow(
      isExpanded: $isPauseMediaExpanded,
      isEnabled: $playbackController.isPauseMediaEnabled,
      label: "Pause Media While Recording",
      infoMessage: "Pauses playing media when recording starts and resumes when done."
     ) {
      Picker("Resume Delay", selection: $playbackController.mediaResumptionDelay) {
       Text("0s").tag(0.0)
       Text("1s").tag(1.0)
       Text("2s").tag(2.0)
       Text("3s").tag(3.0)
       Text("4s").tag(4.0)
       Text("5s").tag(5.0)
      }
     }
    }
   }
   .formStyle(.grouped)
   .scrollContentBackground(.hidden)
   .fixedSize(horizontal: false, vertical: true)

   // Interface
   sectionLabel("Recorder Interface")
   Form {
    Section {
     Picker("Recorder Style", selection: $whisperState.recorderType) {
      Text("Notch").tag(RecorderStyle.notch.rawValue)
      Text("Mini").tag(RecorderStyle.mini.rawValue)
     }
     .pickerStyle(.segmented)

     Picker("Display", selection: $whisperState.recorderScreenSelection) {
      Text("Active Window").tag("activeWindow")
      Text("Mouse Cursor").tag("mouseCursor")
      Text("Primary Display").tag("primaryDisplay")
     }
    }
   }
   .formStyle(.grouped)
   .scrollContentBackground(.hidden)
   .fixedSize(horizontal: false, vertical: true)

   // Audio Input
   sectionLabel("Audio Input")
   AudioInputSettingsView()
  }
 }

 @ViewBuilder
 private func hotkeyPicker(binding: Binding<HotkeyManager.HotkeyOption>) -> some View {
  Picker("", selection: binding) {
   ForEach(HotkeyManager.HotkeyOption.allCases, id: \.self) { option in
    Text(option.displayName).tag(option)
   }
  }
  .labelsHidden()
  .frame(width: 140)
 }

 @ViewBuilder
 private func companionModifierPicker(
  binding: Binding<HotkeyManager.CompanionModifier>,
  excluding hotkey: HotkeyManager.HotkeyOption
 ) -> some View {
  let excludedFlag = hotkey.modifierFlag
  Picker("", selection: binding) {
   ForEach(HotkeyManager.CompanionModifier.allCases, id: \.self) { mod in
    if mod == .none || mod.flag != excludedFlag {
     Text(mod.displayName).tag(mod)
    }
   }
  }
  .labelsHidden()
  .frame(width: 120)
 }
}

// MARK: - Stage 2: Speech-to-Text

private struct SpeechToTextStageContent: View {
 @Binding var selectedView: ViewType?
 @EnvironmentObject private var whisperState: WhisperState

 var body: some View {
  VStack(alignment: .leading, spacing: 0) {
   ModelManagementView(whisperState: whisperState)
  }
 }
}

// MARK: - Stage 3: Output Filters

private struct OutputFiltersStageContent: View {
 var body: some View {
  VStack(alignment: .leading, spacing: 16) {
   OutputFilterSettingsView()
   Divider()
   FillerWordsSettingsView()
  }
 }
}

// MARK: - Stage 4: Text Formatting

private struct TextFormattingStageContent: View {
 @EnvironmentObject private var enhancementService: AIEnhancementService
 @AppStorage(UserDefaults.Keys.isTextFormattingEnabled) private var textFormattingEnabled = true
 @AppStorage(UserDefaults.Keys.appendTrailingSpace) private var trailingSpace = false
 @AppStorage(UserDefaults.Keys.autoGeneratePhoneticHints) private var autoGeneratePhoneticHints = false

 var body: some View {
  VStack(alignment: .leading, spacing: 16) {
   HStack {
    Toggle(isOn: $textFormattingEnabled) {
     Text("Auto-capitalize and format text")
    }
    .toggleStyle(.switch)
    InfoTip("Apply intelligent text formatting to break large block of text into paragraphs.")
   }

   HStack {
    Toggle(isOn: $trailingSpace) {
     Text("Add trailing space after transcription")
    }
    .toggleStyle(.switch)
    InfoTip("Adds a space at the end so you can continue typing seamlessly.")
   }

   Divider()

   sectionLabel("Post Processing")

   Text("Post processing happens in the background after paste. Enhanced results appear in History.")
    .font(.system(size: 13))
    .foregroundColor(.secondary)

   Toggle(isOn: $enhancementService.backgroundEnhancementEnabled) {
    HStack(spacing: 4) {
     Text("Background Enhancement")
     InfoTip("Pastes raw text immediately and enhances in the background. Enhanced results appear in History.")
    }
   }
   .toggleStyle(.switch)

   Toggle(isOn: $enhancementService.vocabularyExtractionEnabled) {
    HStack(spacing: 4) {
     Text("Vocabulary Extraction")
     InfoTip("Analyzes AI corrections to detect new vocabulary and suggests additions to your dictionary.")
    }
   }
   .toggleStyle(.switch)
   .opacity(enhancementService.backgroundEnhancementEnabled ? 1.0 : 0.5)
   .disabled(!enhancementService.backgroundEnhancementEnabled)

   Toggle(isOn: $autoGeneratePhoneticHints) {
    HStack(spacing: 4) {
     Text("Auto-generate Phonetic Hints")
     InfoTip("Automatically discovers how Whisper mishears your vocabulary words and adds phonetic hints to improve future recognition.")
    }
   }
   .toggleStyle(.switch)
   .opacity(enhancementService.backgroundEnhancementEnabled ? 1.0 : 0.5)
   .disabled(!enhancementService.backgroundEnhancementEnabled)
  }
 }
}

// MARK: - Stage 5: Word Replacement

private struct WordReplacementStageContent: View {
 @EnvironmentObject private var whisperState: WhisperState

 var body: some View {
  VStack(alignment: .leading, spacing: 0) {
   DictionarySettingsView(whisperPrompt: whisperState.whisperPrompt)
  }
 }
}

// MARK: - Stage 6: AI Enhancement

private struct AIEnhancementStageContent: View {
 var body: some View {
  VStack(alignment: .leading, spacing: 0) {
   EnhancementSettingsView()
  }
 }
}

// MARK: - Stage 7: Paste / Output

private struct PasteOutputStageContent: View {
 @AppStorage(UserDefaults.Keys.pasteMethod) private var pasteMethod = "default"
 @AppStorage(UserDefaults.Keys.restoreClipboardAfterPaste) private var restoreClipboard = true
 @AppStorage(UserDefaults.Keys.clipboardRestoreDelay) private var clipboardRestoreDelay = 0.25
 @AppStorage(UserDefaults.Keys.typeOutDelay) private var typeOutDelay = 3.0
 @AppStorage(UserDefaults.Keys.warnNoTextField) private var warnNoTextField = true

 var body: some View {
  VStack(alignment: .leading, spacing: 16) {
   Form {
    Section {
     Picker(selection: $pasteMethod) {
      Text("Paste").tag("default")
      Text("AppleScript").tag("appleScript")
      Text("Type Out").tag("typeOut")
     } label: {
      HStack(spacing: 4) {
       Text("Paste Method")
       InfoTip("Paste uses simulated Cmd+V. AppleScript works with custom keyboard layouts (e.g. Neo2). Type Out types text character-by-character, bypassing paste restrictions in some apps.")
      }
     }

     if pasteMethod == "typeOut" {
      Picker("Type Out Delay", selection: $typeOutDelay) {
       Text("1s").tag(1.0)
       Text("2s").tag(2.0)
       Text("3s").tag(3.0)
       Text("5s").tag(5.0)
       Text("8s").tag(8.0)
      }
     }

     Toggle(isOn: $warnNoTextField) {
      HStack(spacing: 4) {
       Text("Warn When No Text Field Detected")
       InfoTip("Shows a warning when no editable text field is focused. Transcription will be copied to clipboard instead of pasted.")
      }
     }
    }

    Section {
     Toggle(isOn: $restoreClipboard) {
      HStack(spacing: 4) {
       Text("Restore Clipboard After Paste")
       InfoTip("Saves your clipboard before pasting and restores it afterward.")
      }
     }

     if restoreClipboard {
      Picker("Restore Delay", selection: $clipboardRestoreDelay) {
       Text("250ms").tag(0.25)
       Text("500ms").tag(0.5)
       Text("1s").tag(1.0)
       Text("2s").tag(2.0)
       Text("3s").tag(3.0)
       Text("4s").tag(4.0)
       Text("5s").tag(5.0)
      }
     }
    }
   }
   .formStyle(.grouped)
   .scrollContentBackground(.hidden)
   .fixedSize(horizontal: false, vertical: true)
  }
 }
}

// MARK: - Helpers

private func sectionLabel(_ text: String) -> some View {
 Text(text)
  .font(.system(size: 14, weight: .semibold))
  .foregroundColor(.primary)
}
