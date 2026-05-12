import AppKit

enum KeyAction {
    case accept
    case dismiss
    case clear
    case manualInvoke
    case typingContinued
}

final class KeyboardMonitor {
    private let handler: @MainActor (KeyAction) -> Void
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let stateLock = NSLock()
    private var suggestionVisible = false

    init(handler: @escaping @MainActor (KeyAction) -> Void) {
        self.handler = handler
    }

    func setSuggestionVisible(_ visible: Bool) {
        stateLock.lock()
        suggestionVisible = visible
        stateLock.unlock()
    }

    func start() {
        guard eventTap == nil else {
            return
        }

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: KeyboardMonitor.eventTapCallback,
            userInfo: refcon
        ) else {
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func handle(_ event: CGEvent) -> Unmanaged<CGEvent>? {
        let action = action(for: event)
        let consume = shouldConsume(action)
        DispatchQueue.main.async { [handler] in
            MainActor.assumeIsolated {
                handler(action)
            }
        }
        return consume ? nil : Unmanaged.passUnretained(event)
    }

    private func shouldConsume(_ action: KeyAction) -> Bool {
        guard action == .accept || action == .dismiss else {
            return false
        }

        stateLock.lock()
        let visible = suggestionVisible
        stateLock.unlock()
        return visible
    }

    private func action(for event: CGEvent) -> KeyAction {
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        switch keyCode {
        case 48:
            return .accept
        case 53:
            return .dismiss
        case 123, 124:
            return .clear
        case 49 where flags.contains(.maskAlternate):
            return .manualInvoke
        default:
            return .typingContinued
        }
    }

    private static let eventTapCallback: CGEventTapCallBack = { _, type, event, refcon in
        guard type == .keyDown, let refcon else {
            return Unmanaged.passUnretained(event)
        }

        let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(refcon).takeUnretainedValue()
        return monitor.handle(event)
    }
}
