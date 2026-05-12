import AppKit

@main
final class AunMain {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AunAppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

