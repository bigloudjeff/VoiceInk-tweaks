import SwiftUI
import SwiftData
import os

struct TranscriptionHistoryView: View {
    private static let logger = Logger(subsystem: "com.prakashjoshipax.voiceink", category: "TranscriptionHistoryView")
    @Environment(\.modelContext) private var modelContext
    @State private var searchText = ""
    @State private var selectedTranscription: Transcription?
    @State private var selectedTranscriptions: Set<Transcription> = []
    @State private var showDeleteConfirmation = false
    @State private var showPinnedDeletionAlert = false
    @State private var lastClickedTranscription: Transcription?
    @State private var isViewCurrentlyVisible = false
    @State private var showAnalysisView = false
    @State private var isLeftSidebarVisible = true
    @State private var isRightSidebarVisible = true
    @State private var leftSidebarWidth: CGFloat = 260
    @State private var rightSidebarWidth: CGFloat = 260
    @State private var displayedTranscriptions: [Transcription] = []
    @State private var isLoading = false
    @State private var hasMoreContent = true
    @State private var lastTimestamp: Date?
    @State private var selectedPowerMode: String? = nil
    @State private var selectedModelName: String? = nil
    @State private var selectedTargetApp: String? = nil
    @State private var availablePowerModes: [String] = []
    @State private var availableModelNames: [String] = []
    @State private var availableTargetApps: [String] = []

    private let exportService = VoiceInkCSVExportService()
    private let fileExportService = TranscriptionFileExportService()
    private let minSidebarWidth: CGFloat = 200
    private let maxSidebarWidth: CGFloat = 350
    private let pageSize = 20

    private func matchesActiveFilters(_ t: Transcription) -> Bool {
        if let mode = selectedPowerMode, t.powerModeName != mode { return false }
        if let model = selectedModelName, t.transcriptionModelName != model { return false }
        if let app = selectedTargetApp, t.targetAppName != app { return false }
        return true
    }

    private var filteredTranscriptions: [Transcription] {
        displayedTranscriptions.filter(matchesActiveFilters)
    }

    private var groupedTranscriptions: [(header: String, transcriptions: [Transcription])] {
        let calendar = Calendar.current
        let now = Date()
        let startOfToday = calendar.startOfDay(for: now)
        guard let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday),
              let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: now)?.start,
              let startOfMonth = calendar.dateInterval(of: .month, for: now)?.start
        else { return [("All", filteredTranscriptions)] }

        var today: [Transcription] = []
        var yesterday: [Transcription] = []
        var thisWeek: [Transcription] = []
        var thisMonth: [Transcription] = []
        var older: [Transcription] = []

        for t in filteredTranscriptions {
            if t.timestamp >= startOfToday {
                today.append(t)
            } else if t.timestamp >= startOfYesterday {
                yesterday.append(t)
            } else if t.timestamp >= startOfWeek {
                thisWeek.append(t)
            } else if t.timestamp >= startOfMonth {
                thisMonth.append(t)
            } else {
                older.append(t)
            }
        }

        var groups: [(header: String, transcriptions: [Transcription])] = []
        if !today.isEmpty { groups.append(("Today", today)) }
        if !yesterday.isEmpty { groups.append(("Yesterday", yesterday)) }
        if !thisWeek.isEmpty { groups.append(("This Week", thisWeek)) }
        if !thisMonth.isEmpty { groups.append(("This Month", thisMonth)) }
        if !older.isEmpty { groups.append(("Older", older)) }
        return groups
    }

    @Query(Self.createLatestTranscriptionIndicatorDescriptor()) private var latestTranscriptionIndicator: [Transcription]

    private static func createLatestTranscriptionIndicatorDescriptor() -> FetchDescriptor<Transcription> {
        var descriptor = FetchDescriptor<Transcription>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return descriptor
    }

    private func cursorQueryDescriptor(after timestamp: Date? = nil) -> FetchDescriptor<Transcription> {
        var descriptor = FetchDescriptor<Transcription>(
            sortBy: [SortDescriptor(\Transcription.timestamp, order: .reverse)]
        )

        if let timestamp = timestamp {
            if !searchText.isEmpty {
                descriptor.predicate = #Predicate<Transcription> { transcription in
                    (transcription.text.localizedStandardContains(searchText) ||
                    (transcription.enhancedText?.localizedStandardContains(searchText) ?? false)) &&
                    transcription.timestamp < timestamp
                }
            } else {
                descriptor.predicate = #Predicate<Transcription> { transcription in
                    transcription.timestamp < timestamp
                }
            }
        } else if !searchText.isEmpty {
            descriptor.predicate = #Predicate<Transcription> { transcription in
                transcription.text.localizedStandardContains(searchText) ||
                (transcription.enhancedText?.localizedStandardContains(searchText) ?? false)
            }
        }
        
        descriptor.fetchLimit = pageSize
        return descriptor
    }
    
    var body: some View {
        HStack(spacing: 0) {
            if isLeftSidebarVisible {
                leftSidebarView
                    .frame(
                        minWidth: minSidebarWidth,
                        idealWidth: leftSidebarWidth,
                        maxWidth: maxSidebarWidth
                    )
                    .transition(.move(edge: .leading))

                Divider()
            }

            centerPaneView
                .frame(maxWidth: .infinity)

            if isRightSidebarVisible {
                Divider()

                rightSidebarView
                    .frame(
                        minWidth: minSidebarWidth,
                        idealWidth: rightSidebarWidth,
                        maxWidth: maxSidebarWidth
                    )
                    .transition(.move(edge: .trailing))
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .navigation) {
                Button(action: { withAnimation { isLeftSidebarVisible.toggle() } }) {
                    Label("Toggle Sidebar", systemImage: "sidebar.left")
                }
                .accessibilityIdentifier(AccessibilityID.History.buttonToggleLeftSidebar)
            }

            ToolbarItemGroup(placement: .automatic) {
                Button(action: { withAnimation { isRightSidebarVisible.toggle() } }) {
                    Label("Toggle Inspector", systemImage: "sidebar.right")
                }
                .accessibilityIdentifier(AccessibilityID.History.buttonToggleRightSidebar)
            }
        }
        .alert("Delete Selected Items?", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                deleteSelectedTranscriptions()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone. Are you sure you want to delete \(selectedTranscriptions.count) item\(selectedTranscriptions.count == 1 ? "" : "s")?")
        }
        .alert("Pinned Items Cannot Be Deleted", isPresented: $showPinnedDeletionAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            let pinnedCount = selectedTranscriptions.filter(\.isPinned).count
            Text("\(pinnedCount) pinned item\(pinnedCount == 1 ? "" : "s") in the selection. Unpin them first to delete.")
        }
        .sheet(isPresented: $showAnalysisView) {
            if !selectedTranscriptions.isEmpty {
                PerformanceAnalysisView(transcriptions: Array(selectedTranscriptions))
            }
        }
        .onAppear {
            isViewCurrentlyVisible = true
            Task {
                await loadInitialContent()
            }
        }
        .onDisappear {
            isViewCurrentlyVisible = false
        }
        .onChange(of: searchText) { _, _ in
            Task {
                await resetPagination()
                await loadInitialContent()
            }
        }
        .onChange(of: latestTranscriptionIndicator.first?.id) { oldId, newId in
            guard isViewCurrentlyVisible else { return }
            if newId != oldId {
                Task {
                    await resetPagination()
                    await loadInitialContent()
                }
            }
        }
    }

    private var leftSidebarView: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 13))
                TextField("Search transcriptions", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .font(.system(size: 13))
                    .accessibilityIdentifier(AccessibilityID.History.fieldSearch)
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.thinMaterial)
            )
            .padding(12)

            if !availablePowerModes.isEmpty || !availableModelNames.isEmpty || !availableTargetApps.isEmpty {
                HStack(spacing: 6) {
                    if !availablePowerModes.isEmpty {
                        HistoryFilterMenu(
                            selection: $selectedPowerMode,
                            options: availablePowerModes,
                            placeholder: "Power Mode",
                            allLabel: "All Power Modes",
                            accessibilityId: AccessibilityID.History.menuPowerModeFilter
                        )
                    }

                    if !availableModelNames.isEmpty {
                        HistoryFilterMenu(
                            selection: $selectedModelName,
                            options: availableModelNames,
                            placeholder: "Model",
                            allLabel: "All Models",
                            accessibilityId: AccessibilityID.History.menuModelFilter
                        )
                    }

                    if !availableTargetApps.isEmpty {
                        HistoryFilterMenu(
                            selection: $selectedTargetApp,
                            options: availableTargetApps,
                            placeholder: "App",
                            allLabel: "All Apps",
                            accessibilityId: "history_menu_target_app_filter"
                        )
                    }

                    if selectedPowerMode != nil || selectedModelName != nil || selectedTargetApp != nil {
                        Button {
                            selectedPowerMode = nil
                            selectedModelName = nil
                            selectedTargetApp = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear all filters")
                        .accessibilityIdentifier(AccessibilityID.History.buttonClearFilters)
                    }

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
            }

            Divider()

            ZStack(alignment: .bottom) {
                if filteredTranscriptions.isEmpty && !isLoading {
                    if hasMoreContent && (selectedPowerMode != nil || selectedModelName != nil || selectedTargetApp != nil) {
                        VStack(spacing: 12) {
                            ProgressView().controlSize(.small)
                            Text("Searching...")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .task {
                            await loadUntilFilteredResultsOrExhausted()
                        }
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text("No transcriptions")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8, pinnedViews: .sectionHeaders) {
                            ForEach(groupedTranscriptions, id: \.header) { group in
                                Section {
                                    ForEach(group.transcriptions) { transcription in
                                        TranscriptionListItem(
                                            transcription: transcription,
                                            isSelected: selectedTranscription == transcription,
                                            isChecked: selectedTranscriptions.contains(transcription),
                                            onSelect: {
                                                let flags = NSEvent.modifierFlags
                                                if flags.contains(.command) {
                                                    toggleSelection(transcription)
                                                    selectedTranscription = transcription
                                                } else if flags.contains(.shift) {
                                                    shiftSelectTo(transcription)
                                                } else {
                                                    selectedTranscription = transcription
                                                    selectedTranscriptions = [transcription]
                                                    lastClickedTranscription = transcription
                                                }
                                            },
                                            onToggleCheck: { toggleSelection(transcription) }
                                        )
                                    }
                                } header: {
                                    Text(group.header)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 4)
                                        .background(Color(NSColor.controlBackgroundColor).opacity(0.95))
                                }
                            }

                            if hasMoreContent {
                                if isLoading {
                                    HStack {
                                        Spacer()
                                        ProgressView().controlSize(.small)
                                        Spacer()
                                    }
                                    .padding(.vertical, 10)
                                } else {
                                    Color.clear
                                        .frame(height: 1)
                                        .onAppear {
                                            Task { await loadMoreContent() }
                                        }
                                }
                            }
                        }
                        .padding(8)
                        .padding(.bottom, 50)
                    }
                }

                if !filteredTranscriptions.isEmpty {
                    selectionToolbar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var centerPaneView: some View {
        Group {
            if let transcription = selectedTranscription {
                TranscriptionDetailView(transcription: transcription)
                    .id(transcription.id)
            } else {
                ScrollView {
                    VStack(spacing: 32) {
                        Spacer()
                            .frame(minHeight: 40)

                        VStack(spacing: 12) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 50))
                                .foregroundColor(.secondary)
                            Text("No Selection")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundColor(.secondary)
                            Text("Select a transcription to view details")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }

                        HistoryShortcutTipView()
                            .padding(.horizontal, 24)

                        Spacer()
                            .frame(minHeight: 40)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 600)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.controlBackgroundColor))
            }
        }
    }

    private var rightSidebarView: some View {
        Group {
            if let transcription = selectedTranscription {
                TranscriptionMetadataView(transcription: transcription)
                    .id(transcription.id)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("No Metadata")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.controlBackgroundColor))
            }
        }
    }

    private var selectionToolbar: some View {
        HStack(spacing: 12) {
            Button(action: {
                if selectedTranscriptions.isEmpty {
                    Task { await selectAllTranscriptions() }
                } else {
                    selectedTranscriptions.removeAll()
                }
            }) {
                Image(systemName: selectedTranscriptions.isEmpty ? "circle" : "checkmark.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .foregroundColor(selectedTranscriptions.isEmpty ? .secondary : Color(NSColor.controlAccentColor))
                    .font(.system(size: 18))
            }
            .buttonStyle(.plain)
            .help(selectedTranscriptions.isEmpty ? "Select All" : "Deselect All")
            .accessibilityIdentifier(selectedTranscriptions.isEmpty ? AccessibilityID.History.buttonSelectAll : AccessibilityID.History.buttonDeselectAll)

            Divider()
                .frame(height: 16)

            Button(action: { togglePinForSelected() }) {
                Image(systemName: !selectedTranscriptions.isEmpty && selectedTranscriptions.allSatisfy(\.isPinned) ? "pin.slash" : "pin.fill")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help(!selectedTranscriptions.isEmpty && selectedTranscriptions.allSatisfy(\.isPinned) ? "Unpin" : "Pin")
            .accessibilityIdentifier(AccessibilityID.History.buttonPin)
            .disabled(selectedTranscriptions.isEmpty)

            Button(action: { showAnalysisView = true }) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Analyze")
            .accessibilityIdentifier(AccessibilityID.History.buttonAnalyze)
            .disabled(selectedTranscriptions.isEmpty)

            Menu {
                Button("Export as CSV") {
                    exportService.exportTranscriptionsToCSV(transcriptions: Array(selectedTranscriptions))
                }
                Button("Export as Files") {
                    fileExportService.exportAsFiles(Array(selectedTranscriptions))
                }
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.secondary)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Export")
            .accessibilityIdentifier(AccessibilityID.History.buttonExport)
            .disabled(selectedTranscriptions.isEmpty)

            Button(action: { showDeleteConfirmation = true }) {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Delete")
            .accessibilityIdentifier(AccessibilityID.History.buttonDelete)
            .disabled(selectedTranscriptions.isEmpty)

            Spacer()

            if !selectedTranscriptions.isEmpty {
                Text("\(selectedTranscriptions.count) selected")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            Color(NSColor.windowBackgroundColor)
                .shadow(color: Color.black.opacity(0.15), radius: 3, y: -2)
        )
    }
    
    @MainActor
    private func loadInitialContent() async {
        isLoading = true
        defer { isLoading = false }

        do {
            lastTimestamp = nil
            let items = try modelContext.fetch(cursorQueryDescriptor())
            displayedTranscriptions = items
            lastTimestamp = items.last?.timestamp
            hasMoreContent = items.count == pageSize
            updateAvailableFilterOptions()
        } catch {
            Self.logger.error("Error loading transcriptions: \(error.localizedDescription, privacy: .public)")
        }
    }

    @MainActor
    private func loadMoreContent() async {
        guard !isLoading, hasMoreContent, let lastTimestamp = lastTimestamp else { return }

        isLoading = true
        defer { isLoading = false }

        do {
            let newItems = try modelContext.fetch(cursorQueryDescriptor(after: lastTimestamp))
            displayedTranscriptions.append(contentsOf: newItems)
            self.lastTimestamp = newItems.last?.timestamp
            hasMoreContent = newItems.count == pageSize
            updateAvailableFilterOptions()
        } catch {
            Self.logger.error("Error loading more transcriptions: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    @MainActor
    private func loadUntilFilteredResultsOrExhausted() async {
        while filteredTranscriptions.isEmpty && hasMoreContent {
            guard !isLoading else { return }
            await loadMoreContent()
        }
    }

    @MainActor
    private func resetPagination() {
        displayedTranscriptions = []
        lastTimestamp = nil
        hasMoreContent = true
        isLoading = false
        availablePowerModes = []
        availableModelNames = []
        availableTargetApps = []
    }

    private func updateAvailableFilterOptions() {
        var modes = Set(availablePowerModes)
        var models = Set(availableModelNames)
        var apps = Set(availableTargetApps)
        for t in displayedTranscriptions {
            if let m = t.powerModeName, !m.isEmpty { modes.insert(m) }
            if let m = t.transcriptionModelName, !m.isEmpty { models.insert(m) }
            if let a = t.targetAppName, !a.isEmpty { apps.insert(a) }
        }
        availablePowerModes = modes.sorted()
        availableModelNames = models.sorted()
        availableTargetApps = apps.sorted()
    }

    private func performDeletion(for transcription: Transcription) {
        if let urlString = transcription.audioFileURL,
           let url = URL(string: urlString),
           FileManager.default.fileExists(atPath: url.path) {
            do {
                try FileManager.default.removeItem(at: url)
            } catch {
                Self.logger.error("Error deleting audio file: \(error.localizedDescription, privacy: .public)")
            }
        }

        if selectedTranscription == transcription {
            selectedTranscription = nil
        }

        selectedTranscriptions.remove(transcription)
        modelContext.delete(transcription)
    }

    private func saveAndReload() async {
        do {
            try modelContext.save()
            NotificationCenter.default.post(name: .transcriptionDeleted, object: nil)
            await loadInitialContent()
        } catch {
            Self.logger.error("Error saving deletion: \(error.localizedDescription, privacy: .public)")
            await loadInitialContent()
        }
    }

    private func deleteTranscription(_ transcription: Transcription) {
        performDeletion(for: transcription)
        Task {
            await saveAndReload()
        }
    }

    private func deleteSelectedTranscriptions() {
        let pinnedCount = selectedTranscriptions.filter(\.isPinned).count
        if pinnedCount > 0 {
            showPinnedDeletionAlert = true
            return
        }
        for transcription in selectedTranscriptions {
            performDeletion(for: transcription)
        }
        selectedTranscriptions.removeAll()

        Task {
            await saveAndReload()
        }
    }

    private func togglePinForSelected() {
        let allPinned = selectedTranscriptions.allSatisfy(\.isPinned)
        for transcription in selectedTranscriptions {
            transcription.isPinned = !allPinned
        }
        do {
            try modelContext.save()
        } catch {
            Self.logger.error("Failed to save pin state: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    private func toggleSelection(_ transcription: Transcription) {
        if selectedTranscriptions.contains(transcription) {
            selectedTranscriptions.remove(transcription)
        } else {
            selectedTranscriptions.insert(transcription)
        }
        lastClickedTranscription = transcription
    }

    private func shiftSelectTo(_ transcription: Transcription) {
        guard let anchor = lastClickedTranscription else {
            selectedTranscription = transcription
            selectedTranscriptions = [transcription]
            lastClickedTranscription = transcription
            return
        }
        let allItems = filteredTranscriptions
        guard let anchorIdx = allItems.firstIndex(where: { $0.id == anchor.id }),
              let targetIdx = allItems.firstIndex(where: { $0.id == transcription.id }) else {
            selectedTranscription = transcription
            selectedTranscriptions = [transcription]
            lastClickedTranscription = transcription
            return
        }
        let range = min(anchorIdx, targetIdx)...max(anchorIdx, targetIdx)
        selectedTranscriptions = Set(allItems[range])
        selectedTranscription = transcription
    }

    private func selectAllTranscriptions() async {
        do {
            var allDescriptor = FetchDescriptor<Transcription>()

            if !searchText.isEmpty {
                allDescriptor.predicate = #Predicate<Transcription> { transcription in
                    transcription.text.localizedStandardContains(searchText) ||
                    (transcription.enhancedText?.localizedStandardContains(searchText) ?? false)
                }
            }

            let allTranscriptions = try modelContext.fetch(allDescriptor)
            let filtered = allTranscriptions.filter(matchesActiveFilters)

            await MainActor.run {
                selectedTranscriptions = Set(filtered)
            }
        } catch {
            Self.logger.error("Error selecting all transcriptions: \(error.localizedDescription, privacy: .public)")
        }
    }
}

// MARK: - Filter Menu Component

private struct HistoryFilterMenu: View {
    @Binding var selection: String?
    let options: [String]
    let placeholder: String
    let allLabel: String
    let accessibilityId: String

    var body: some View {
        Menu {
            Button(allLabel) { selection = nil }
            Divider()
            ForEach(options, id: \.self) { option in
                Button(option) { selection = option }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selection ?? placeholder)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 8, weight: .bold))
            }
            .font(.system(size: 11, weight: selection != nil ? .semibold : .regular))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(selection != nil ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityId)
    }
}
