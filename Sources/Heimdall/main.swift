import AppKit

// Plain AppKit entry point: a menu-bar-only app needs no SwiftUI App scene,
// and this guarantees AppDelegate receives application(_:open:).
let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.run()
