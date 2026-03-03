import Foundation

enum VoiceInkDataError: Error {
 case saveFailed(context: String, underlying: Error)
 case fetchFailed(entity: String, underlying: Error)
}
