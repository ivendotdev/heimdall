import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private let defaultBrowserItem = NSMenuItem()
    private let settings = BrowserSettings()
    private lazy var picker = PickerController(settings: settings)

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        // A stable name lets macOS save the icon's position, which is how menu bar managers
        // like Thaw move it.
        item.autosaveName = "Heimdall"
        let image = NSImage(systemSymbolName: "binoculars", accessibilityDescription: "Heimdall")
        image?.isTemplate = true
        item.button?.image = image

        defaultBrowserItem.title = "Set as Default Browser"
        defaultBrowserItem.action = #selector(setAsDefaultBrowser)
        defaultBrowserItem.target = self

        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(defaultBrowserItem)
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Heimdall", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        item.menu = menu

        statusItem = item
    }

    // Opening the app again (Finder, Spotlight, `open -a Heimdall`) shows Settings, so it's
    // reachable even when the menu bar icon is hidden.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return false
    }

    // Called for clicked links (http/https) and opened .html files.
    func application(_ application: NSApplication, open urls: [URL]) {
        guard !urls.isEmpty else { return }
        picker.show(urls)
    }

    // Checked only when both schemes point here; a dash means http and https disagree.
    func menuNeedsUpdate(_ menu: NSMenu) {
        let isDefault = ["http", "https"].map { scheme in
            let handler = NSWorkspace.shared.urlForApplication(toOpen: URL(string: "\(scheme)://example.com")!)
            return handler?.standardizedFileURL == Bundle.main.bundleURL.standardizedFileURL
        }
        defaultBrowserItem.state = isDefault.allSatisfy { $0 } ? .on : isDefault.contains(true) ? .mixed : .off
    }

    @objc private func openSettings() {
        let window = settingsWindow ?? {
            let window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "Heimdall Settings"
            window.isReleasedWhenClosed = false
            settingsWindow = window
            return window
        }()
        // Rebuilt on every open so newly installed or removed browsers show up.
        window.contentViewController = NSHostingController(
            rootView: SettingsView(settings: settings, installed: Browser.installed())
        )
        window.center()
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    @objc private func setAsDefaultBrowser() {
        Task {
            do {
                // macOS asks the user to confirm the change.
                for scheme in ["http", "https"] {
                    try await NSWorkspace.shared.setDefaultApplication(at: Bundle.main.bundleURL, toOpenURLsWithScheme: scheme)
                }
            } catch {
                NSAlert(error: error).runModal()
            }
        }
    }
}
