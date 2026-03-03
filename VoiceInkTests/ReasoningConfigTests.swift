import Testing
@testable import VoiceInk

struct ReasoningConfigTests {

 @Test func geminiFlashReturnsLow() {
  #expect(ReasoningConfig.getReasoningParameter(for: "gemini-2.5-flash") == "low")
 }

 @Test func geminiFlashLiteReturnsLow() {
  #expect(ReasoningConfig.getReasoningParameter(for: "gemini-2.5-flash-lite") == "low")
 }

 @Test func openAIReasoningReturnsMinimal() {
  #expect(ReasoningConfig.getReasoningParameter(for: "gpt-5-mini") == "minimal")
  #expect(ReasoningConfig.getReasoningParameter(for: "gpt-5-nano") == "minimal")
 }

 @Test func cerebrasReasoningReturnsLow() {
  #expect(ReasoningConfig.getReasoningParameter(for: "gpt-oss-120b") == "low")
 }

 @Test func nonReasoningModelReturnsNil() {
  #expect(ReasoningConfig.getReasoningParameter(for: "gpt-4o") == nil)
  #expect(ReasoningConfig.getReasoningParameter(for: "claude-3-opus") == nil)
 }

 @Test func emptyStringReturnsNil() {
  #expect(ReasoningConfig.getReasoningParameter(for: "") == nil)
 }
}
