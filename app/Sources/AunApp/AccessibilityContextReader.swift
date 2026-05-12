import AppKit
import ApplicationServices

struct FocusedContext: Sendable {
    let appName: String
    let windowTitle: String?
    let beforeCursor: String
    let afterCursor: String
    let selectedText: String?
    let isSecureField: Bool
    let isImeComposing: Bool
    let isFullscreenGame: Bool
    let isRemoteDesktop: Bool
    let typingSpeedCps: Int
    let caretBounds: CGRect
}

final class AccessibilityContextReader {
    private let remoteDesktopBundleIdentifiers: Set<String> = [
        "com.apple.ScreenSharing",
        "com.microsoft.rdc.macos",
        "com.google.ChromeRemoteDesktop",
        "com.realvnc.vncviewer",
        "com.teamviewer.TeamViewer",
        "com.anydesk.AnyDesk",
        "com.parsec.app"
    ]

    func readFocusedContext(typingSpeedCps: Int = 0) -> FocusedContext? {
        guard AXIsProcessTrusted() else {
            return nil
        }

        guard let app = NSWorkspace.shared.frontmostApplication else {
            return nil
        }

        let system = AXUIElementCreateSystemWide()
        var focusedValue: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(
            system,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        )

        guard focusedResult == .success, let focusedElement = focusedValue else {
            return nil
        }

        let focused = focusedElement as! AXUIElement
        let fullText = readStringAttribute(kAXValueAttribute, from: focused) ?? ""
        let selectedRange = readSelectedTextRange(from: focused)
        let cursorContext = split(fullText, around: selectedRange)
        let bundleIdentifier = app.bundleIdentifier ?? ""

        return FocusedContext(
            appName: app.localizedName ?? app.bundleIdentifier ?? "Unknown",
            windowTitle: readStringAttribute(kAXTitleAttribute, from: focused),
            beforeCursor: cursorContext.before,
            afterCursor: cursorContext.after,
            selectedText: readStringAttribute(kAXSelectedTextAttribute, from: focused)
                ?? cursorContext.selected,
            isSecureField: readRole(from: focused) == "AXSecureTextField",
            isImeComposing: hasMarkedText(in: focused),
            isFullscreenGame: isLikelyFullscreenGame(app: app, focused: focused),
            isRemoteDesktop: remoteDesktopBundleIdentifiers.contains(bundleIdentifier),
            typingSpeedCps: typingSpeedCps,
            caretBounds: readCaretBounds(from: focused) ?? .zero
        )
    }

    func insertTextAtFocus(_ text: String) -> Bool {
        guard AXIsProcessTrusted(),
              !text.isEmpty,
              let focused = focusedElement()
        else {
            return false
        }

        let result = AXUIElementSetAttributeValue(
            focused,
            kAXSelectedTextAttribute as CFString,
            text as CFTypeRef
        )
        return result == .success
    }

    private func focusedElement() -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        var focusedValue: CFTypeRef?
        let focusedResult = AXUIElementCopyAttributeValue(
            system,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        )

        guard focusedResult == .success, let focusedValue else {
            return nil
        }

        return (focusedValue as! AXUIElement)
    }

    private func readStringAttribute(_ attribute: String, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success else {
            return nil
        }
        return value as? String
    }

    private func readRole(from element: AXUIElement) -> String? {
        readStringAttribute(kAXRoleAttribute, from: element)
    }

    private func isLikelyFullscreenGame(app: NSRunningApplication, focused: AXUIElement) -> Bool {
        guard app.activationPolicy == .regular else {
            return false
        }

        let role = readRole(from: focused)
        let subrole = readStringAttribute(kAXSubroleAttribute, from: focused)
        let screenFrame = NSScreen.main?.frame ?? .zero
        let focusedFrame = readFrame(from: focused) ?? .zero
        let coversScreen = screenFrame != .zero
            && focusedFrame.width >= screenFrame.width * 0.95
            && focusedFrame.height >= screenFrame.height * 0.95

        return coversScreen
            && role != "AXTextField"
            && role != "AXTextArea"
            && subrole != "AXStandardWindow"
    }

    private func hasMarkedText(in element: AXUIElement) -> Bool {
        if let markedRange = readRangeAttribute("AXTextInputMarkedRange", from: element),
           markedRange.location != kCFNotFound,
           markedRange.length > 0
        {
            return true
        }

        var markerRangeValue: CFTypeRef?
        let markerRangeResult = AXUIElementCopyAttributeValue(
            element,
            "AXTextInputMarkedTextMarkerRange" as CFString,
            &markerRangeValue
        )
        return markerRangeResult == .success && markerRangeValue != nil
    }

    private func readSelectedTextRange(from element: AXUIElement) -> CFRange? {
        readRangeAttribute(kAXSelectedTextRangeAttribute, from: element)
    }

    private func readRangeAttribute(_ attribute: String, from element: AXUIElement) -> CFRange? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element,
            attribute as CFString,
            &value
        )
        guard result == .success, let axValue = value else {
            return nil
        }

        var range = CFRange()
        guard AXValueGetValue(axValue as! AXValue, .cfRange, &range) else {
            return nil
        }
        return range
    }

    private func split(_ text: String, around range: CFRange?) -> (
        before: String,
        selected: String?,
        after: String
    ) {
        guard let range,
              range.location >= 0,
              range.length >= 0,
              let start = index(in: text, utf16Offset: range.location),
              let end = index(in: text, utf16Offset: range.location + range.length)
        else {
            return (text, nil, "")
        }

        let selected = range.length > 0 ? String(text[start..<end]) : nil
        return (String(text[..<start]), selected, String(text[end...]))
    }

    private func index(in text: String, utf16Offset: Int) -> String.Index? {
        guard utf16Offset >= 0, utf16Offset <= text.utf16.count else {
            return nil
        }

        let utf16Index = text.utf16.index(text.utf16.startIndex, offsetBy: utf16Offset)
        return utf16Index.samePosition(in: text)
    }

    private func readCaretBounds(from element: AXUIElement) -> CGRect? {
        var rangeValue: CFTypeRef?
        let rangeResult = AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &rangeValue
        )
        guard rangeResult == .success, let rangeValue else {
            return nil
        }

        var selectedRange = CFRange()
        guard AXValueGetValue(rangeValue as! AXValue, .cfRange, &selectedRange) else {
            return nil
        }

        if selectedRange.length == 0,
           selectedRange.location > 0,
           let previousBounds = readBounds(
               for: CFRange(location: selectedRange.location - 1, length: 1),
               from: element
           )
        {
            let caretFromPreviousCharacter = CGRect(
                x: previousBounds.maxX,
                y: previousBounds.minY,
                width: 1,
                height: previousBounds.height
            )
            return convertAccessibilityBoundsToAppKit(caretFromPreviousCharacter)
        }

        guard let bounds = readBounds(for: selectedRange, from: element) else {
            return nil
        }
        return convertAccessibilityBoundsToAppKit(bounds)
    }

    private func readBounds(for range: CFRange, from element: AXUIElement) -> CGRect? {
        var range = range
        guard let rangeValue = AXValueCreate(.cfRange, &range) else {
            return nil
        }

        var boundsValue: CFTypeRef?
        let boundsResult = AXUIElementCopyParameterizedAttributeValue(
            element,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            rangeValue,
            &boundsValue
        )
        guard boundsResult == .success, let axBounds = boundsValue else {
            return nil
        }

        var bounds = CGRect.zero
        guard AXValueGetValue(axBounds as! AXValue, .cgRect, &bounds) else {
            return nil
        }
        return bounds
    }

    private func convertAccessibilityBoundsToAppKit(_ bounds: CGRect) -> CGRect {
        guard bounds != .zero else {
            return bounds
        }

        let globalMaxY = NSScreen.screens.map(\.frame.maxY).max() ?? bounds.maxY
        let matchingScreen = NSScreen.screens.first { screen in
            let topLeftScreenFrame = CGRect(
                x: screen.frame.minX,
                y: globalMaxY - screen.frame.maxY,
                width: screen.frame.width,
                height: screen.frame.height
            )
            return topLeftScreenFrame.insetBy(dx: -64, dy: -64).intersects(bounds)
        } ?? NSScreen.main

        guard matchingScreen != nil else {
            return bounds
        }

        let convertedY = globalMaxY - bounds.maxY
        return CGRect(
            x: bounds.minX,
            y: convertedY,
            width: bounds.width,
            height: max(bounds.height, 18)
        )
    }

    private func readFrame(from element: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?

        guard AXUIElementCopyAttributeValue(
            element,
            kAXPositionAttribute as CFString,
            &positionValue
        ) == .success,
            AXUIElementCopyAttributeValue(
                element,
                kAXSizeAttribute as CFString,
                &sizeValue
            ) == .success,
            let positionValue,
            let sizeValue
        else {
            return nil
        }

        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &position),
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        else {
            return nil
        }

        return CGRect(origin: position, size: size)
    }
}
