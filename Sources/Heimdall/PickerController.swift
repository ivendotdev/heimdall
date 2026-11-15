import AppKit
import SwiftUI

/// Borderless panels refuse key status by default; we need it for keyboard shortcuts.
private final class PickerPanel: NSPanel {
    init(size: NSSize) {
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { true }
}

@MainActor
final class PickerController: NSObject, NSWindowDelegate {
    private let settings: BrowserSettings
    private var panel: PickerPanel?
    private var keyMonitor: Any?
    private var urls: [URL] = []
    private var browsers: [Browser] = []

    init(settings: BrowserSettings) {
        self.settings = settings
    }

    func show(_ urls: [URL]) {
        dismiss()
        self.urls = urls
        browsers = settings.visible(Browser.installed())

        let view = PickerView(
            urls: urls,
            browsers: browsers,
            onPick: { [weak self] in self?.open(in: $0) },
            onCopy: { [weak self] in self?.copyURLs() }
        )
        let hostingView = NSHostingView(rootView: view)
        let panel = PickerPanel(size: hostingView.fittingSize)
        panel.contentView = hostingView
        panel.delegate = self
        center(panel)

        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let handled = MainActor.assumeIsolated { self?.handleKey(event) ?? false }
            return handled ? nil : event
        }
    }

    func dismiss() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
        panel?.delegate = nil
        panel?.orderOut(nil)
        panel = nil
    }

    // Clicking anywhere outside the panel dismisses it.
    func windowDidResignKey(_ notification: Notification) {
        dismiss()
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection([.command, .option, .control, .shift])
        let key = event.charactersIgnoringModifiers ?? ""

        if event.keyCode == 53 { // Esc
            dismiss()
            return true
        }
        if modifiers == .command, key == "c" {
            copyURLs()
            return true
        }
        if modifiers.isEmpty, let number = Int(key), (1...9).contains(number), number <= browsers.count {
            open(in: browsers[number - 1])
            return true
        }
        return false
    }

    private func open(in browser: Browser) {
        let urls = self.urls
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        dismiss()

        Task {
            do {
                _ = try await NSWorkspace.shared.open(urls, withApplicationAt: browser.url, configuration: configuration)
            } catch {
                // Don't lose the link: report the failure and bring the picker back.
                NSApp.activate()
                NSAlert(error: error).runModal()
                show(urls)
            }
        }
    }

    private func copyURLs() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(urls.map(\.absoluteString).joined(separator: "\n"), forType: .string)
        dismiss()
    }

    /// Centers on whichever screen the cursor is on.
    private func center(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main
        else { return }
        let visible = screen.visibleFrame
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2))
    }
}
