import SwiftUI

struct SettingsView: View {
    let settings: BrowserSettings
    let installed: [Browser]
    @State private var browsers: [Browser]

    init(settings: BrowserSettings, installed: [Browser]) {
        self.settings = settings
        self.installed = installed
        _browsers = State(initialValue: settings.arranged(installed))
    }

    /// The 1–9 key each visible browser gets in the picker.
    private var shortcuts: [String: String] {
        let visible = browsers.filter { !settings.hidden.contains($0.id) }.prefix(9)
        return Dictionary(uniqueKeysWithValues: visible.enumerated().map { ($1.id, "\($0 + 1)") })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Drag to reorder. Untick a browser to hide it from the picker.")
                .font(.callout)
                .foregroundStyle(.secondary)

            List {
                ForEach(browsers) { browser in
                    HStack(spacing: 10) {
                        Toggle("Show \(browser.name)", isOn: isShown(browser))
                            .labelsHidden()
                        Image(nsImage: browser.icon)
                            .resizable()
                            .frame(width: 24, height: 24)
                        Text(browser.name)
                        Spacer()
                        if let shortcut = shortcuts[browser.id] {
                            ShortcutBadge(text: shortcut)
                        }
                    }
                    .opacity(settings.hidden.contains(browser.id) ? 0.5 : 1)
                }
                .onMove { source, destination in
                    browsers.move(fromOffsets: source, toOffset: destination)
                    settings.order = browsers.map(\.id)
                }
            }

            HStack {
                Spacer()
                // Order only: hidden browsers stay hidden.
                Button("Reset to Alphabetical") {
                    settings.order = []
                    browsers = installed
                }
            }
        }
        .padding(20)
        .frame(width: 380, height: 440)
    }

    private func isShown(_ browser: Browser) -> Binding<Bool> {
        Binding(
            get: { !settings.hidden.contains(browser.id) },
            set: { isShown in
                if isShown {
                    settings.hidden.remove(browser.id)
                } else {
                    settings.hidden.insert(browser.id)
                }
            }
        )
    }
}
