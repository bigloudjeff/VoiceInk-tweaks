import AppIntents
import Foundation

struct AppShortcuts: AppShortcutsProvider {
 @AppShortcutsBuilder
 static var appShortcuts: [AppShortcut] {
  AppShortcut(
   intent: ToggleMiniRecorderIntent(),
   phrases: [
    "Toggle \(.applicationName) recorder",
    "Start \(.applicationName) recording",
    "Stop \(.applicationName) recording",
    "Toggle recorder in \(.applicationName)",
    "Start recording in \(.applicationName)",
    "Stop recording in \(.applicationName)"
   ],
   shortTitle: "Toggle Recorder",
   systemImageName: "mic.circle"
  )

  AppShortcut(
   intent: DismissMiniRecorderIntent(),
   phrases: [
    "Dismiss \(.applicationName) recorder",
    "Cancel \(.applicationName) recording",
    "Close \(.applicationName) recorder",
    "Hide \(.applicationName) recorder"
   ],
   shortTitle: "Dismiss Recorder",
   systemImageName: "xmark.circle"
  )

  AppShortcut(
   intent: ToggleEnhancementIntent(),
   phrases: [
    "Toggle \(.applicationName) enhancement",
    "Toggle AI enhancement in \(.applicationName)"
   ],
   shortTitle: "Toggle Enhancement",
   systemImageName: "wand.and.stars"
  )

  AppShortcut(
   intent: SetEnhancementModeIntent(),
   phrases: [
    "Set \(.applicationName) enhancement mode",
    "Change enhancement mode in \(.applicationName)"
   ],
   shortTitle: "Set Enhancement Mode",
   systemImageName: "slider.horizontal.3"
  )

  AppShortcut(
   intent: SelectPromptIntent(),
   phrases: [
    "Select \(.applicationName) prompt",
    "Change prompt in \(.applicationName)"
   ],
   shortTitle: "Select Prompt",
   systemImageName: "text.bubble"
  )

  AppShortcut(
   intent: GetRecordingStateIntent(),
   phrases: [
    "Get \(.applicationName) recording state",
    "What is \(.applicationName) doing"
   ],
   shortTitle: "Get Recording State",
   systemImageName: "info.circle"
  )

  AppShortcut(
   intent: ActivatePowerModeIntent(),
   phrases: [
    "Activate \(.applicationName) Power Mode",
    "Turn on Power Mode in \(.applicationName)"
   ],
   shortTitle: "Activate Power Mode",
   systemImageName: "bolt.circle"
  )

  AppShortcut(
   intent: GetLastTranscriptionIntent(),
   phrases: [
    "Get last \(.applicationName) transcription",
    "What did \(.applicationName) transcribe"
   ],
   shortTitle: "Get Last Transcription",
   systemImageName: "doc.text"
  )

  AppShortcut(
   intent: SearchTranscriptionsIntent(),
   phrases: [
    "Search \(.applicationName) transcriptions",
    "Find in \(.applicationName) history"
   ],
   shortTitle: "Search Transcriptions",
   systemImageName: "magnifyingglass"
  )

  AppShortcut(
   intent: TranscribeAudioFileIntent(),
   phrases: [
    "Transcribe audio with \(.applicationName)",
    "Transcribe file with \(.applicationName)"
   ],
   shortTitle: "Transcribe Audio File",
   systemImageName: "waveform"
  )
 }
}
