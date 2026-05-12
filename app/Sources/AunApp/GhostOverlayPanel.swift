import AppKit

final class GhostOverlayPanel: NSPanel {
    private let label = NSTextField(labelWithString: "")
    private(set) var currentSuggestion = ""

    init() {
        super.init(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: true
        )

        isFloatingPanel = true
        hidesOnDeactivate = false
        level = .popUpMenu
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        ignoresMouseEvents = true

        label.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        label.textColor = NSColor.systemGray.withAlphaComponent(0.82)
        label.backgroundColor = .clear
        label.isBezeled = false
        label.isEditable = false
        label.isSelectable = false
        contentView = label
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    func showSuggestion(_ text: String, near caretBounds: CGRect) {
        let signpost = AunTelemetry.overlayShowStarted()
        currentSuggestion = text
        label.stringValue = text
        label.sizeToFit()

        let size = label.fittingSize
        let origin = CGPoint(
            x: caretBounds.maxX + 1,
            y: caretBounds.midY - (size.height / 2)
        )
        setFrame(CGRect(origin: origin, size: size), display: true)
        alphaValue = 1
        orderFrontRegardless()

        AunTelemetry.overlayShowEnded(signpost)
    }

    func hideSuggestion() {
        let signpost = AunTelemetry.overlayHideStarted()
        currentSuggestion = ""
        label.stringValue = ""
        alphaValue = 0
        orderOut(nil)
        AunTelemetry.overlayHideEnded(signpost)
    }
}
