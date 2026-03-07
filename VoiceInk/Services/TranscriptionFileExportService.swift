import Foundation
import AppKit

class TranscriptionFileExportService {

 private static let folderDateFormatter: DateFormatter = {
  let formatter = DateFormatter()
  formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
  return formatter
 }()

 func exportAsFiles(_ transcriptions: [Transcription]) {
  guard !transcriptions.isEmpty else { return }

  // Capture all model data on the main thread before going to background
  let entries = transcriptions.map { t in
   CapturedEntry(
    id: t.id,
    text: t.text,
    enhancedText: t.enhancedText,
    timestamp: t.timestamp,
    duration: t.duration,
    audioFileURL: t.audioFileURL,
    transcriptionModelName: t.transcriptionModelName,
    aiEnhancementModelName: t.aiEnhancementModelName,
    promptName: t.promptName,
    transcriptionDuration: t.transcriptionDuration,
    enhancementDuration: t.enhancementDuration,
    aiRequestSystemMessage: t.aiRequestSystemMessage,
    aiRequestUserMessage: t.aiRequestUserMessage,
    powerModeName: t.powerModeName,
    powerModeEmoji: t.powerModeEmoji,
    transcriptionStatus: t.transcriptionStatus,
    isPinned: t.isPinned,
    enhancementSource: t.enhancementSource,
    sttPrompt: t.sttPrompt,
    extractedVocabulary: t.extractedVocabulary,
    targetAppName: t.targetAppName,
    targetAppBundleId: t.targetAppBundleId
   )
  }

  // Present folder picker on the main thread, then write on background
  let panel = NSOpenPanel()
  panel.title = "Choose Export Folder"
  panel.message = "Select a folder to export \(entries.count) transcription\(entries.count == 1 ? "" : "s")."
  panel.canChooseFiles = false
  panel.canChooseDirectories = true
  panel.canCreateDirectories = true

  guard panel.runModal() == .OK, let baseURL = panel.url else { return }

  DispatchQueue.global(qos: .userInitiated).async {
   do {
    let exportRoot = baseURL.appendingPathComponent("VoiceInk-Export")
    try FileManager.default.createDirectory(at: exportRoot, withIntermediateDirectories: true)

    for entry in entries {
     let folderName = self.buildFolderName(entry)
     let entryDir = exportRoot.appendingPathComponent(folderName)
     try FileManager.default.createDirectory(at: entryDir, withIntermediateDirectories: true)

     try self.writeMetadataYAML(entry, to: entryDir)
     try self.writeTranscriptionMarkdown(entry, to: entryDir)
     try self.writePromptMarkdown(entry, to: entryDir)
     self.copyAudioFile(entry, to: entryDir)
    }

    DispatchQueue.main.async {
     NSWorkspace.shared.open(exportRoot)
    }
   } catch {
    DispatchQueue.main.async {
     let alert = NSAlert()
     alert.messageText = "Export Error"
     alert.informativeText = "Failed to export files: \(error.localizedDescription)"
     alert.alertStyle = .warning
     alert.addButton(withTitle: "OK")
     alert.runModal()
    }
   }
  }
 }

 // MARK: - File Writers

 private func writeMetadataYAML(_ entry: CapturedEntry, to dir: URL) throws {
  var lines: [String] = []
  lines.append("id: \(entry.id.uuidString)")
  lines.append("timestamp: \(entry.timestamp.ISO8601Format())")
  lines.append("duration: \(entry.duration)")
  lines.append("pinned: \(entry.isPinned)")

  if let model = entry.transcriptionModelName {
   lines.append("transcription_model: \(yamlEscape(model))")
  }
  if let dur = entry.transcriptionDuration {
   lines.append("transcription_duration: \(dur)")
  }
  if let model = entry.aiEnhancementModelName {
   lines.append("enhancement_model: \(yamlEscape(model))")
  }
  if let dur = entry.enhancementDuration {
   lines.append("enhancement_duration: \(dur)")
  }
  if let name = entry.promptName {
   lines.append("prompt_name: \(yamlEscape(name))")
  }
  if let name = entry.powerModeName {
   let emoji = entry.powerModeEmoji ?? ""
   lines.append("power_mode: \(yamlEscape(emoji.isEmpty ? name : "\(emoji) \(name)"))")
  }
  if let status = entry.transcriptionStatus {
   lines.append("status: \(status)")
  }
  if let source = entry.enhancementSource {
   lines.append("enhancement_source: \(source)")
  }
  if let app = entry.targetAppName {
   lines.append("target_app: \(yamlEscape(app))")
  }
  if let bundleId = entry.targetAppBundleId {
   lines.append("target_app_bundle_id: \(bundleId)")
  }

  let yaml = lines.joined(separator: "\n") + "\n"
  try yaml.write(to: dir.appendingPathComponent("metadata.yaml"), atomically: true, encoding: .utf8)
 }

 private func writeTranscriptionMarkdown(_ entry: CapturedEntry, to dir: URL) throws {
  var md = "# Transcription\n\n"
  md += "## Original\n\n"
  md += entry.text + "\n"

  if let enhanced = entry.enhancedText, !enhanced.isEmpty {
   md += "\n## Enhanced\n\n"
   md += enhanced + "\n"
  }

  try md.write(to: dir.appendingPathComponent("transcription.md"), atomically: true, encoding: .utf8)
 }

 private func writePromptMarkdown(_ entry: CapturedEntry, to dir: URL) throws {
  let hasSystem = entry.aiRequestSystemMessage != nil && !entry.aiRequestSystemMessage!.isEmpty
  let hasUser = entry.aiRequestUserMessage != nil && !entry.aiRequestUserMessage!.isEmpty
  guard hasSystem || hasUser else { return }

  var md = "# AI Enhancement Prompt\n\n"

  if let system = entry.aiRequestSystemMessage, !system.isEmpty {
   md += "## System Message\n\n"
   md += system + "\n"
  }

  if let user = entry.aiRequestUserMessage, !user.isEmpty {
   md += "\n## User Message\n\n"
   md += user + "\n"
  }

  try md.write(to: dir.appendingPathComponent("prompt.md"), atomically: true, encoding: .utf8)
 }

 private func copyAudioFile(_ entry: CapturedEntry, to dir: URL) {
  guard let urlString = entry.audioFileURL,
        let audioURL = URL(string: urlString),
        FileManager.default.fileExists(atPath: audioURL.path) else { return }

  let ext = audioURL.pathExtension.isEmpty ? "wav" : audioURL.pathExtension
  let dest = dir.appendingPathComponent("recording.\(ext)")
  try? FileManager.default.copyItem(at: audioURL, to: dest)
 }

 // MARK: - Helpers

 private func buildFolderName(_ entry: CapturedEntry) -> String {
  let dateStr = Self.folderDateFormatter.string(from: entry.timestamp)

  let displayText = entry.enhancedText ?? entry.text
  let words = displayText.split(separator: " ").prefix(4).joined(separator: "_")
  let safe = words
   .replacingOccurrences(of: "/", with: "-")
   .replacingOccurrences(of: ":", with: "-")
   .prefix(40)

  return "\(dateStr)_\(safe)"
 }

 private func yamlEscape(_ value: String) -> String {
  if value.contains(":") || value.contains("#") || value.contains("\"") ||
     value.contains("'") || value.contains("\n") {
   let escaped = value.replacingOccurrences(of: "\"", with: "\\\"")
   return "\"\(escaped)\""
  }
  return value
 }
}

private struct CapturedEntry {
 let id: UUID
 let text: String
 let enhancedText: String?
 let timestamp: Date
 let duration: TimeInterval
 let audioFileURL: String?
 let transcriptionModelName: String?
 let aiEnhancementModelName: String?
 let promptName: String?
 let transcriptionDuration: TimeInterval?
 let enhancementDuration: TimeInterval?
 let aiRequestSystemMessage: String?
 let aiRequestUserMessage: String?
 let powerModeName: String?
 let powerModeEmoji: String?
 let transcriptionStatus: String?
 let isPinned: Bool
 let enhancementSource: String?
 let sttPrompt: String?
 let extractedVocabulary: String?
 let targetAppName: String?
 let targetAppBundleId: String?
}
