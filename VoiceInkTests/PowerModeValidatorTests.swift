import Testing
import Foundation
@testable import VoiceInk

// MARK: - Mock

private class MockPowerModeProvider: PowerModeProviding {
 var configurations: [PowerModeConfig] = []
 var activeConfiguration: PowerModeConfig?
 var currentActiveConfiguration: PowerModeConfig? { activeConfiguration }
 var enabledConfigurations: [PowerModeConfig] { configurations.filter { $0.isEnabled } }

 func getConfiguration(with id: UUID) -> PowerModeConfig? {
  configurations.first { $0.id == id }
 }
 func getConfigurationForURL(_ url: String) -> PowerModeConfig? { nil }
 func getConfigurationForApp(_ bundleId: String) -> PowerModeConfig? { nil }
 func getDefaultConfiguration() -> PowerModeConfig? { nil }
 func setActiveConfiguration(_ config: PowerModeConfig?) { activeConfiguration = config }
 func isEmojiInUse(_ emoji: String) -> Bool { configurations.contains { $0.emoji == emoji } }
}

struct PowerModeValidatorTests {

 // MARK: - Existing tests (using mock now)

 @Test func emptyNameFails() {
  let mock = MockPowerModeProvider()
  let validator = PowerModeValidator(powerModeManager: mock)
  let config = PowerModeConfig(name: "", emoji: "T", isAIEnhancementEnabled: false)

  let errors = validator.validateForSave(config: config, mode: .add)
  #expect(errors.contains { if case .emptyName = $0 { return true }; return false })
 }

 @Test func whitespaceOnlyNameFails() {
  let mock = MockPowerModeProvider()
  let validator = PowerModeValidator(powerModeManager: mock)
  let config = PowerModeConfig(name: "   ", emoji: "T", isAIEnhancementEnabled: false)

  let errors = validator.validateForSave(config: config, mode: .add)
  #expect(errors.contains { if case .emptyName = $0 { return true }; return false })
 }

 @Test func validNamePasses() {
  let mock = MockPowerModeProvider()
  let validator = PowerModeValidator(powerModeManager: mock)
  let config = PowerModeConfig(name: "MyMode", emoji: "T", isAIEnhancementEnabled: false)

  let errors = validator.validateForSave(config: config, mode: .add)
  #expect(errors.isEmpty)
 }

 // MARK: - Mock-based tests

 @Test func detectsDuplicateName() {
  let mock = MockPowerModeProvider()
  mock.configurations = [
   PowerModeConfig(name: "Work", emoji: "W", isAIEnhancementEnabled: false)
  ]
  let validator = PowerModeValidator(powerModeManager: mock)
  let newConfig = PowerModeConfig(name: "Work", emoji: "X", isAIEnhancementEnabled: false)

  let errors = validator.validateForSave(config: newConfig, mode: .add)
  #expect(errors.contains { if case .duplicateName = $0 { return true }; return false })
 }

 @Test func allowsSameNameInEditMode() {
  let mock = MockPowerModeProvider()
  let existingConfig = PowerModeConfig(name: "Work", emoji: "W", isAIEnhancementEnabled: false)
  mock.configurations = [existingConfig]
  let validator = PowerModeValidator(powerModeManager: mock)

  // Editing the same config should not flag duplicate name
  let errors = validator.validateForSave(config: existingConfig, mode: .edit(existingConfig))
  #expect(!errors.contains { if case .duplicateName = $0 { return true }; return false })
 }

 @Test func detectsDuplicateAppTrigger() {
  let mock = MockPowerModeProvider()
  let existingConfig = PowerModeConfig(
   name: "Coding",
   emoji: "C",
   appConfigs: [AppConfig(bundleIdentifier: "com.apple.safari", appName: "Safari")],
   isAIEnhancementEnabled: false
  )
  mock.configurations = [existingConfig]
  let validator = PowerModeValidator(powerModeManager: mock)

  let newConfig = PowerModeConfig(
   name: "Browsing",
   emoji: "B",
   appConfigs: [AppConfig(bundleIdentifier: "com.apple.safari", appName: "Safari")],
   isAIEnhancementEnabled: false
  )
  let errors = validator.validateForSave(config: newConfig, mode: .add)
  #expect(errors.contains { if case .duplicateAppTrigger = $0 { return true }; return false })
 }

 @Test func detectsDuplicateWebsiteTrigger() {
  let mock = MockPowerModeProvider()
  let existingConfig = PowerModeConfig(
   name: "GitHub",
   emoji: "G",
   urlConfigs: [URLConfig(url: "github.com")],
   isAIEnhancementEnabled: false
  )
  mock.configurations = [existingConfig]
  let validator = PowerModeValidator(powerModeManager: mock)

  let newConfig = PowerModeConfig(
   name: "Code",
   emoji: "C",
   urlConfigs: [URLConfig(url: "github.com")],
   isAIEnhancementEnabled: false
  )
  let errors = validator.validateForSave(config: newConfig, mode: .add)
  #expect(errors.contains { if case .duplicateWebsiteTrigger = $0 { return true }; return false })
 }
}
