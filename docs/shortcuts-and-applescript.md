# VoiceInk Shortcuts & AppleScript Guide

VoiceInk supports macOS Shortcuts (Siri, Shortcuts.app) and AppleScript for automating transcription workflows. This guide covers every available action.

---

## Shortcuts (AppIntents)

Open **Shortcuts.app** and search for "VoiceInk" to see all available actions. You can also invoke them via Siri using the phrases listed below.

### Recording

| Action | Parameters | Returns | Siri Phrase |
|--------|-----------|---------|-------------|
| **Toggle Recorder** | -- | Dialog | "Toggle VoiceInk recorder" |
| **Dismiss Recorder** | -- | Dialog | "Dismiss VoiceInk recorder" |
| **Get Recording State** | -- | Text (`idle`, `recording`, `transcribing`, `enhancing`, `busy`) | "Get VoiceInk recording state" |

### AI Enhancement

| Action | Parameters | Returns | Siri Phrase |
|--------|-----------|---------|-------------|
| **Toggle Enhancement** | -- | Dialog (enabled/disabled) | "Toggle VoiceInk enhancement" |
| **Set Enhancement Mode** | Mode: `Off`, `On`, `Background` | Dialog | "Set VoiceInk enhancement mode" |
| **Select Prompt** | Prompt Name (text) | Dialog | "Select VoiceInk prompt" |
| **Toggle Screen Context** | -- | Dialog (enabled/disabled) | -- |
| **Toggle Clipboard Context** | -- | Dialog (enabled/disabled) | -- |

### Power Mode

| Action | Parameters | Returns | Siri Phrase |
|--------|-----------|---------|-------------|
| **Activate Power Mode** | Name (text) | Dialog | "Activate VoiceInk Power Mode" |
| **Deactivate Power Mode** | -- | Dialog | -- |

### Transcription Data

| Action | Parameters | Returns | Siri Phrase |
|--------|-----------|---------|-------------|
| **Get Last Transcription** | -- | Text (transcription content) | "Get last VoiceInk transcription" |
| **Get Recent Transcriptions** | Count (default: 5) | Text (formatted list) | -- |
| **Search Transcriptions** | Query (text) | Text (matching results) | "Search VoiceInk transcriptions" |

### Utility

| Action | Parameters | Returns | Siri Phrase |
|--------|-----------|---------|-------------|
| **Set Language** | Language Code (e.g. `en`, `fr`, `auto`) | Dialog | -- |
| **Transcribe Audio File** | Audio File | Text (transcription) | "Transcribe audio with VoiceInk" |

### Shortcuts Examples

**Quick dictation setup** -- Create a shortcut that activates a Power Mode, sets a prompt, then toggles the recorder:

1. Add "Activate VoiceInk Power Mode" -- set name to "Email"
2. Add "Select VoiceInk Prompt" -- set name to "Natural Voice"
3. Add "Toggle VoiceInk Recorder"

**Get last transcription to clipboard** -- Pair "Get Last VoiceInk Transcription" with the built-in "Copy to Clipboard" action.

**Batch transcription** -- Use "Transcribe Audio File with VoiceInk" inside a "Repeat with Each" loop over a folder of audio files.

---

## AppleScript

VoiceInk exposes a full scripting dictionary. Open **Script Editor**, go to Window > Library, and add VoiceInk to browse the dictionary.

### Read-Only Properties

Access these on the `application` object:

```applescript
tell application "VoiceInk"
    get recording state        -- "idle", "starting", "recording", "transcribing", "enhancing", "busy"
    get enhancement enabled    -- true / false
    get enhancement mode       -- "off", "on", "background"
    get active prompt name     -- "Natural Voice", "Assistant", etc.
    get active power mode      -- Power Mode name, or "" if none active
end tell
```

### Commands

#### Recording

```applescript
tell application "VoiceInk"
    toggle recording       -- Start or stop the recorder
    dismiss recorder       -- Dismiss the recorder and cancel recording
end tell
```

#### AI Enhancement

```applescript
tell application "VoiceInk"
    -- Toggle enhancement on/off
    toggle enhancement

    -- Set a specific mode: "off", "on", or "background"
    set enhancement mode "on"
    set enhancement mode "background"
    set enhancement mode "off"

    -- Select a prompt by name
    select prompt "Natural Voice"
    select prompt "Assistant"

    -- Toggle context sources
    toggle screen context
    toggle clipboard context
end tell
```

#### Power Mode

```applescript
tell application "VoiceInk"
    -- Activate a Power Mode by name
    activate power mode "Email"

    -- Deactivate the current Power Mode
    deactivate power mode
end tell
```

#### Transcription Data

```applescript
tell application "VoiceInk"
    -- Get the most recent transcription text
    get last transcription
end tell
```

#### Language

```applescript
tell application "VoiceInk"
    -- Set the transcription language
    set language "en"
    set language "fr"
    set language "auto"
end tell
```

### AppleScript Examples

**Quick capture workflow** -- Toggle recording, wait, then grab the result:

```applescript
tell application "VoiceInk"
    toggle recording
end tell

-- Wait for recording to finish (user stops manually)
delay 10

tell application "VoiceInk"
    set transcribedText to get last transcription
end tell

-- Do something with the text
tell application "Notes"
    tell account "iCloud"
        make new note at folder "Notes" with properties {body:transcribedText}
    end tell
end tell
```

**Switch context for different tasks:**

```applescript
on setVoiceInkForEmail()
    tell application "VoiceInk"
        activate power mode "Email"
        select prompt "Natural Voice"
        set enhancement mode "on"
    end tell
end setVoiceInkForEmail

on setVoiceInkForCoding()
    tell application "VoiceInk"
        deactivate power mode
        select prompt "Assistant"
        set enhancement mode "on"
        toggle screen context -- enable screen context for code awareness
    end tell
end setVoiceInkForCoding
```

**Poll recording state (for advanced automation):**

```applescript
tell application "VoiceInk"
    toggle recording
    repeat
        set currentState to get recording state
        if currentState is "idle" then exit repeat
        delay 1
    end repeat
    get last transcription
end tell
```

---

## Notes

- All 15 Shortcuts actions work without opening VoiceInk's main window (`openAppWhenRun` is false).
- AppleScript commands that involve async operations (Power Mode activation/deactivation) return immediately while the operation completes in the background.
- Prompt and Power Mode names are matched case-insensitively with leading/trailing whitespace trimmed.
- If a prompt or Power Mode name is not found, the command returns an error message listing all available options.
- The "Transcribe Audio File" shortcut uses whichever transcription model is currently selected in VoiceInk.
- "Get Recent Transcriptions" caps at 50 results; "Search Transcriptions" caps at 20 results.
