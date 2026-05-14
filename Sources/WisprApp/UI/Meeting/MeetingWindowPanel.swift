//
//  MeetingWindowPanel.swift
//  wispr
//
//  Floating NSPanel that hosts the MeetingTranscriptView.
//  Similar to RecordingOverlayPanel but larger and resizable.
//

import AppKit
import SwiftUI

/// A floating `NSPanel` that hosts the meeting transcription UI.
///
/// Unlike the compact RecordingOverlayPanel, this is a resizable window
/// with title bar, close button, and full transcript view.
@MainActor
final class MeetingWindowPanel: NSObject, NSWindowDelegate {

    // MARK: - Properties

    private var panel: NSPanel?
    private let meetingStateManager: MeetingStateManager
    private let settingsStore: SettingsStore
    private let themeEngine: UIThemeEngine

    /// Whether the panel is currently visible.
    private(set) var isVisible = false

    // MARK: - Initialization

    init(
        meetingStateManager: MeetingStateManager,
        settingsStore: SettingsStore,
        themeEngine: UIThemeEngine
    ) {
        self.meetingStateManager = meetingStateManager
        self.settingsStore = settingsStore
        self.themeEngine = themeEngine
    }

    // MARK: - Panel Lifecycle

    /// Shows the meeting window.
    func show() {
        if panel == nil {
            createPanel()
        }

        guard let panel, !isVisible else { return }

        positionPanel(panel)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        isVisible = true
    }

    /// Dismisses the meeting window.
    func dismiss() {
        guard let panel, isVisible else { return }
        panel.orderOut(nil)
        isVisible = false
    }

    // MARK: - Private Helpers

    private func createPanel() {
        let transcriptView = MeetingTranscriptView()
            .environment(meetingStateManager)
            .environment(settingsStore)
            .environment(themeEngine)

        let hostingView = NSHostingView(rootView: transcriptView)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 520),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel, .utilityWindow],
            backing: .buffered,
            defer: false
        )

        panel.title = "Meeting Transcription"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.isOpaque = true
        panel.hasShadow = true
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = hostingView
        panel.minSize = NSSize(width: 320, height: 300)
        panel.isReleasedWhenClosed = false
        panel.delegate = self

        self.panel = panel
    }

    // MARK: - NSWindowDelegate

    /// Called when the user closes the window via the red X button.
    /// Syncs both the panel's flag and the state manager's observable property
    /// so the observation loop can re-trigger on the next menu click.
    func windowWillClose(_ notification: Notification) {
        isVisible = false
        meetingStateManager.isWindowVisible = false
    }

    // MARK: - Positioning

    private func positionPanel(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let panelSize = panel.frame.size

        // Position in the bottom-right corner with some padding
        let x = screenFrame.maxX - panelSize.width - 20
        let y = screenFrame.minY + 20
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
