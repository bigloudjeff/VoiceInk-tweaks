import SwiftUI

struct TranscriptionDetailView: View {
 let transcription: Transcription

 private var hasAudioFile: Bool {
  if let urlString = transcription.audioFileURL,
     let url = URL(string: urlString),
     FileManager.default.fileExists(atPath: url.path) {
   return true
  }
  return false
 }

 var body: some View {
  VStack(spacing: 0) {
   ScrollView {
    VStack(alignment: .leading, spacing: 16) {
     TranscriptionSection(
      label: "Original",
      icon: "mic.fill",
      text: transcription.text
     )

     if let enhancedText = transcription.enhancedText, !enhancedText.isEmpty {
      TranscriptionSection(
       label: "Enhanced",
       icon: "sparkles",
       text: enhancedText,
       tint: Color.accentColor
      )

      if enhancedText != transcription.text {
       DiffSection(
        originalText: transcription.text,
        enhancedText: enhancedText
       )
      }

      if let extractedVocab = transcription.extractedVocabulary, !extractedVocab.isEmpty {
       VocabularyChipsSection(extractedVocabulary: extractedVocab)
      }
     }
    }
    .padding(16)
   }

   if hasAudioFile, let urlString = transcription.audioFileURL,
      let url = URL(string: urlString) {
    VStack(spacing: 0) {
     Divider()

     AudioPlayerView(url: url)
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(
       RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(Color(NSColor.controlBackgroundColor).opacity(0.5))
      )
      .padding(.horizontal, 12)
      .padding(.top, 6)
    }
   }
  }
  .padding(.vertical, 12)
  .background(Color(NSColor.controlBackgroundColor))
 }
}

// MARK: - Transcription Section

private struct TranscriptionSection: View {
 let label: String
 let icon: String
 let text: String
 var tint: Color?
 @State private var justCopied = false

 var body: some View {
  VStack(alignment: .leading, spacing: 6) {
   HStack(spacing: 4) {
    Image(systemName: icon)
     .font(.system(size: 10, weight: .semibold))
    Text(label)
     .font(.system(size: 11, weight: .semibold))
   }
   .foregroundColor(tint ?? .secondary)

   Text(text)
    .font(.system(size: 14, weight: .regular))
    .lineSpacing(3)
    .textSelection(.enabled)
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(
     RoundedRectangle(cornerRadius: 10, style: .continuous)
      .fill(tint?.opacity(0.06) ?? Color.clear)
      .background(
       RoundedRectangle(cornerRadius: 10, style: .continuous)
        .fill(.thinMaterial)
      )
      .overlay(
       RoundedRectangle(cornerRadius: 10, style: .continuous)
        .strokeBorder(tint?.opacity(0.15) ?? Color.primary.opacity(0.06), lineWidth: 0.5)
      )
    )
    .overlay(alignment: .topTrailing) {
     Button(action: { copyToClipboard() }) {
      Image(systemName: justCopied ? "checkmark" : "doc.on.doc")
       .font(.system(size: 11))
       .foregroundColor(justCopied ? .green : .secondary)
       .frame(width: 24, height: 24)
       .background(Color(NSColor.controlBackgroundColor).opacity(0.9))
       .clipShape(Circle())
     }
     .buttonStyle(.plain)
     .help("Copy to clipboard")
     .padding(6)
    }
  }
 }

 private func copyToClipboard() {
  let _ = ClipboardManager.copyToClipboard(text)
  withAnimation { justCopied = true }
  DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
   withAnimation { justCopied = false }
  }
 }
}

// MARK: - Vocabulary Chips

private struct VocabularyChipsSection: View {
 let extractedVocabulary: String

 private var entries: [(raw: String, corrected: String, isPhoneticHint: Bool)] {
  extractedVocabulary.components(separatedBy: "\n").compactMap { line in
   let isHint = line.hasSuffix("(phonetic hint)")
   let cleaned = line.replacingOccurrences(of: " (phonetic hint)", with: "")
   let parts = cleaned.components(separatedBy: " -> ")
   guard parts.count == 2 else { return nil }
   return (raw: parts[0].trimmingCharacters(in: .whitespaces),
           corrected: parts[1].trimmingCharacters(in: .whitespaces),
           isPhoneticHint: isHint)
  }
 }

 var body: some View {
  VStack(alignment: .leading, spacing: 6) {
   HStack(spacing: 4) {
    Image(systemName: "character.book.closed.fill")
     .font(.system(size: 10, weight: .semibold))
    Text("Extracted Vocabulary")
     .font(.system(size: 11, weight: .semibold))
   }
   .foregroundColor(.secondary)

   VocabFlowLayout(spacing: 6) {
    ForEach(Array(entries.enumerated()), id: \.offset) { _, entry in
     HStack(spacing: 3) {
      Text(entry.corrected)
       .font(.system(size: 11, weight: .semibold))
       .foregroundColor(entry.isPhoneticHint ? .orange : Color(NSColor.systemGreen))
      Text(entry.raw)
       .font(.system(size: 10, weight: .regular))
       .foregroundColor(.secondary)
     }
     .padding(.horizontal, 8)
     .padding(.vertical, 4)
     .background(
      RoundedRectangle(cornerRadius: 6, style: .continuous)
       .fill(entry.isPhoneticHint
        ? Color.orange.opacity(0.1)
        : Color(NSColor.systemGreen).opacity(0.1))
       .overlay(
        RoundedRectangle(cornerRadius: 6, style: .continuous)
         .strokeBorder(entry.isPhoneticHint
          ? Color.orange.opacity(0.2)
          : Color(NSColor.systemGreen).opacity(0.2), lineWidth: 0.5)
       )
     )
    }
   }
  }
 }
}

private struct VocabFlowLayout: Layout {
 var spacing: CGFloat

 func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
  let rows = computeRows(proposal: proposal, subviews: subviews)
  var height: CGFloat = 0
  for (i, row) in rows.enumerated() {
   let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
   height += rowHeight
   if i < rows.count - 1 { height += spacing }
  }
  return CGSize(width: proposal.width ?? 0, height: height)
 }

 func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
  let rows = computeRows(proposal: proposal, subviews: subviews)
  var y = bounds.minY
  for (i, row) in rows.enumerated() {
   var x = bounds.minX
   let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
   for view in row {
    let size = view.sizeThatFits(.unspecified)
    view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
    x += size.width + spacing
   }
   y += rowHeight
   if i < rows.count - 1 { y += spacing }
  }
 }

 private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubview]] {
  let maxWidth = proposal.width ?? .infinity
  var rows: [[LayoutSubview]] = [[]]
  var currentWidth: CGFloat = 0

  for view in subviews {
   let size = view.sizeThatFits(.unspecified)
   if currentWidth + size.width > maxWidth && !rows[rows.count - 1].isEmpty {
    rows.append([])
    currentWidth = 0
   }
   rows[rows.count - 1].append(view)
   currentWidth += size.width + spacing
  }
  return rows
 }
}

// MARK: - Diff Section

private struct DiffSection: View {
 let originalText: String
 let enhancedText: String

 var body: some View {
  VStack(alignment: .leading, spacing: 6) {
   HStack(spacing: 4) {
    Image(systemName: "plus.forwardslash.minus")
     .font(.system(size: 10, weight: .semibold))
    Text("Changes")
     .font(.system(size: 11, weight: .semibold))
   }
   .foregroundColor(.secondary)

   VStack(alignment: .leading, spacing: 0) {
    let groups = WordDiff.computeGroups(original: originalText, enhanced: enhancedText)
    ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
     switch group {
     case .unchanged(let text):
      Text(text)
       .font(.system(size: 13, weight: .regular))
       .foregroundColor(.primary.opacity(0.5))
       .padding(.vertical, 1)
       .padding(.horizontal, 12)
     case .changed(let removed, let added):
      VStack(alignment: .leading, spacing: 1) {
       if !removed.isEmpty {
        HStack(spacing: 4) {
         Text("-")
          .font(.system(size: 12, weight: .bold, design: .monospaced))
         Text(removed)
          .font(.system(size: 13, weight: .medium))
          .strikethrough()
        }
        .foregroundColor(Color(NSColor.systemRed))
        .padding(.vertical, 3)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.systemRed).opacity(0.12))
       }
       if !added.isEmpty {
        HStack(spacing: 4) {
         Text("+")
          .font(.system(size: 12, weight: .bold, design: .monospaced))
         Text(added)
          .font(.system(size: 13, weight: .medium))
        }
        .foregroundColor(Color(NSColor.systemGreen))
        .padding(.vertical, 3)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.systemGreen).opacity(0.12))
       }
      }
      .padding(.vertical, 2)
      .padding(.horizontal, 4)
     }
    }
   }
   .padding(.vertical, 10)
   .frame(maxWidth: .infinity, alignment: .leading)
   .background(
    RoundedRectangle(cornerRadius: 10, style: .continuous)
     .fill(.thinMaterial)
     .overlay(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
       .strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
     )
   )
  }
 }
}

// MARK: - Word Diff Engine

private enum DiffGroup {
 case unchanged(String)
 case changed(removed: String, added: String)
}

private enum WordDiff {
 static func computeGroups(original: String, enhanced: String) -> [DiffGroup] {
  let origWords = tokenize(original)
  let enhWords = tokenize(enhanced)
  let lcs = longestCommonSubsequence(origWords, enhWords)

  var groups: [DiffGroup] = []
  var oi = 0, ei = 0, li = 0

  while oi < origWords.count || ei < enhWords.count {
   if li < lcs.count {
    var removedWords: [String] = []
    var addedWords: [String] = []

    while oi < origWords.count && trimmed(origWords[oi]) != trimmed(lcs[li]) {
     removedWords.append(origWords[oi])
     oi += 1
    }
    while ei < enhWords.count && trimmed(enhWords[ei]) != trimmed(lcs[li]) {
     addedWords.append(enhWords[ei])
     ei += 1
    }

    if !removedWords.isEmpty || !addedWords.isEmpty {
     groups.append(.changed(
      removed: removedWords.joined().trimmingCharacters(in: .whitespaces),
      added: addedWords.joined().trimmingCharacters(in: .whitespaces)
     ))
    }

    var unchangedWords: [String] = []
    while li < lcs.count && oi < origWords.count && ei < enhWords.count
           && trimmed(origWords[oi]) == trimmed(lcs[li]) {
     unchangedWords.append(origWords[oi])
     oi += 1
     ei += 1
     li += 1
    }
    if !unchangedWords.isEmpty {
     let text = unchangedWords.joined().trimmingCharacters(in: .whitespaces)
     if !text.isEmpty {
      groups.append(.unchanged(text))
     }
    }
   } else {
    var removedWords: [String] = []
    var addedWords: [String] = []
    while oi < origWords.count {
     removedWords.append(origWords[oi])
     oi += 1
    }
    while ei < enhWords.count {
     addedWords.append(enhWords[ei])
     ei += 1
    }
    if !removedWords.isEmpty || !addedWords.isEmpty {
     groups.append(.changed(
      removed: removedWords.joined().trimmingCharacters(in: .whitespaces),
      added: addedWords.joined().trimmingCharacters(in: .whitespaces)
     ))
    }
   }
  }

  return groups
 }

 private static func tokenize(_ text: String) -> [String] {
  var tokens: [String] = []
  var current = ""
  var inWord = false

  for char in text {
   if char.isWhitespace || char.isNewline {
    if inWord {
     current.append(char)
     tokens.append(current)
     current = ""
     inWord = false
    } else {
     current.append(char)
    }
   } else {
    current.append(char)
    inWord = true
   }
  }
  if !current.isEmpty {
   tokens.append(current)
  }
  return tokens
 }

 private static func longestCommonSubsequence(_ a: [String], _ b: [String]) -> [String] {
  let m = a.count, n = b.count
  guard m > 0 && n > 0 else { return [] }
  var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)

  for i in 1...m {
   for j in 1...n {
    if trimmed(a[i - 1]) == trimmed(b[j - 1]) {
     dp[i][j] = dp[i - 1][j - 1] + 1
    } else {
     dp[i][j] = max(dp[i - 1][j], dp[i][j - 1])
    }
   }
  }

  var result: [String] = []
  var i = m, j = n
  while i > 0 && j > 0 {
   if trimmed(a[i - 1]) == trimmed(b[j - 1]) {
    result.append(a[i - 1])
    i -= 1
    j -= 1
   } else if dp[i - 1][j] > dp[i][j - 1] {
    i -= 1
   } else {
    j -= 1
   }
  }

  return result.reversed()
 }

 private static func trimmed(_ s: String) -> String {
  s.trimmingCharacters(in: .whitespacesAndNewlines)
 }
}
