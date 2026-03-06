import SwiftUI
import SwiftData
import KeyboardShortcuts

// ViewType enum with all cases
enum ViewType: String, CaseIterable, Identifiable {
    case metrics = "Dashboard"
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
                        Section {
                            if viewType == .history {
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
                            } else {
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
            if let destination = notification.userInfo?["destination"] as? String {
                switch destination {
                case "Settings":
                    selectedView = .settings
                case "AI Models":
                    selectedView = .models
                case "VoiceInk Pro":
                    selectedView = .license
                case "History":
                    HistoryWindowController.shared.showHistoryWindow(
                        modelContainer: modelContext.container,
                        whisperState: whisperState
                    )
                case "Permissions":
                    selectedView = .permissions
                case "Enhancement":
                    selectedView = .enhancement
                case "Post Processing":
                    selectedView = .postProcessing
                case "Transcribe Audio":
                    selectedView = .transcribeAudio
                case "Power Mode":
                    selectedView = .powerMode
                case "Dashboard":
                    selectedView = .metrics
                case "Dictionary":
                    selectedView = .dictionary
                case "Audio Input":
                    selectedView = .audioInput
                default:
                    break
                }
            }
        }
    }
    
    @ViewBuilder
    private func detailView(for viewType: ViewType) -> some View {
        switch viewType {
        case .metrics:
            MetricsView()
        case .models:
            ModelManagementView(whisperState: whisperState)
        case .enhancement:
            EnhancementSettingsView()
        case .postProcessing:
            PostProcessingSettingsView()
        case .transcribeAudio:
            AudioTranscribeView()
        case .history:
            Text("History")
                .foregroundColor(.secondary)
        case .audioInput:
            AudioInputSettingsView()
        case .dictionary:
            DictionarySettingsView(whisperPrompt: whisperState.whisperPrompt)
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

            Text(viewType.rawValue)
                .font(.system(size: 14, weight: .medium))

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .padding(.vertical, 8)
        .padding(.horizontal, 2)
    }
}

