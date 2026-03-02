import Foundation
import SwiftData

@MainActor
final class AppServiceLocator {
 static let shared = AppServiceLocator()

 private(set) var whisperState: WhisperState?
 private(set) var enhancementService: AIEnhancementService?
 private(set) var modelContainer: ModelContainer?

 private init() {}

 func configure(
  whisperState: WhisperState,
  enhancementService: AIEnhancementService,
  modelContainer: ModelContainer
 ) {
  self.whisperState = whisperState
  self.enhancementService = enhancementService
  self.modelContainer = modelContainer
 }
}
