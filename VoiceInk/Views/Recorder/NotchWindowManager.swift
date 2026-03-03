import SwiftUI
import AppKit

@MainActor
class NotchWindowManager: ObservableObject {
    @Published var isVisible = false
    private var windowController: NSWindowController?
     var notchPanel: NotchRecorderPanel?
    private let whisperState: WhisperState
    private let recorder: Recorder

    init(whisperState: WhisperState, recorder: Recorder) {
        self.whisperState = whisperState
        self.recorder = recorder
    }
    
    func show(on screen: NSScreen? = nil) {
        if isVisible { return }

        if notchPanel == nil {
            initializeWindow(on: screen)
        }
        self.isVisible = true
        notchPanel?.show(on: screen)
    }

    func hide() {
        guard isVisible else { return }

        self.isVisible = false
        notchPanel?.orderOut(nil)
    }

    private func initializeWindow(on screen: NSScreen? = nil) {
        let metrics = NotchRecorderPanel.calculateWindowMetrics(for: screen)
        let panel = NotchRecorderPanel(contentRect: metrics.frame)

        guard let enhancementService = whisperState.enhancementService else { return }

        let notchRecorderView = NotchRecorderView(whisperState: whisperState, recorder: recorder)
            .environmentObject(self)
            .environmentObject(enhancementService)

        let hostingController = NotchRecorderHostingController(rootView: notchRecorderView)
        panel.contentView = hostingController.view

        self.notchPanel = panel
        self.windowController = NSWindowController(window: panel)
    }

    private func deinitializeWindow() {
        notchPanel?.orderOut(nil)
        windowController?.close()
        windowController = nil
        notchPanel = nil
    }
    
    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }
} 
