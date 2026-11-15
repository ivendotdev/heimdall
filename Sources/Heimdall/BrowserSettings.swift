import Foundation
import Observation

/// The user's browser order and hidden browsers, saved in UserDefaults by bundle ID.
@MainActor
@Observable
final class BrowserSettings {
    private enum Key {
        static let order = "browserOrder"
        static let hidden = "hiddenBrowsers"
    }

    var order: [String] {
        didSet { UserDefaults.standard.set(order, forKey: Key.order) }
    }

    var hidden: Set<String> {
        didSet { UserDefaults.standard.set(Array(hidden), forKey: Key.hidden) }
    }

    init() {
        order = UserDefaults.standard.stringArray(forKey: Key.order) ?? []
        hidden = Set(UserDefaults.standard.stringArray(forKey: Key.hidden) ?? [])
    }

    /// All browsers in the user's order. Ones they haven't placed yet (newly installed) keep their
    /// incoming alphabetical order at the end.
    func arranged(_ browsers: [Browser]) -> [Browser] {
        let byID = Dictionary(uniqueKeysWithValues: browsers.map { ($0.id, $0) })
        let placed = order.compactMap { byID[$0] }
        return placed + browsers.filter { !order.contains($0.id) }
    }

    /// What the picker shows: arranged, minus hidden ones.
    func visible(_ browsers: [Browser]) -> [Browser] {
        arranged(browsers).filter { !hidden.contains($0.id) }
    }
}
