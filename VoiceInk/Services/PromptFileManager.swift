import Foundation
import os

/// Loads prompt text from bundle resources with user override support.
///
/// Loading priority:
/// 1. User override file in Application Support (if it exists)
/// 2. Bundle resource file in Prompts/
/// 3. Hard-coded fallback (safety net only)
struct PromptFileManager {
 private static let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "PromptFileManager")

 private static let appSupportPromptsURL: URL = {
  let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
  return appSupport.appendingPathComponent("com.prakashjoshipax.VoiceInk/Prompts", isDirectory: true)
 }()

 // MARK: - Public API

 /// Load a prompt file by name (without extension).
 /// Checks user override first, then bundle resource.
 static func load(_ name: String, subdirectory: String? = nil) -> String? {
  // 1. Check user override
  if let userText = loadUserOverride(name, subdirectory: subdirectory) {
   logger.debug("Loaded user override for \(name, privacy: .public)")
   return userText
  }

  // 2. Check bundle resource
  if let bundleText = loadBundleResource(name, subdirectory: subdirectory) {
   logger.debug("Loaded bundle resource for \(name, privacy: .public)")
   return bundleText
  }

  logger.warning("No prompt file found for \(name, privacy: .public)")
  return nil
 }

 /// Save a user override for the given prompt file.
 static func saveUserOverride(_ name: String, subdirectory: String? = nil, content: String) {
  let dir = userOverrideDirectory(subdirectory: subdirectory)
  do {
   try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
   let fileURL = dir.appendingPathComponent("\(name).md")
   try content.write(to: fileURL, atomically: true, encoding: .utf8)
   logger.info("Saved user override for \(name, privacy: .public)")
  } catch {
   logger.error("Failed to save user override for \(name, privacy: .public): \(error.localizedDescription, privacy: .public)")
  }
 }

 /// Remove a user override, reverting to the bundle default.
 static func removeUserOverride(_ name: String, subdirectory: String? = nil) {
  let fileURL = userOverrideDirectory(subdirectory: subdirectory).appendingPathComponent("\(name).md")
  try? FileManager.default.removeItem(at: fileURL)
  logger.info("Removed user override for \(name, privacy: .public)")
 }

 /// Check whether a user override exists for the given prompt.
 static func hasUserOverride(_ name: String, subdirectory: String? = nil) -> Bool {
  let fileURL = userOverrideDirectory(subdirectory: subdirectory).appendingPathComponent("\(name).md")
  return FileManager.default.fileExists(atPath: fileURL.path)
 }

 /// Migrate legacy UserDefaults system instructions to file-based storage.
 /// Called once on app launch; no-ops if already migrated or nothing to migrate.
 static func migrateFromUserDefaults() {
  let migrationKey = "promptFileManagerMigrationComplete"
  guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

  // Migrate custom system instructions
  if let saved = UserDefaults.standard.string(forKey: UserDefaults.Keys.systemInstructionsTemplate) {
   saveUserOverride("system-instructions", content: saved)
   UserDefaults.standard.removeObject(forKey: UserDefaults.Keys.systemInstructionsTemplate)
   logger.info("Migrated system instructions from UserDefaults to file")
  }

  UserDefaults.standard.set(true, forKey: migrationKey)
 }

 // MARK: - Private

 private static func userOverrideDirectory(subdirectory: String?) -> URL {
  if let subdirectory {
   return appSupportPromptsURL.appendingPathComponent(subdirectory, isDirectory: true)
  }
  return appSupportPromptsURL
 }

 private static func loadUserOverride(_ name: String, subdirectory: String?) -> String? {
  let fileURL = userOverrideDirectory(subdirectory: subdirectory).appendingPathComponent("\(name).md")
  guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
  return try? String(contentsOf: fileURL, encoding: .utf8)
 }

 private static func loadBundleResource(_ name: String, subdirectory: String?) -> String? {
  // Xcode flattens resources into Contents/Resources/ (no subdirectories),
  // so we look up by filename only, ignoring the subdirectory parameter.
  guard let url = Bundle.main.url(forResource: name, withExtension: "md") else {
   return nil
  }
  return try? String(contentsOf: url, encoding: .utf8)
 }
}
