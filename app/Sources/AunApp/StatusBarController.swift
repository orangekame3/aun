import AppKit
import AunSupport

/// Manages the NSStatusItem that lives in the macOS menu bar.
@MainActor
final class StatusBarController {
    private var statusItem: NSStatusItem?
    private var enabledMenuItem: NSMenuItem?
    private var onToggleEnabled: ((Bool) -> Void)?
    private var settingsController: SettingsWindowController?
    private var currentConfig: ManagedConfig = ManagedConfig()
    private var onConfigChanged: ((ManagedConfig) -> Void)?

    private(set) var isSuggestionEnabled = true

    func setup(
        config: ManagedConfig,
        onToggleEnabled: @escaping (Bool) -> Void,
        onConfigChanged: @escaping (ManagedConfig) -> Void
    ) {
        self.currentConfig = config
        self.onConfigChanged = onConfigChanged
        self.onToggleEnabled = onToggleEnabled

        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.statusItem = statusItem

        if let button = statusItem.button {
            if let icon = loadStatusBarIcon() {
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

    private func loadStatusBarIcon() -> NSImage? {
        // Prefer dedicated status bar icon, fall back to app mark
        for name in ["StatusBarIcon", "AunMark"] {
            if let url = Bundle.main.url(forResource: name, withExtension: "png"),
               let image = NSImage(contentsOf: url)
            {
                return image
            }
        }
        return nil
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
        if let existing = settingsController?.window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let controller = SettingsWindowController(config: currentConfig) { [weak self] newConfig in
            self?.currentConfig = newConfig
            self?.onConfigChanged?(newConfig)
        }
        settingsController = controller
        controller.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Aun"
        alert.informativeText = "Aun – Local inline suggestion engine\nVersion 0.1.0-alpha\n\n⚠ Experimental – expect rough edges"
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
