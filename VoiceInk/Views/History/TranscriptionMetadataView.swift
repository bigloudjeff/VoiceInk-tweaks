import SwiftUI
import SwiftData
import os

struct TranscriptionMetadataView: View {
    private static let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "TranscriptionMetadataView")
    @Environment(\.modelContext) private var modelContext
    let transcription: Transcription
    private let fileExportService = TranscriptionFileExportService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Details")
                    .font(.system(size: 14, weight: .semibold))

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 20, height: 20)

                        Text("Pinned")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)

                        Spacer(minLength: 0)

                        Button(action: {
                            transcription.isPinned.toggle()
                            do {
                                try modelContext.save()
                            } catch {
                                Self.logger.error("Failed to save pin state: \(error.localizedDescription, privacy: .public)")
                            }
                        }) {
                            Image(systemName: transcription.isPinned ? "pin.fill" : "pin")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(transcription.isPinned ? .accentColor : .secondary)
                        }
                        .buttonStyle(.plain)
                        .help(transcription.isPinned ? "Unpin" : "Pin")
                        .accessibilityIdentifier(AccessibilityID.History.buttonMetadataPin)
                    }

                    Divider()

                    metadataRow(
                        icon: "calendar",
                        label: "Date",
                        value: transcription.timestamp.formatted(date: .abbreviated, time: .shortened)
                    )

                    Divider()

                    metadataRow(
                        icon: "hourglass",
                        label: "Duration",
                        value: transcription.duration.formatTiming()
                    )

                    if let modelName = transcription.transcriptionModelName {
                        Divider()
                        metadataRow(
                            icon: "cpu.fill",
                            label: "Transcription Model",
                            value: modelName
                        )

                        if let duration = transcription.transcriptionDuration {
                            Divider()
                            metadataRow(
                                icon: "clock.fill",
                                label: "Transcription Time",
                                value: duration.formatTiming()
                            )
                        }
                    }

                    if let aiModel = transcription.aiEnhancementModelName {
                        Divider()
                        metadataRow(
                            icon: "sparkles",
                            label: "Enhancement Model",
                            value: aiModel
                        )

                        if let source = transcription.enhancementSource {
                            Divider()
                            metadataRow(
                                icon: source == "background" ? "arrow.triangle.2.circlepath" : "bolt.fill",
                                label: "Enhancement Mode",
                                value: source == "background" ? "Post Processing" : "Synchronous"
                            )
                        }

                        if let duration = transcription.enhancementDuration {
                            Divider()
                            metadataRow(
                                icon: "clock.fill",
                                label: "Enhancement Time",
                                value: duration.formatTiming()
                            )
                        }
                    }

                    if let promptName = transcription.promptName {
                        Divider()
                        metadataRow(
                            icon: "text.bubble.fill",
                            label: "Prompt",
                            value: promptName
                        )
                    }

                    if let appName = transcription.targetAppName, !appName.isEmpty {
                        Divider()
                        metadataRow(
                            icon: "app.fill",
                            label: "Target App",
                            value: appName
                        )
                    }

                    if let powerModeValue = powerModeDisplay(
                        name: transcription.powerModeName,
                        emoji: transcription.powerModeEmoji
                    ) {
                        Divider()
                        metadataRow(
                            icon: "bolt.fill",
                            label: "Power Mode",
                            value: powerModeValue
                        )
                    }

                    if let urlString = transcription.audioFileURL,
                       let audioURL = URL(string: urlString),
                       FileManager.default.fileExists(atPath: audioURL.path) {
                        Divider()
                        HStack(spacing: 8) {
                            Image(systemName: "waveform")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.secondary)
                                .frame(width: 20, height: 20)
                            Text("Audio File")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                            Spacer(minLength: 0)
                            Button(action: {
                                NSWorkspace.shared.activateFileViewerSelecting([audioURL])
                            }) {
                                Image(systemName: "arrow.up.forward.square")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Show in Finder")
                            .accessibilityIdentifier(AccessibilityID.History.buttonRevealAudioFile)
                        }
                    }

                    Divider()
                    HStack(spacing: 8) {
                        Image(systemName: "cylinder")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 20, height: 20)
                        Text("Transcription Store")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer(minLength: 0)
                        Button(action: {
                            let storeURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                                .appendingPathComponent("com.prakashjoshipax.VoiceInk")
                                .appendingPathComponent("default.store")
                            NSWorkspace.shared.activateFileViewerSelecting([storeURL])
                        }) {
                            Image(systemName: "arrow.up.forward.square")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Show in Finder")
                        .accessibilityIdentifier(AccessibilityID.History.buttonRevealStore)
                    }
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.thinMaterial)
                )

                Button(action: {
                    fileExportService.exportAsFiles([transcription])
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export Entry")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.thinMaterial)
                )
                .accessibilityIdentifier(AccessibilityID.History.buttonExportEntry)

                if let sttPrompt = transcription.sttPrompt, !sttPrompt.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("STT Prompt")
                            .font(.system(size: 14, weight: .semibold))

                        ScrollView {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Sent to transcription model")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary)
                                Text(sttPrompt)
                                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                                    .lineSpacing(2)
                                    .textSelection(.enabled)
                                    .foregroundColor(.primary)
                            }
                            .padding(14)
                        }
                        .frame(minHeight: 60, maxHeight: 200)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(.thinMaterial)
                        )
                    }
                }

                if let extractedVocab = transcription.extractedVocabulary, !extractedVocab.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Extracted Vocabulary")
                            .font(.system(size: 14, weight: .semibold))

                        ScrollView {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Corrections found by comparing raw and enhanced text")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.secondary)
                                Text(extractedVocab)
                                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                                    .lineSpacing(2)
                                    .textSelection(.enabled)
                                    .foregroundColor(.primary)
                            }
                            .padding(14)
                        }
                        .frame(minHeight: 60, maxHeight: 200)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(.thinMaterial)
                        )
                    }
                }

                if transcription.aiRequestSystemMessage != nil || transcription.aiRequestUserMessage != nil {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("AI Request")
                            .font(.system(size: 14, weight: .semibold))

                        ScrollView {
                            VStack(alignment: .leading, spacing: 12) {
                                if let systemMsg = transcription.aiRequestSystemMessage, !systemMsg.isEmpty {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("System Prompt")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(.secondary)
                                        Text(systemMsg)
                                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                                            .lineSpacing(2)
                                            .textSelection(.enabled)
                                            .foregroundColor(.primary)
                                    }
                                }

                                if let userMsg = transcription.aiRequestUserMessage, !userMsg.isEmpty {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("User Message")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(.secondary)
                                        Text(userMsg)
                                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                                            .lineSpacing(2)
                                            .textSelection(.enabled)
                                            .foregroundColor(.primary)
                                    }
                                }
                            }
                            .padding(14)
                        }
                        .frame(minHeight: 250, maxHeight: 500)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(.thinMaterial)
                        )
                    }
                }
            }
            .padding(12)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func metadataRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .frame(width: 20, height: 20)

            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)

            Spacer(minLength: 0)

            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(1)
        }
    }

    private func powerModeDisplay(name: String?, emoji: String?) -> String? {
        guard name != nil || emoji != nil else { return nil }

        switch (emoji?.trimmingCharacters(in: .whitespacesAndNewlines), name?.trimmingCharacters(in: .whitespacesAndNewlines)) {
        case let (.some(emojiValue), .some(nameValue)) where !emojiValue.isEmpty && !nameValue.isEmpty:
            return "\(emojiValue) \(nameValue)"
        case let (.some(emojiValue), _) where !emojiValue.isEmpty:
            return emojiValue
        case let (_, .some(nameValue)) where !nameValue.isEmpty:
            return nameValue
        default:
            return nil
        }
    }
}
