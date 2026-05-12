import AppKit
import AunSupport

/// Native settings window built with Auto Layout.
@MainActor
final class SettingsWindowController: NSWindowController {
    private var config: ManagedConfig
    private let onSave: (ManagedConfig) -> Void

    // Inference controls
    private let modelPathField = NSTextField()
    private let contextSizeStepper = NSStepper()
    private let contextSizeLabel = NSTextField(labelWithString: "")
    private let maxTokensStepper = NSStepper()
    private let maxTokensLabel = NSTextField(labelWithString: "")
    private let temperatureSlider = NSSlider()
    private let temperatureLabel = NSTextField(labelWithString: "")
    private let gpuLayersStepper = NSStepper()
    private let gpuLayersLabel = NSTextField(labelWithString: "")

    // Policy controls
    private let debounceStepper = NSStepper()
    private let debounceLabel = NSTextField(labelWithString: "")
    private let minContextStepper = NSStepper()
    private let minContextLabel = NSTextField(labelWithString: "")
    private let maxSpeedStepper = NSStepper()
    private let maxSpeedLabel = NSTextField(labelWithString: "")

    private let labelWidth: CGFloat = 140

    init(config: ManagedConfig, onSave: @escaping (ManagedConfig) -> Void) {
        self.config = config
        self.onSave = onSave

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 420),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Aun Settings"
        window.center()
        window.isReleasedWhenClosed = false

        super.init(window: window)
        setupUI()
        loadValues()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    // MARK: - UI Construction

    private func setupUI() {
        guard let contentView = window?.contentView else { return }
        contentView.wantsLayer = true

        let tabView = NSTabView()
        tabView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(tabView)

        let inferenceTab = NSTabViewItem(identifier: "inference")
        inferenceTab.label = "Inference"
        inferenceTab.view = buildInferenceTab()
        tabView.addTabViewItem(inferenceTab)

        let policyTab = NSTabViewItem(identifier: "policy")
        policyTab.label = "Policy"
        policyTab.view = buildPolicyTab()
        tabView.addTabViewItem(policyTab)

        let saveButton = NSButton(title: "Save", target: self, action: #selector(saveSettings))
        saveButton.keyEquivalent = "\r"
        saveButton.translatesAutoresizingMaskIntoConstraints = false

        let cancelButton = NSButton(title: "Cancel", target: self, action: #selector(cancelSettings))
        cancelButton.keyEquivalent = "\u{1b}"
        cancelButton.translatesAutoresizingMaskIntoConstraints = false

        let openJSONButton = NSButton(title: "Open JSON…", target: self, action: #selector(openJSON))
        openJSONButton.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(saveButton)
        contentView.addSubview(cancelButton)
        contentView.addSubview(openJSONButton)

        NSLayoutConstraint.activate([
            tabView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            tabView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            tabView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            tabView.bottomAnchor.constraint(equalTo: saveButton.topAnchor, constant: -16),

            saveButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            saveButton.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            saveButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),

            cancelButton.trailingAnchor.constraint(equalTo: saveButton.leadingAnchor, constant: -8),
            cancelButton.bottomAnchor.constraint(equalTo: saveButton.bottomAnchor),
            cancelButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 80),

            openJSONButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            openJSONButton.bottomAnchor.constraint(equalTo: saveButton.bottomAnchor),
        ])
    }

    private func buildInferenceTab() -> NSView {
        let container = NSView()

        configureStepper(contextSizeStepper, min: 512, max: 131072, increment: 512)
        configureStepper(maxTokensStepper, min: 1, max: 1024, increment: 1)
        configureStepper(gpuLayersStepper, min: 0, max: 999, increment: 1)

        temperatureSlider.minValue = 0
        temperatureSlider.maxValue = 2
        temperatureSlider.isContinuous = true
        temperatureSlider.target = self
        temperatureSlider.action = #selector(temperatureChanged)

        contextSizeStepper.target = self
        contextSizeStepper.action = #selector(contextSizeChanged)
        maxTokensStepper.target = self
        maxTokensStepper.action = #selector(maxTokensChanged)
        gpuLayersStepper.target = self
        gpuLayersStepper.action = #selector(gpuLayersChanged)

        var y = container.topAnchor
        y = addTextField(label: "Model Path:", field: modelPathField, below: y, in: container)
        y = addStepperRow(label: "Context Size:", valueLabel: contextSizeLabel, stepper: contextSizeStepper, below: y, in: container)
        y = addStepperRow(label: "Max Tokens:", valueLabel: maxTokensLabel, stepper: maxTokensStepper, below: y, in: container)
        y = addSliderRow(label: "Temperature:", valueLabel: temperatureLabel, slider: temperatureSlider, below: y, in: container)
        _ = addStepperRow(label: "GPU Layers:", valueLabel: gpuLayersLabel, stepper: gpuLayersStepper, below: y, in: container)

        return container
    }

    private func buildPolicyTab() -> NSView {
        let container = NSView()

        configureStepper(debounceStepper, min: 0, max: 2000, increment: 10)
        configureStepper(minContextStepper, min: 0, max: 100, increment: 1)
        configureStepper(maxSpeedStepper, min: 1, max: 100, increment: 1)

        debounceStepper.target = self
        debounceStepper.action = #selector(debounceChanged)
        minContextStepper.target = self
        minContextStepper.action = #selector(minContextChanged)
        maxSpeedStepper.target = self
        maxSpeedStepper.action = #selector(maxSpeedChanged)

        var y = container.topAnchor
        y = addStepperRow(label: "Idle Debounce (ms):", valueLabel: debounceLabel, stepper: debounceStepper, below: y, in: container)
        y = addStepperRow(label: "Min Context Chars:", valueLabel: minContextLabel, stepper: minContextStepper, below: y, in: container)
        _ = addStepperRow(label: "Max Speed (cps):", valueLabel: maxSpeedLabel, stepper: maxSpeedStepper, below: y, in: container)

        return container
    }

    // MARK: - Row Builders

    private func makeLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.alignment = .right
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }

    /// Full-width text field row: [Label] [==== TextField ====]
    private func addTextField(
        label text: String,
        field: NSTextField,
        below anchor: NSLayoutYAxisAnchor,
        in container: NSView
    ) -> NSLayoutYAxisAnchor {
        let label = makeLabel(text)
        field.translatesAutoresizingMaskIntoConstraints = false
        field.lineBreakMode = .byTruncatingTail
        container.addSubview(label)
        container.addSubview(field)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: anchor, constant: 16),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            label.widthAnchor.constraint(equalToConstant: labelWidth),
            label.centerYAnchor.constraint(equalTo: field.centerYAnchor),

            field.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 8),
            field.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            field.topAnchor.constraint(equalTo: anchor, constant: 16),
        ])
        return field.bottomAnchor
    }

    /// Stepper row: [Label] [Value] [▲▼]
    private func addStepperRow(
        label text: String,
        valueLabel: NSTextField,
        stepper: NSStepper,
        below anchor: NSLayoutYAxisAnchor,
        in container: NSView
    ) -> NSLayoutYAxisAnchor {
        let label = makeLabel(text)
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.alignment = .right
        stepper.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        container.addSubview(valueLabel)
        container.addSubview(stepper)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: anchor, constant: 16),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            label.widthAnchor.constraint(equalToConstant: labelWidth),
            label.centerYAnchor.constraint(equalTo: stepper.centerYAnchor),

            valueLabel.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 8),
            valueLabel.widthAnchor.constraint(equalToConstant: 72),
            valueLabel.centerYAnchor.constraint(equalTo: stepper.centerYAnchor),

            stepper.leadingAnchor.constraint(equalTo: valueLabel.trailingAnchor, constant: 4),
            stepper.topAnchor.constraint(equalTo: anchor, constant: 16),
        ])
        return stepper.bottomAnchor
    }

    /// Slider row: [Label] [Value] [====== Slider ======]
    private func addSliderRow(
        label text: String,
        valueLabel: NSTextField,
        slider: NSSlider,
        below anchor: NSLayoutYAxisAnchor,
        in container: NSView
    ) -> NSLayoutYAxisAnchor {
        let label = makeLabel(text)
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.alignment = .right
        slider.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)
        container.addSubview(valueLabel)
        container.addSubview(slider)

        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: anchor, constant: 16),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 16),
            label.widthAnchor.constraint(equalToConstant: labelWidth),
            label.centerYAnchor.constraint(equalTo: slider.centerYAnchor),

            valueLabel.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 8),
            valueLabel.widthAnchor.constraint(equalToConstant: 40),
            valueLabel.centerYAnchor.constraint(equalTo: slider.centerYAnchor),

            slider.leadingAnchor.constraint(equalTo: valueLabel.trailingAnchor, constant: 8),
            slider.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -16),
            slider.topAnchor.constraint(equalTo: anchor, constant: 16),
        ])
        return slider.bottomAnchor
    }

    // MARK: - Helpers

    private func configureStepper(_ stepper: NSStepper, min: Double, max: Double, increment: Double) {
        stepper.minValue = min
        stepper.maxValue = max
        stepper.increment = increment
        stepper.valueWraps = false
    }

    // MARK: - Load / Save

    private func loadValues() {
        modelPathField.stringValue = config.inference.modelPath

        contextSizeStepper.integerValue = config.inference.contextSize
        contextSizeLabel.stringValue = "\(config.inference.contextSize)"

        maxTokensStepper.integerValue = config.inference.maxTokens
        maxTokensLabel.stringValue = "\(config.inference.maxTokens)"

        temperatureSlider.doubleValue = config.inference.temperature
        temperatureLabel.stringValue = String(format: "%.2f", config.inference.temperature)

        gpuLayersStepper.integerValue = config.inference.gpuLayers ?? 99
        gpuLayersLabel.stringValue = "\(config.inference.gpuLayers ?? 99)"

        debounceStepper.integerValue = config.policy.idleDebounceMs
        debounceLabel.stringValue = "\(config.policy.idleDebounceMs)"

        minContextStepper.integerValue = config.policy.minContextChars
        minContextLabel.stringValue = "\(config.policy.minContextChars)"

        maxSpeedStepper.integerValue = config.policy.maxTypingSpeedCps
        maxSpeedLabel.stringValue = "\(config.policy.maxTypingSpeedCps)"
    }

    @objc private func saveSettings() {
        config.inference.modelPath = modelPathField.stringValue
        config.inference.contextSize = contextSizeStepper.integerValue
        config.inference.maxTokens = maxTokensStepper.integerValue
        config.inference.temperature = temperatureSlider.doubleValue
        config.inference.gpuLayers = gpuLayersStepper.integerValue

        config.policy.idleDebounceMs = debounceStepper.integerValue
        config.policy.minContextChars = minContextStepper.integerValue
        config.policy.maxTypingSpeedCps = maxSpeedStepper.integerValue

        do {
            try ManagedConfigLoader.save(config)
            onSave(config)
            window?.close()
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
    }

    @objc private func cancelSettings() {
        window?.close()
    }

    @objc private func openJSON() {
        NSWorkspace.shared.open(ManagedConfigLoader.userConfigURL)
    }

    // MARK: - Stepper / Slider Actions

    @objc private func contextSizeChanged() {
        contextSizeLabel.stringValue = "\(contextSizeStepper.integerValue)"
    }

    @objc private func maxTokensChanged() {
        maxTokensLabel.stringValue = "\(maxTokensStepper.integerValue)"
    }

    @objc private func temperatureChanged() {
        temperatureLabel.stringValue = String(format: "%.2f", temperatureSlider.doubleValue)
    }

    @objc private func gpuLayersChanged() {
        gpuLayersLabel.stringValue = "\(gpuLayersStepper.integerValue)"
    }

    @objc private func debounceChanged() {
        debounceLabel.stringValue = "\(debounceStepper.integerValue)"
    }

    @objc private func minContextChanged() {
        minContextLabel.stringValue = "\(minContextStepper.integerValue)"
    }

    @objc private func maxSpeedChanged() {
        maxSpeedLabel.stringValue = "\(maxSpeedStepper.integerValue)"
    }
}
