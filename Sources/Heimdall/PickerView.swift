import SwiftUI

struct PickerView: View {
    let urls: [URL]
    let browsers: [Browser]
    let onPick: (Browser) -> Void
    let onCopy: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            VStack(alignment: .leading, spacing: 2) {
                Text(urls.first?.absoluteString ?? "")
                    .lineLimit(1)
                    .truncationMode(.middle)
                if urls.count > 1 {
                    Text("+ \(urls.count - 1) more")
                        .foregroundStyle(.tertiary)
                }
            }
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.bottom, 4)

            ForEach(Array(browsers.enumerated()), id: \.element.id) { index, browser in
                Row(shortcut: index < 9 ? "\(index + 1)" : nil, action: { onPick(browser) }) {
                    Image(nsImage: browser.icon)
                        .resizable()
                        .frame(width: 28, height: 28)
                    Text(browser.name)
                }
            }

            if browsers.isEmpty {
                Text("No browsers to show. Check Settings.")
                    .foregroundStyle(.secondary)
                    .padding(8)
            }

            Divider().padding(.vertical, 2)

            Row(shortcut: "⌘C", action: onCopy) {
                Image(systemName: "doc.on.doc")
                    .frame(width: 28, height: 20)
                Text("Copy URL")
            }
        }
        .padding(10)
        .frame(width: 340)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct Row<Label: View>: View {
    let shortcut: String?
    let action: () -> Void
    @ViewBuilder let label: Label
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                label
                Spacer()
                if let shortcut {
                    ShortcutBadge(text: shortcut)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
            .background(isHovered ? Color.accentColor.opacity(0.2) : .clear, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

struct ShortcutBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
    }
}
