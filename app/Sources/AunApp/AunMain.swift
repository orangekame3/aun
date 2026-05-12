import AppKit

@main
final class AunMain {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AunAppDelegate()
        app.delegate = delegate
        if let iconURL = Bundle.main.url(forResource: "AunMark", withExtension: "png"),
           let icon = NSImage(contentsOf: iconURL)
        {
            app.applicationIconImage = icon
        }
        app.setActivationPolicy(.accessory)
        app.run()
    }
}
