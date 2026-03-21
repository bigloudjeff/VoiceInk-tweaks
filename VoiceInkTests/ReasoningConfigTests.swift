import Testing
@testable import VoiceInk

struct ReasoningConfigTests {

 @Test func geminiFlashReturnsNone() {
  #expect(ReasoningConfig.getReasoningParameter(for: "gemini-2.5-flash") == "none")
  #expect(ReasoningConfig.getReasoningParameter(for: "gemini-2.5-flash-lite") == "none")
 }

 @Test func geminiProReturnsMinimal() {
  #expect(ReasoningConfig.getReasoningParameter(for: "gemini-2.5-pro") == "minimal")
  #expect(ReasoningConfig.getReasoningParameter(for: "gemini-3.1-pro-preview") == "minimal")
  #expect(ReasoningConfig.getReasoningParameter(for: "gemini-3-flash-preview") == "minimal")
  #expect(ReasoningConfig.getReasoningParameter(for: "gemini-3.1-flash-lite-preview") == "minimal")
 }

 @Test func openAI54ReturnsNone() {
  #expect(ReasoningConfig.getReasoningParameter(for: "gpt-5.4") == "none")
  #expect(ReasoningConfig.getReasoningParameter(for: "gpt-5.4-mini") == "none")
  #expect(ReasoningConfig.getReasoningParameter(for: "gpt-5.4-nano") == "none")
  #expect(ReasoningConfig.getReasoningParameter(for: "gpt-5.2") == "none")
 }

 @Test func openAIOlderReturnsMinimal() {
  #expect(ReasoningConfig.getReasoningParameter(for: "gpt-5-mini") == "minimal")
  #expect(ReasoningConfig.getReasoningParameter(for: "gpt-5-nano") == "minimal")
 }

 @Test func cerebrasReasoningReturnsLow() {
  #expect(ReasoningConfig.getReasoningParameter(for: "gpt-oss-120b") == "low")
 }

 @Test func groqReasoningReturnsLow() {
  #expect(ReasoningConfig.getReasoningParameter(for: "openai/gpt-oss-120b") == "low")
  #expect(ReasoningConfig.getReasoningParameter(for: "openai/gpt-oss-20b") == "low")
 }

 @Test func groqQwenReturnsNone() {
  #expect(ReasoningConfig.getReasoningParameter(for: "qwen/qwen3-32b") == "none")
 }

 @Test func nonReasoningModelReturnsNil() {
  #expect(ReasoningConfig.getReasoningParameter(for: "gpt-4o") == nil)
  #expect(ReasoningConfig.getReasoningParameter(for: "claude-3-opus") == nil)
 }

 @Test func emptyStringReturnsNil() {
  #expect(ReasoningConfig.getReasoningParameter(for: "") == nil)
 }

 // MARK: - requiresFixedTemperature

 @Test func gpt5RequiresFixedTemperature() {
  #expect(ReasoningConfig.requiresFixedTemperature("gpt-5.4") == true)
  #expect(ReasoningConfig.requiresFixedTemperature("gpt-5.4-mini") == true)
  #expect(ReasoningConfig.requiresFixedTemperature("gpt-5.2") == true)
  #expect(ReasoningConfig.requiresFixedTemperature("gpt-5-mini") == true)
  #expect(ReasoningConfig.requiresFixedTemperature("gpt-5-nano") == true)
 }

 @Test func nonFixedTemperatureModels() {
  #expect(ReasoningConfig.requiresFixedTemperature("gpt-4o") == false)
  #expect(ReasoningConfig.requiresFixedTemperature("claude-3-opus") == false)
  #expect(ReasoningConfig.requiresFixedTemperature("") == false)
 }

 // MARK: - Extra body parameters

 @Test func cerebrasDisableReasoningExtraParams() {
  let params = ReasoningConfig.getExtraBodyParameters(for: "zai-glm-4.7")
  #expect(params?["disable_reasoning"] as? Bool == true)
 }

 @Test func normalModelNoExtraParams() {
  #expect(ReasoningConfig.getExtraBodyParameters(for: "gpt-5.4") == nil)
 }
}
