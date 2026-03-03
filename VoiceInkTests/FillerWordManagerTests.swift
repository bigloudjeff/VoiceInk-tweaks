import Testing
import Foundation
@testable import VoiceInk

@Suite(.serialized)
struct FillerWordManagerTests {

 @Test func defaultFillerWordsAreLoaded() {
  let defaults = FillerWordManager.defaultFillerWords
  #expect(defaults.contains("uh"))
  #expect(defaults.contains("um"))
  #expect(defaults.contains("hmm"))
  #expect(defaults.count == 15)
 }

 @Test func addWordSucceeds() {
  let manager = FillerWordManager.shared
  let savedWords = manager.fillerWords

  let added = manager.addWord("zzztest")
  #expect(added == true)
  #expect(manager.fillerWords.contains("zzztest"))

  // Cleanup
  manager.removeWord("zzztest")
  manager.fillerWords = savedWords
 }

 @Test func addWordRejectsDuplicate() {
  let manager = FillerWordManager.shared
  let savedWords = manager.fillerWords

  _ = manager.addWord("zzzdup")
  let secondAdd = manager.addWord("zzzdup")
  #expect(secondAdd == false)

  // Cleanup
  manager.removeWord("zzzdup")
  manager.fillerWords = savedWords
 }

 @Test func addWordRejectsEmpty() {
  let manager = FillerWordManager.shared
  #expect(manager.addWord("") == false)
  #expect(manager.addWord("   ") == false)
 }

 @Test func removeWordWorks() {
  let manager = FillerWordManager.shared
  let savedWords = manager.fillerWords

  _ = manager.addWord("zzzremove")
  #expect(manager.fillerWords.contains("zzzremove"))

  manager.removeWord("zzzremove")
  #expect(!manager.fillerWords.contains("zzzremove"))

  // Cleanup
  manager.fillerWords = savedWords
 }
}
