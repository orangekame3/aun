import AppKit

/// Manages the NSStatusItem that lives in the macOS menu bar.
@MainActor
final class StatusBarController {
    private var statusItem: NSStatusItem?
    private var enabledMenuItem: NSMenuItem?
    private var onToggleEnabled: ((Bool) -> Void)?

    private(set) var isSuggestionEnabled = true

    func setup(onToggleEnabled: @escaping (Bool) -> Void) {
        self.onToggleEnabled = onToggleEnabled

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.statusItem = statusItem

        if let button = statusItem.button {
            if let iconURL = Bundle.main.url(forResource: "AunMark", withExtension: "png"),
               let icon = NSImage(contentsOf: iconURL)
            {
                icon.size = NSSize(width: 18, height: 18)
                icon.isTemplate = true
                button.image = icon
            } else {
                button.title = "A"
            }
            button.toolTip = "Aun – inline suggestion"
        }

        statusItem.menu = buildMenu()
    }

    func updateEnabledState(_ enabled: Bool) {
        isSuggestionEnabled = enabled
        enabledMenuItem?.title = enabled ? "Disable Suggestions" : "Enable Suggestions"
        enabledMenuItem?.state = enabled ? .on : .off

        if let button = statusItem?.button {
            button.appearsDisabled = !enabled
        }
    }

    // MARK: - Menu

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let enabledItem = NSMenuItem(
            title: "Disable Suggestions",
            action: #selector(toggleEnabled),
            keyEquivalent: ""
        )
        enabledItem.target = self
        enabledItem.state = .on
        self.enabledMenuItem = enabledItem
        menu.addItem(enabledItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(
            title: "Open Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let aboutItem = NSMenuItem(
            title: "About Aun",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Aun",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    // MARK: - Actions

    @objc private func toggleEnabled() {
        let newState = !isSuggestionEnabled
        updateEnabledState(newState)
        onToggleEnabled?(newState)
    }

    @objc private func openSettings() {
        let supportDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Aun")
        let configPath = supportDir.appendingPathComponent("managed-config.json")

        // Create default config if it doesn't exist
        if !FileManager.default.fileExists(atPath: configPath.path) {
            try? FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
            if let examplePath = Bundle.main.path(forResource: "managed-config.example", ofType: "json"),
               let exampleData = FileManager.default.contents(atPath: examplePath)
            {
                FileManager.default.createFile(atPath: configPath.path, contents: exampleData)
            } else {
                // Write minimal default config
                let defaultJSON = """
                {
                  "inference": {},
                  "privacy": {},
                  "policy": {}
                }
                """
                FileManager.default.createFile(
                    atPath: configPath.path,
                    contents: defaultJSON.data(using: .utf8)
                )
            }
        }

        NSWorkspace.shared.open(configPath)
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Aun"
        alert.informativeText = "Aun – Local inline suggestion engine\nVersion 0.1.0"
        alert.alertStyle = .informational
        if let iconURL = Bundle.main.url(forResource: "AunMark", withExtension: "png"),
           let icon = NSImage(contentsOf: iconURL)
        {
            alert.icon = icon
        }
        alert.runModal()
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
