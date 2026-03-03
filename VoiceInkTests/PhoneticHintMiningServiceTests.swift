import Testing
@testable import VoiceInk

struct PhoneticHintMiningServiceTests {

 // MARK: - isPlausiblePhoneticHint

 @Test func acceptsGenuineMishearing() {
  // "chezmoy" sounds like "chezmoi"
  #expect(PhoneticHintMiningService.isPlausiblePhoneticHint(raw: "chezmoy", corrected: "chezmoi"))
 }

 @Test func rejectsMorphologicalVariant() {
  // "clicking" is just an inflection of "click"
  #expect(!PhoneticHintMiningService.isPlausiblePhoneticHint(raw: "clicking", corrected: "click"))
 }

 @Test func rejectsAbbreviation() {
  // "devs" is a short prefix of "developers" (corrected >= 2x raw length)
  #expect(!PhoneticHintMiningService.isPlausiblePhoneticHint(raw: "devs", corrected: "developers"))
 }

 @Test func rejectsContainedVocabWord() {
  // Raw contains the corrected word verbatim plus extra
  #expect(!PhoneticHintMiningService.isPlausiblePhoneticHint(raw: "slash ideation", corrected: "ideation"))
 }

 @Test func rejectsLowBigramSimilarity() {
  // Completely unrelated words
  #expect(!PhoneticHintMiningService.isPlausiblePhoneticHint(raw: "banana", corrected: "keyboard"))
 }

 @Test func rejectsEmptyInput() {
  #expect(!PhoneticHintMiningService.isPlausiblePhoneticHint(raw: "", corrected: "test"))
  #expect(!PhoneticHintMiningService.isPlausiblePhoneticHint(raw: "test", corrected: ""))
 }

 @Test func rejectsSlashCommand() {
  #expect(!PhoneticHintMiningService.isPlausiblePhoneticHint(raw: "slash commit", corrected: "/commit"))
 }

 @Test func rejectsTokenCountMismatch() {
  // Token count differs by more than 1
  #expect(!PhoneticHintMiningService.isPlausiblePhoneticHint(raw: "one two three four", corrected: "single"))
 }

 // MARK: - mergeHints

 @Test func mergesNewHintsWithExisting() {
  let result = PhoneticHintMiningService.mergeHints(existing: "klaud, clod", new: ["klawd"])
  #expect(result == "klaud, clod, klawd")
 }

 @Test func skipsDuplicateHints() {
  let result = PhoneticHintMiningService.mergeHints(existing: "klaud", new: ["klaud", "klawd"])
  #expect(result == "klaud, klawd")
 }

 @Test func handlesEmptyExisting() {
  let result = PhoneticHintMiningService.mergeHints(existing: "", new: ["klaud", "klawd"])
  #expect(result == "klaud, klawd")
 }

 @Test func handlesEmptyNew() {
  let result = PhoneticHintMiningService.mergeHints(existing: "klaud", new: [])
  #expect(result == "klaud")
 }

 @Test func caseInsensitiveDuplicateCheck() {
  let result = PhoneticHintMiningService.mergeHints(existing: "Klaud", new: ["klaud"])
  #expect(result == "Klaud")
 }
}
