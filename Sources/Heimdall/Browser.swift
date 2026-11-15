import AppKit

struct Browser: Identifiable {
    let id: String
    let name: String
    let url: URL
    let icon: NSImage

    /// Every installed app that can open https links, minus Heimdall itself, one entry per bundle ID.
    @MainActor
    static func installed() -> [Browser] {
        // Asking "who opens https?" is how we define "a browser", whatever URL actually arrived.
        // Asking per-URL would pull in every HTML editor for file:// opens.
        let probe = URL(string: "https://example.com")!
        let ownID = Bundle.main.bundleIdentifier
        var seen = Set<String>()

        return NSWorkspace.shared.urlsForApplications(toOpen: probe)
            .compactMap { appURL -> Browser? in
                // Skip engines other apps bundle for themselves (e.g. a private Chromium in
                // ~/Library/Application Support); real installs live in Applications folders.
                guard !appURL.pathComponents.contains("Library"),
                      let bundleID = Bundle(url: appURL)?.bundleIdentifier,
                      bundleID != ownID,
                      seen.insert(bundleID).inserted
                else { return nil }

                let name = FileManager.default.displayName(atPath: appURL.path)
                return Browser(
                    id: bundleID,
                    name: name.hasSuffix(".app") ? String(name.dropLast(4)) : name,
                    url: appURL,
                    icon: NSWorkspace.shared.icon(forFile: appURL.path)
                )
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
