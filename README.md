> **Looking for the official VoiceInk?** **[Beingpax/VoiceInk](https://github.com/Beingpax/VoiceInk)** | [tryvoiceink.com](https://tryvoiceink.com)
>
> This is a personal fork. I use VoiceInk daily and have been making improvements based on my own preferences and workflow needs. This fork is public so the work is visible and available to the community. It is not intended to compete with or fragment the original project.
>
> The original author is welcome to pull any of these changes into the main repo at any time. I'm also happy to open PRs for individual features if that's preferred.

---

## Fork Changes

All changes in this fork relative to the upstream repository, organized by area. See the [original PR #562](https://github.com/Beingpax/VoiceInk/pull/562) for the initial batch of work.

### Performance

- **Parallel context capture** -- clipboard and screen OCR run concurrently via `async let`, saving 200-500ms per transcription
- **3-second OCR timeout** -- prevents screen capture from stalling the entire pipeline on complex windows
- **Model pre-loading on selection** -- transcription model loads in the background immediately when selected, eliminating 2-5s first-recording latency
- **30-second model cleanup grace period** -- back-to-back transcriptions reuse the loaded model instead of repeatedly loading/unloading
- **Cached word replacement regex** -- compiled patterns are cached instead of recompiled per replacement per transcription
- **Pre-compiled AppleScript** -- paste script compiled once at class init, not on every paste
- **Cached DateFormatter/ISO8601DateFormatter** -- formatter instances reused instead of recreated
- **SwiftData query optimization** -- database-level filtering with `#Predicate` and `propertiesToFetch` to reduce memory footprint

### Background Enhancement Queue

- **Zero-wait paste** -- raw transcription pastes immediately, AI enhancement processes asynchronously in the background
- **Thread-safe queue** -- `OSAllocatedUnfairLock` for lock-free job management on a detached task
- **System message snapshot** -- captures AI prompt at enqueue time before screen context clears

### LLM Enhancement Model Prewarming

- **Prewarm on recording start** -- sends a minimal `max_tokens: 1` request to force local LLM model loading (Ollama, custom localhost providers) while recording is in progress
- **Prewarm on app launch and wake** -- via the existing `ModelPrewarmService` infrastructure
- **Configurable inactivity threshold** -- only prewarms if no enhancement has run within a user-configurable window (1-30 minutes, default 5)
- **Activity tracking** -- records each successful enhancement to avoid redundant prewarm requests during active use
- **Provider detection** -- automatically identifies local providers (Ollama, custom with localhost/127.0.0.1 URLs) and skips cloud providers

### Hotkey System Rewrite

- **Three recording modes** -- hybrid (brief press = toggle, long press = push-to-talk), push-to-talk, and toggle
- **Dual hotkey slots** -- two independent hotkey configurations for different workflows
- **Companion modifier support** -- any hotkey can combine with a second modifier (Shift, Control, Option, Command, Fn)
- **Seven modifier key options** -- Right/Left Option, Right/Left Control, Fn, Right Command, Right Shift, plus custom via KeyboardShortcuts
- **Middle-click recording toggle** -- mouse button 2 support with configurable activation delay
- **Fn key debounce (40ms)** -- filters spurious macOS Fn flag events
- **State machine isolation** -- each hotkey slot tracks its own key state independently

### Paste Strategy

- **Editable text field detection** -- uses Accessibility APIs to check `AXRole` before pasting; warns when no text field is focused
- **Type-out mode** -- character-by-character typing via `CGEvent` for fields that block clipboard paste (password fields, some web forms)
- **Input source management** -- temporarily switches to QWERTY for Cmd+V on non-QWERTY layouts, then restores

### Intelligent Vocabulary System

- **Vocabulary extraction pipeline** -- `VocabularyDiffEngine` uses LCS alignment to compare raw transcription against AI-enhanced text and identify correction patterns
- **Automatic suggestions** -- `VocabularySuggestionService` tracks correction frequency and surfaces suggestions when patterns recur
- **Phonetic hints** -- `phoneticHints` field on vocabulary words (e.g., "VoiceInk (often heard as: voicing, voice ink)") improves both local and cloud model corrections
- **Auto-generated hints** -- `PhoneticHintMiningService` mines transcription history with multi-layered plausibility filtering (morphological variants, abbreviations, bigram Dice similarity)
- **Transcription vs enhancement vocab split** -- bare word list for biasing speech recognition, full annotations with hints for AI enhancement
- **Common word filtering** -- frequency lists for 5 languages (en, de, es, fr, pt) to filter common words from suggestions

### Local AI Provider (MLX-LM)

- **MLX-LM integration** -- local inference on Apple Silicon via `LocalMLXService` and `LocalMLXClient`
- **Auto-start server** -- VoiceInk launches the mlx-lm server process when MLX-LM is selected, including model loading and health polling
- **OpenAI-compatible API** -- HTTP client at localhost:8090, no API key needed

### Automation Interfaces

- **AppleScript** -- full scripting dictionary (`VoiceInk.sdef`) with read-only properties (recording state, current model, language, enhancement mode, etc.) and commands for recording, enhancement, settings, vocabulary, word replacements, queries, and navigation
- **Siri Shortcuts / App Intents** -- AppIntent structs for vocabulary, word replacements, settings, and query commands; registered in `AppShortcuts.swift` with Siri phrases
- **URL scheme** -- `voiceink://` routes for vocabulary, replacements, recording, enhancement, settings, navigation, and status
- **AppleScript window navigation** -- `show window "ViewName"` and `show history` commands

### History and Export

- **Pinned transcriptions** -- pin important entries to the top of history
- **Multi-select** -- select multiple entries for bulk operations
- **Always-visible toolbar** -- history toolbar stays accessible during scrolling
- **Single-entry export** -- export individual transcriptions
- **Export-as-files** -- YAML metadata, markdown, and audio file export option

### Architecture and Code Quality

- **WhisperState decomposition** -- extracted `TranscriptionOrchestrator`, `RecorderUICoordinator`, `ModelResourceManager`, `LocalModelManager`, `ParakeetModelManager` from the 1,480+ line god object
- **Protocol-based dependency injection** -- `WhisperContextProvider`, `PowerModeProviding`, `NotificationPresenting`, `FillerWordProviding`, and 5 service protocols via `AppServiceLocator`
- **Centralized UserDefaults keys** -- all keys in `UserDefaultsManager.swift` across ~30 files
- **Centralized error handling** -- `safeSave`/`safeFetch`/`trySave` pattern with consistent logging
- **Resolved all critical/high findings** -- from automated ideation audit (10 critical, 38 high)
- **20 medium-priority findings addressed** -- across 4 fix batches
- **Accessibility identifiers** -- centralized in `AccessibilityID.swift` for XCUITest automation

### Testing

- **100+ unit tests** added across:
  - `LLMPrewarmServiceTests` (18) -- provider detection, URL construction, inactivity threshold, guard behavior
  - `CustomVocabularyServiceTests` (21) -- add/remove/list with duplicate detection, case-insensitive matching, phonetic hints
  - `VoiceInkURLHandlerTests` (28+) -- URL scheme parsing for all route types with encoding validation
  - `ScriptCommandSettingsTests` (18) -- input validation for recording modes, recorder styles, paste methods, enhancement modes
  - `PowerModeManagerTests`, `PowerModeConfigCodableTests`, `PowerModeValidatorTests`, `PowerModeURLMatchingTests` -- Power Mode business logic
  - `VocabularyDiffEngineTests`, `PhoneticHintMiningServiceTests` -- vocabulary extraction and hint plausibility
  - `FillerWordRemovalTests`, `FillerWordManagerTests` -- filler word processing
  - `WhisperTextFormatterTests`, `TranscriptionOutputFilterTests` -- output formatting
  - `WordReplacementServiceTests`, `ReasoningConfigTests` -- additional business logic

---

<div align="center">
  <img src="VoiceInk/Assets.xcassets/AppIcon.appiconset/256-mac.png" width="180" height="180" />
  <h1>VoiceInk</h1>
  <p>Voice to text app for macOS to transcribe what you say to text almost instantly</p>

  [![License](https://img.shields.io/badge/License-GPL%20v3-blue.svg)](https://www.gnu.org/licenses/gpl-3.0)
  ![Platform](https://img.shields.io/badge/platform-macOS%2014.0%2B-brightgreen)
  [![GitHub release (latest by date)](https://img.shields.io/github/v/release/Beingpax/VoiceInk)](https://github.com/Beingpax/VoiceInk/releases)
  ![GitHub all releases](https://img.shields.io/github/downloads/Beingpax/VoiceInk/total)
  ![GitHub stars](https://img.shields.io/github/stars/Beingpax/VoiceInk?style=social)
  <p>
    <a href="https://tryvoiceink.com">Website</a> •
    <a href="https://www.youtube.com/@tryvoiceink">YouTube</a>
  </p>

  <a href="https://tryvoiceink.com">
    <img src="https://img.shields.io/badge/Download%20Now-Latest%20Version-blue?style=for-the-badge&logo=apple" alt="Download VoiceInk" width="250"/>
  </a>
</div>

---

VoiceInk is a native macOS application that transcribes what you say to text almost instantly. You can find all the information and download the app from [here](https://tryvoiceink.com). 

![VoiceInk Mac App](https://github.com/user-attachments/assets/12367379-83e7-48a6-b52c-4488a6a04bba)

After dedicating the past 5 months to developing this app, I've decided to open source it for the greater good. 

My goal is to make it **the most efficient and privacy-focused voice-to-text solution for macOS** that is a joy to use. While the source code is now open for experienced developers to build and contribute, purchasing a license helps support continued development and gives you access to automatic updates, priority support, and upcoming features.

## Features

- 🎙️ **Accurate Transcription**: Local AI models that transcribe your voice to text with 99% accuracy, almost instantly
- 🔒 **Privacy First**: 100% offline processing ensures your data never leaves your device
- ⚡ **Power Mode**: Intelligent app detection automatically applies your perfect pre-configured settings based on the app/ URL you're on
- 🧠 **Context Aware**: Smart AI that understands your screen content and adapts to the context
- 🎯 **Global Shortcuts**: Configurable keyboard shortcuts for quick recording and push-to-talk functionality
- 📝 **Personal Dictionary**: Train the AI to understand your unique terminology with custom words, industry terms, and smart text replacements
- 🔄 **Smart Modes**: Instantly switch between AI-powered modes optimized for different writing styles and contexts
- 🤖 **AI Assistant**: Built-in voice assistant mode for a quick chatGPT like conversational assistant

## Get Started

### Download
Get the latest version with a free trial from [tryvoiceink.com](https://tryvoiceink.com). Your purchase helps me work on VoiceInk full-time and continuously improve it with new features and updates.

#### Homebrew
Alternatively, you can install VoiceInk via `brew`:

```shell
brew install --cask voiceink
```

### Build from Source
As an open-source project, you can build VoiceInk yourself by following the instructions in [BUILDING.md](BUILDING.md). However, the compiled version includes additional benefits like automatic updates, priority support via Discord and email, and helps fund ongoing development.

## Requirements

- macOS 14.4 or later

## Documentation

- [Building from Source](BUILDING.md) - Detailed instructions for building the project
- [Contributing Guidelines](CONTRIBUTING.md) - How to contribute to VoiceInk
- [Code of Conduct](CODE_OF_CONDUCT.md) - Our community standards

## Contributing

We welcome contributions! However, please note that all contributions should align with the project's goals and vision. Before starting work on any feature or fix:

1. Read our [Contributing Guidelines](CONTRIBUTING.md)
2. Open an issue to discuss your proposed changes
3. Wait for maintainer feedback

For build instructions, see our [Building Guide](BUILDING.md).

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## Support

If you encounter any issues or have questions, please:
1. Check the existing issues in the GitHub repository
2. Create a new issue if your problem isn't already reported
3. Provide as much detail as possible about your environment and the problem

## Acknowledgments

### Core Technology
- [whisper.cpp](https://github.com/ggerganov/whisper.cpp) - High-performance inference of OpenAI's Whisper model
- [FluidAudio](https://github.com/FluidInference/FluidAudio) - Used for Parakeet model implementation

### Essential Dependencies
- [Sparkle](https://github.com/sparkle-project/Sparkle) - Keeping VoiceInk up to date
- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) - User-customizable keyboard shortcuts
- [LaunchAtLogin](https://github.com/sindresorhus/LaunchAtLogin) - Launch at login functionality
- [MediaRemoteAdapter](https://github.com/ejbills/mediaremote-adapter) - Media playback control during recording
- [Zip](https://github.com/marmelroy/Zip) - File compression and decompression utilities
- [SelectedTextKit](https://github.com/tisfeng/SelectedTextKit) - A modern macOS library for getting selected text
- [Swift Atomics](https://github.com/apple/swift-atomics) - Low-level atomic operations for thread-safe concurrent programming


---

Made with ❤️ by Pax
