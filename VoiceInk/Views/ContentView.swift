import SwiftUI
import SwiftData
import KeyboardShortcuts

// ViewType enum with all cases
enum ViewType: String, CaseIterable, Identifiable {
    case metrics = "Dashboard"
    case pipeline = "Pipeline"
    case transcribeAudio = "Transcribe Audio"
    case history = "History"
    case models = "AI Models"
    case enhancement = "Enhancement"
    case postProcessing = "Post Processing"
    case powerMode = "Power Mode"
    case permissions = "Permissions"
    case audioInput = "Audio Input"
    case dictionary = "Dictionary"
    case settings = "Settings"
    case license = "VoiceInk Pro"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .metrics: return "gauge.medium"
        case .pipeline: return "point.3.connected.trianglepath.dotted"
        case .transcribeAudio: return "waveform.circle.fill"
        case .history: return "doc.text.fill"
        case .models: return "brain.head.profile"
        case .enhancement: return "wand.and.stars"
        case .postProcessing: return "arrow.trianglehead.2.clockwise"
        case .powerMode: return "sparkles.square.fill.on.square"
        case .permissions: return "shield.fill"
        case .audioInput: return "mic.fill"
        case .dictionary: return "character.book.closed.fill"
        case .settings: return "gearshape.fill"
        case .license: return "checkmark.seal.fill"
        }
    }

    /// Display name in the sidebar (may differ from rawValue).
    var displayName: String {
        switch self {
        case .settings: return "Preferences"
        default: return rawValue
        }
    }

    /// Whether this view type appears in the sidebar.
    /// Removed items are still navigable via URL scheme / notifications
    /// but are absorbed into the Pipeline or Preferences views.
    var isVisibleInSidebar: Bool {
        switch self {
        case .enhancement, .postProcessing, .audioInput, .models, .dictionary:
            return false
        default:
            return true
        }
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let visualEffectView = NSVisualEffectView()
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
        visualEffectView.state = .active
        return visualEffectView
    }

    func updateNSView(_ visualEffectView: NSVisualEffectView, context: Context) {
        visualEffectView.material = material
        visualEffectView.blendingMode = blendingMode
    }
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @EnvironmentObject private var whisperState: WhisperState
    @EnvironmentObject private var hotkeyManager: HotkeyManager
    @AppStorage(UserDefaults.Keys.powerModeUIFlag) private var powerModeUIFlag = false
    @State private var selectedView: ViewType? = .metrics
    @State private var selectedPipelineStage: PipelineStage? = nil
    @State private var isPipelineExpanded: Bool = false
    @State private var pendingView: ViewType?
    @State private var showUnsavedChangesAlert = false
    @State private var searchText = ""
    @ObservedObject private var powerModeManager = PowerModeManager.shared
    @FocusState private var searchFieldFocused: Bool
    let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    @StateObject private var licenseViewModel = LicenseViewModel()

    private var guardedSelection: Binding<ViewType?> {
        Binding(
            get: { selectedView },
            set: { newValue in
                if selectedView == .powerMode && powerModeManager.hasUnsavedEdits {
                    pendingView = newValue
                    showUnsavedChangesAlert = true
                } else {
                    selectedView = newValue
                }
            }
        )
    }

    private var visibleViewTypes: [ViewType] {
        ViewType.allCases.filter { viewType in
            guard viewType.isVisibleInSidebar else { return false }
            if viewType == .powerMode {
                return powerModeUIFlag
            }
            return true
        }
    }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                    TextField("Search settings...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .focused($searchFieldFocused)
                        .accessibilityIdentifier(AccessibilityID.Sidebar.searchField)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color.primary.opacity(0.06))
                .cornerRadius(8)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)

                List(selection: guardedSelection) {
                    Section {
                        // App Header
                        HStack(spacing: 6) {
                            if let appIcon = NSImage(named: "AppIcon") {
                                Image(nsImage: appIcon)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 28, height: 28)
                                    .cornerRadius(8)
                            }

                            Text("VoiceInk")
                                .font(.system(size: 14, weight: .semibold))

                            if case .licensed = licenseViewModel.licenseState {
                                Text("PRO")
                                    .font(.system(size: 9, weight: .heavy))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Color.blue)
                                    .cornerRadius(4)
                            }

                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }

                    if searchText.isEmpty {
                    ForEach(visibleViewTypes) { viewType in
                        if viewType == .pipeline {
                            Section {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isPipelineExpanded.toggle()
                                    }
                                } label: {
                                    HStack {
                                        SidebarItemView(viewType: viewType)
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundColor(.secondary)
                                            .rotationEffect(.degrees(isPipelineExpanded ? 90 : 0))
                                    }
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier(AccessibilityID.Sidebar.navLink(viewType.rawValue))
                                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                                .listRowSeparator(.hidden)

                                if isPipelineExpanded {
                                    ForEach(PipelineStage.allCases) { stage in
                                        Button {
                                            selectedPipelineStage = stage
                                            selectedView = .pipeline
                                        } label: {
                                            PipelineSidebarItem(
                                                stage: stage,
                                                isSelected: selectedView == .pipeline && selectedPipelineStage == stage
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .listRowInsets(EdgeInsets(top: 0, leading: 8, bottom: 0, trailing: 0))
                                        .listRowSeparator(.hidden)
                                    }
                                }
                            }
                        } else if viewType == .history {
                            Section {
                                Button(action: {
                                    HistoryWindowController.shared.showHistoryWindow(
                                        modelContainer: modelContext.container,
                                        whisperState: whisperState
                                    )
                                }) {
                                    SidebarItemView(viewType: viewType)
                                }
                                .accessibilityIdentifier(AccessibilityID.Sidebar.buttonHistory)
                                .buttonStyle(.plain)
                                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                                .listRowSeparator(.hidden)
                            }
                        } else {
                            Section {
                                NavigationLink(value: viewType) {
                                    SidebarItemView(viewType: viewType)
                                }
                                .accessibilityIdentifier(AccessibilityID.Sidebar.navLink(viewType.rawValue))
                                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                                .listRowSeparator(.hidden)
                            }
                        }
                    }
                } else {
                    Section {
                        SettingsSearchResultsView(
                            query: searchText,
                            selectedView: $selectedView,
                            searchText: $searchText
                        )
                    }
                }
            }
            .accessibilityIdentifier(AccessibilityID.Sidebar.list)
            .listStyle(.sidebar)
            }
            .navigationTitle("VoiceInk")
            .navigationSplitViewColumnWidth(210)
        } detail: {
            if let selectedView = selectedView {
                detailView(for: selectedView)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .navigationTitle(selectedView.rawValue)
            } else {
                Text("Select a view")
                    .foregroundColor(.secondary)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 950)
        .frame(minHeight: 730)
        .onExitCommand {
            if !searchText.isEmpty {
                searchText = ""
            }
        }
        .alert("Unsaved Changes", isPresented: $showUnsavedChangesAlert) {
            Button("Save") {
                let destination = pendingView
                pendingView = nil
                NotificationCenter.default.post(name: .powerModeConfigSaveRequested, object: destination)
            }
            Button("Discard", role: .destructive) {
                powerModeManager.hasUnsavedEdits = false
                selectedView = pendingView
                pendingView = nil
            }
            Button("Cancel", role: .cancel) {
                pendingView = nil
            }
        } message: {
            Text("You have unsaved Power Mode changes.")
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToDestination)) { notification in
            let destination: NavigationDestination?
            if let typed = notification.userInfo?[NavigationDestination.userInfoKey] as? NavigationDestination {
                destination = typed
            } else if let legacy = notification.userInfo?["destination"] as? String {
                destination = NavigationDestination(legacyString: legacy)
            } else {
                destination = nil
            }
            guard let destination else { return }
            switch destination {
            case .view(let viewType):
                selectedView = viewType
            case .pipelineStage(let stage):
                selectedPipelineStage = stage
                selectedView = .pipeline
            case .historyWindow:
                HistoryWindowController.shared.showHistoryWindow(
                    modelContainer: modelContext.container,
                    whisperState: whisperState
                )
            }
        }
    }
    
    @ViewBuilder
    private func detailView(for viewType: ViewType) -> some View {
        switch viewType {
        case .metrics:
            MetricsView()
        case .pipeline:
            PipelineView(selectedView: $selectedView, selectedStage: $selectedPipelineStage)
        case .models, .enhancement, .postProcessing, .audioInput, .dictionary:
            // These are now absorbed into Pipeline
            PipelineView(selectedView: $selectedView, selectedStage: $selectedPipelineStage)
        case .transcribeAudio:
            AudioTranscribeView()
        case .history:
            Text("History")
                .foregroundColor(.secondary)
        case .powerMode:
            PowerModeView()
        case .settings:
            SettingsView()
                .environmentObject(whisperState)
        case .license:
            LicenseManagementView()
        case .permissions:
            PermissionsView()
        }
    }
}

private struct SidebarItemView: View {
    let viewType: ViewType

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: viewType.icon)
                .font(.system(size: 18, weight: .medium))
                .frame(width: 24, height: 24)

            Text(viewType.displayName)
                .font(.system(size: 14, weight: .medium))

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .padding(.vertical, 8)
        .padding(.horizontal, 2)
    }
}

private struct PipelineSidebarItem: View {
    let stage: PipelineStage
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(isSelected ? stage.color : stage.color.opacity(0.3))
                .frame(width: 8, height: 8)

            Image(systemName: stage.icon)
                .font(.system(size: 12))
                .foregroundColor(isSelected ? stage.color : .secondary)
                .frame(width: 16)

            Text(stage.title)
                .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? .primary : .secondary)

            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .contentShape(Rectangle())
    }
}

