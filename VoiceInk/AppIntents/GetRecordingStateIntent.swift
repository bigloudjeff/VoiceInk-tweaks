import AppIntents
import Foundation

struct GetRecordingStateIntent: AppIntent {
 static var title: LocalizedStringResource = "Get VoiceInk Recording State"
 static var description = IntentDescription("Get the current recording state of VoiceInk.")

 static var openAppWhenRun: Bool = false

 @MainActor
 func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
  guard let whisperState = AppServiceLocator.shared.whisperState else {
   throw IntentError.serviceNotAvailable
  }

  let state: String
  switch whisperState.recordingState {
  case .idle: state = "idle"
  case .starting: state = "starting"
  case .recording: state = "recording"
  case .transcribing: state = "transcribing"
  case .enhancing: state = "enhancing"
  case .busy: state = "busy"
  }

  return .result(value: state, dialog: "Recording state: \(state)")
 }
}
