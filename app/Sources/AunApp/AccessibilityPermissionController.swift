import ApplicationServices

enum AccessibilityPermissionController {
    static func ensureTrusted(promptIfNeeded: Bool = true) -> Bool {
        if AXIsProcessTrusted() {
            return true
        }

        guard promptIfNeeded else {
            return false
        }

        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
