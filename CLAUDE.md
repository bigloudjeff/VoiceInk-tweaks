# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
make local          # Build with local signing, output to ~/Downloads/VoiceInk.app
make all            # Full build (clone whisper.cpp, build framework, build app)
make dev            # Build and run
make clean          # Remove ~/VoiceInk-Dependencies and build artifacts
```

`make local` uses `LocalBuild.xcconfig` (Apple Development cert, team 6KL725J249) and `VoiceInk.local.entitlements`. It sets the `LOCAL_BUILD` Swift compilation flag, which gates iCloud sync, keychain access (falls back to UserDefaults), and license validation (auto-licensed).

There are no working test commands yet. VoiceInkTests uses Swift Testing (`@Test`), VoiceInkUITests uses XCTest. Both have signing/deployment-target issues when run via `xcodebuild test`.

## Deploying to /Applications

Always deploy to `/Applications/VoiceInk.app` (preserves TCC permissions):
```bash
pkill -x VoiceInk
cp -R ~/Library/Developer/Xcode/DerivedData/VoiceInk-*/Build/Products/Debug/VoiceInk.app /Applications/
open /Applications/VoiceInk.app
```

## Code Style

- **Single-space indentation** throughout the codebase (1 space per indent level)
- Swift 5, targeting macOS 14.4+
- SwiftUI for all views, SwiftData for persistence
- No SwiftLint or formatter configured

## Architecture Overview

### App Lifecycle (VoiceInk.swift)

The `@main` App struct creates all core services in `init()` and injects them as `@EnvironmentObject`:
- `WhisperState` -- recording state machine, model management, transcription orchestration
- `AIService` -- AI provider configuration (API keys, model selection, base URLs)
- `AIEnhancementService` -- enhancement pipeline (prompt selection, screen/clipboard context, LLM calls)
- `HotkeyManager` -- global keyboard shortcuts via KeyboardShortcuts framework
- `MenuBarManager` -- NSStatusItem menu bar integration

### Two SwiftData Stores

Both in `~/Library/Application Support/com.prakashjoshipax.VoiceInk/`:
- **`default.store`** -- `Transcription` model (text, enhanced text, timestamps, metadata)
- **`dictionary.store`** -- `VocabularyWord`, `VocabularySuggestion`, `WordReplacement` models. Syncs via iCloud in production builds.

### Recording Pipeline

`RecordingState` enum: `idle` -> `starting` -> `recording` -> `transcribing` -> `enhancing` -> `idle`

1. `HotkeyManager` triggers recording via `WhisperState`
2. `Recorder` captures audio via CoreAudio
3. `TranscriptionServiceRegistry` routes to the correct service based on model provider:
   - `LocalTranscriptionService` (whisper.cpp via LibWhisper)
   - `ParakeetTranscriptionService` (NVIDIA Parakeet models)
   - `CloudTranscriptionService` (OpenAI Whisper API)
   - `StreamingTranscriptionService` (Deepgram, ElevenLabs, Mistral, Soniox)
   - `NativeAppleTranscriptionService` (Apple Speech framework)
4. Optional AI enhancement via `AIEnhancementService`
5. Result pasted via `CursorPaster` (clipboard or type-out)

### AI Enhancement

`AIService` manages 13 providers (Gemini, OpenAI, Anthropic, Groq, Cerebras, Ollama, Custom, etc.). Each provider has a base URL, default model, and API key stored via `KeychainService`.

`AIEnhancementService` orchestrates:
- Prompt selection (predefined + custom `CustomPrompt` objects)
- Optional screen context capture (`ScreenCaptureService` using ScreenCaptureKit + Vision OCR)
- Optional clipboard context
- LLM request via LLMKit (SPM dependency)
- Background enhancement queue (`EnhancementQueueService`)

### Power Mode

Per-application/URL configuration overrides stored as JSON in UserDefaults. `PowerModeManager` (singleton) matches the current frontmost app or browser URL to a `PowerModeConfig`, which can override: AI prompt, transcription model, AI provider/model, screen capture toggle, and auto-send behavior.

### Recorder UI

Two recorder styles rendered in separate NSPanel windows:
- **MiniRecorderView** -- floating pill-shaped window
- **NotchRecorderView** -- extends from the MacBook notch area

Both use shared components from `RecorderComponents.swift`: `RecorderPromptButton` (enhancement prompt selector), `RecorderPowerModeButton` (power mode selector), `RecorderStatusDisplay` (visualizer/status), `RecorderRecordButton`.

### Navigation

`ContentView.swift` uses `NavigationSplitView` with a sidebar containing `ViewType` enum cases. History opens in a separate window via `HistoryWindowController`.

### Automation Interfaces

VoiceInk exposes its features via three automation interfaces, all backed by shared service methods in `CustomVocabularyService` and direct `UserDefaults` / `AppServiceLocator` access.

**AppleScript** (`VoiceInk.sdef` + `ScriptCommands.swift` + `ScriptableProperties.swift`):
- Read-only properties on the application class: `recording state`, `current model`, `current language`, `recording mode`, `recorder style`, `paste method`, `sound enabled`, `enhancement enabled/mode`, `active prompt name`, `active power mode`
- Commands for recording, enhancement, settings toggles, vocabulary, word replacements, queries, and navigation
- Usage: `osascript -e 'tell application "VoiceInk" to <command>'`

**App Intents / Siri Shortcuts** (`AppIntents/VocabularyIntents.swift`, `AppIntents/SettingsIntents.swift`):
- AppIntent structs for vocabulary, word replacements, settings, and query commands
- Registered in `AppShortcuts.swift` (max 10 Siri phrases; remaining intents available as Shortcuts actions)
- All intents are `@MainActor` and access services via `AppServiceLocator.shared`

**URL Scheme** (`VoiceInkURLHandler.swift`, registered in `Info.plist`):
- `voiceink://vocabulary/{add,remove,list}` -- vocabulary management
- `voiceink://replacement/{add,remove,list}` -- word replacement management
- `voiceink://recording/{toggle,dismiss,mode,style}` -- recording control
- `voiceink://enhancement/{toggle,mode,prompt,screen,clipboard}` -- enhancement control
- `voiceink://settings/{sound,mute,pause-media,text-formatting,filler-removal,vad,menu-bar-only,paste,language}` -- settings toggles
- `voiceink://navigate/{dashboard,history,models,...,history-window}` -- UI navigation
- `voiceink://status` -- status summary notification
- Serves as CLI via `open "voiceink://..."` from any terminal

### Accessibility Identifiers

`AccessibilityID.swift` contains centralized identifiers for XCUITest automation. Convention: `screen.elementType.specificName`. Applied via `.accessibilityIdentifier()` across all interactive views.

## Key Dependencies (SPM)

- **whisper.cpp** -- Local transcription engine (XCFramework, built via Makefile)
- **LLMKit** -- OpenAI-compatible LLM client for AI enhancement
- **KeyboardShortcuts** -- Global hotkey registration
- **Sparkle** -- Auto-update framework
- **LaunchAtLogin-Modern** -- Login item management
- **FluidAudio** -- Audio processing utilities
- **SelectedTextKit** -- Selected text detection
- **mediaremote-adapter** -- Media playback control (pause/resume during recording)
- **Zip** -- Settings import/export

## Git Remotes

- `origin` -- upstream (`Beingpax/VoiceInk.git`, read-only push access)
- `private` -- private staging repo (`bigloudjeff/VoiceInk-private.git`, push here first)
- `fork` -- public fork (`bigloudjeff/VoiceInk-tweaks.git`, push here when ready to go public)
