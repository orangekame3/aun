import AppKit
import AunSupport

@MainActor
final class AunAppDelegate: NSObject, NSApplicationDelegate {
    private let contextReader = AccessibilityContextReader()
    private let managedConfig = ManagedConfigLoader.load()
    private let overlay = GhostOverlayPanel()
    private var keyboardMonitor: KeyboardMonitor?
    private var pendingInlineSuggestion: DispatchWorkItem?
    private var permissionPollTimer: Timer?
    private var focusedTextPollTimer: Timer?
    private var lastFocusedTextKey: String?
    private var generationTask: Task<Void, Never>?
    private var typingTimestamps: [Date] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        AunTelemetry.appStarted()
        if !AccessibilityPermissionController.ensureTrusted() {
            showStatus("Accessibility permission needed")
            startPermissionPolling()
        }

        keyboardMonitor = KeyboardMonitor { [weak self] action in
            self?.handle(action)
        }
        keyboardMonitor?.start()
        startFocusedTextPolling()
    }

    func applicationWillTerminate(_ notification: Notification) {
        pendingInlineSuggestion?.cancel()
        generationTask?.cancel()
        permissionPollTimer?.invalidate()
        focusedTextPollTimer?.invalidate()
        keyboardMonitor?.stop()
    }

    private func handle(_ action: KeyAction) {
        AunTelemetry.keyAction(action)

        switch action {
        case .manualInvoke:
            pendingInlineSuggestion?.cancel()
            guard let context = contextReader.readFocusedContext(typingSpeedCps: currentTypingSpeedCps()) else {
                AunTelemetry.suggestionSuppressed(reason: "no_context")
                hideSuggestion()
                return
            }
            let suggestion = developmentSuggestion(for: context)
            AunTelemetry.suggestionShown(characterCount: suggestion.count)
            showSuggestion(suggestion, near: context.caretBounds)
        case .accept:
            pendingInlineSuggestion?.cancel()
            let suggestion = overlay.currentSuggestion
            guard !suggestion.isEmpty else {
                return
            }
            AunTelemetry.suggestionAccepted(characterCount: suggestion.count)
            _ = contextReader.insertTextAtFocus(suggestion)
            hideSuggestion()
        case .dismiss, .clear:
            pendingInlineSuggestion?.cancel()
            hideSuggestion()
        case .typingContinued:
            recordTypingEvent()
            scheduleInlineSuggestion()
            hideSuggestion()
        }
    }

    private func scheduleInlineSuggestion() {
        pendingInlineSuggestion?.cancel()
        generationTask?.cancel()

        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                self?.showInlineSuggestionIfNeeded()
            }
        }
        pendingInlineSuggestion = work
        let delayMs = min(managedConfig.policy.idleDebounceMs, 300)
        AunTelemetry.suggestionScheduled(delayMs: delayMs)
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(delayMs), execute: work)
    }

    private func showInlineSuggestionIfNeeded() {
        guard let context = contextReader.readFocusedContext(typingSpeedCps: currentTypingSpeedCps()),
              context.beforeCursor.trimmingCharacters(in: .whitespacesAndNewlines).count >= managedConfig.policy.minContextChars,
              context.typingSpeedCps <= managedConfig.policy.maxTypingSpeedCps,
              !context.isSecureField,
              !context.isImeComposing,
              !context.isFullscreenGame,
              !context.isRemoteDesktop
        else {
            AunTelemetry.suggestionSuppressed(reason: "policy")
            hideSuggestion()
            return
        }

        let fallback = developmentSuggestion(for: context)
        if !fallback.isEmpty {
            AunTelemetry.suggestionShown(characterCount: fallback.count)
            showSuggestion(fallback, near: context.caretBounds)
        }

        generationTask?.cancel()
        generationTask = Task { [weak self] in
            guard let self else {
                return
            }

            let generated = await LocalLLMCompletion.generate(for: context, config: self.managedConfig)
            if Task.isCancelled {
                return
            }

            await MainActor.run {
                guard let suggestion = generated, !suggestion.isEmpty else {
                    if fallback.isEmpty {
                        AunTelemetry.suggestionSuppressed(reason: "empty_suggestion")
                    }
                    return
                }

                AunTelemetry.suggestionShown(characterCount: suggestion.count)
                self.showSuggestion(suggestion, near: context.caretBounds)
            }
        }
    }

    private func developmentSuggestion(for context: FocusedContext) -> String {
        guard !context.isSecureField,
              !context.isImeComposing,
              !context.isFullscreenGame,
              !context.isRemoteDesktop
        else {
            return ""
        }

        let before = context.beforeCursor.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !before.isEmpty else {
            return ""
        }

        if before.hasSuffix("それなら") {
            return "まずは小さいモデルから試すと良いです"
        }

        if before.hasSuffix("まず") {
            return "は小さく動かして確認します"
        }

        if before.hasSuffix("今日は") {
            return "動作確認から進めます"
        }

        if before.hasSuffix("です") || before.hasSuffix("ます") {
            return "。"
        }

        if before.range(of: #"[A-Za-z0-9]$"#, options: .regularExpression) != nil {
            return " "
        }

        return "、"
    }

    private func recordTypingEvent(now: Date = Date()) {
        typingTimestamps.append(now)
        typingTimestamps = typingTimestamps.filter { now.timeIntervalSince($0) <= 1.0 }
    }

    private func currentTypingSpeedCps(now: Date = Date()) -> Int {
        typingTimestamps = typingTimestamps.filter { now.timeIntervalSince($0) <= 1.0 }
        return typingTimestamps.count
    }

    private func startPermissionPolling() {
        permissionPollTimer?.invalidate()
        permissionPollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }

                if AccessibilityPermissionController.ensureTrusted(promptIfNeeded: false) {
                    self.permissionPollTimer?.invalidate()
                    self.permissionPollTimer = nil
                    self.hideSuggestion()
                } else {
                    self.showStatus("Accessibility permission needed")
                }
            }
        }
    }

    private func startFocusedTextPolling() {
        focusedTextPollTimer?.invalidate()
        focusedTextPollTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.observeFocusedTextChange()
            }
        }
    }

    private func observeFocusedTextChange() {
        guard let context = contextReader.readFocusedContext(typingSpeedCps: currentTypingSpeedCps()) else {
            return
        }

        let textKey = [
            context.appName,
            context.windowTitle ?? "",
            context.beforeCursor,
            context.afterCursor,
            context.selectedText ?? ""
        ].joined(separator: "\u{1f}")

        guard textKey != lastFocusedTextKey else {
            return
        }

        lastFocusedTextKey = textKey

        guard !context.beforeCursor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        recordTypingEvent()
        scheduleInlineSuggestion()
        hideSuggestion()
    }

    private func showStatus(_ text: String) {
        let mouse = NSEvent.mouseLocation
        let bounds = CGRect(x: mouse.x, y: mouse.y, width: 1, height: 18)
        overlay.showSuggestion(text, near: bounds)
        keyboardMonitor?.setSuggestionVisible(false)
    }

    private func showSuggestion(_ text: String, near caretBounds: CGRect) {
        overlay.showSuggestion(text, near: caretBounds)
        keyboardMonitor?.setSuggestionVisible(!text.isEmpty)
    }

    private func hideSuggestion() {
        overlay.hideSuggestion()
        keyboardMonitor?.setSuggestionVisible(false)
    }
}
