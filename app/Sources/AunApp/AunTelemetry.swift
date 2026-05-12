import Foundation
import OSLog

enum AunTelemetry {
    private static let logger = Logger(subsystem: "dev.aun.Aun", category: "runtime")
    private static let signposter = OSSignposter(subsystem: "dev.aun.Aun", category: "performance")

    static func appStarted() {
        logger.info("app_started")
    }

    static func keyAction(_ action: KeyAction) {
        logger.debug("key_action=\(String(describing: action), privacy: .public)")
    }

    static func keyboardMonitorStarted() {
        logger.info("keyboard_monitor_started")
    }

    static func keyboardMonitorFailed() {
        logger.warning("keyboard_monitor_failed")
    }

    static func suggestionScheduled(delayMs: Int) {
        logger.debug("suggestion_scheduled delay_ms=\(delayMs, privacy: .public)")
    }

    static func suggestionSuppressed(reason: String) {
        logger.debug("suggestion_suppressed reason=\(reason, privacy: .public)")
    }

    static func suggestionShown(characterCount: Int) {
        logger.debug("suggestion_shown chars=\(characterCount, privacy: .public)")
    }

    static func suggestionAccepted(characterCount: Int) {
        logger.info("suggestion_accepted chars=\(characterCount, privacy: .public)")
    }

    static func suggestionInsertionFailed() {
        logger.warning("suggestion_insertion_failed")
    }

    static func configRejected(reason: String) {
        logger.warning("managed_config_rejected reason=\(reason, privacy: .public)")
    }

    static func overlayShowStarted() -> OSSignpostIntervalState {
        signposter.beginInterval("overlay_show")
    }

    static func overlayShowEnded(_ state: OSSignpostIntervalState) {
        signposter.endInterval("overlay_show", state)
    }

    static func overlayHideStarted() -> OSSignpostIntervalState {
        signposter.beginInterval("overlay_hide")
    }

    static func overlayHideEnded(_ state: OSSignpostIntervalState) {
        signposter.endInterval("overlay_hide", state)
    }
}
