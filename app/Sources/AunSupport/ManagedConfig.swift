import Foundation

public struct ManagedConfig: Codable, Sendable {
    public var inference = Inference()
    public var privacy = Privacy()
    public var policy = Policy()

    enum CodingKeys: String, CodingKey {
        case inference
        case privacy
        case policy
    }

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        inference = try container.decodeIfPresent(Inference.self, forKey: .inference) ?? Inference()
        privacy = try container.decodeIfPresent(Privacy.self, forKey: .privacy) ?? Privacy()
        policy = try container.decodeIfPresent(Policy.self, forKey: .policy) ?? Policy()
    }

    public struct Inference: Codable, Sendable {
        public var llamaCli = "llama-completion"
        public var modelPath = "models/gemma-4-E4B-it-Q4_K_M.gguf"
        public var promptCache: String? = "models/gemma-4-E4B-it.prompt-cache"
        public var contextSize = 4096
        public var maxTokens = 24
        public var temperature = 0.2
        public var chatTemplate: String?
        public var gpuLayers: Int? = 99

        enum CodingKeys: String, CodingKey {
            case llamaCli = "llama_cli"
            case modelPath = "model_path"
            case promptCache = "prompt_cache"
            case contextSize = "context_size"
            case maxTokens = "max_tokens"
            case temperature
            case chatTemplate = "chat_template"
            case gpuLayers = "gpu_layers"
        }

        public init() {}

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            llamaCli = try container.decodeIfPresent(String.self, forKey: .llamaCli) ?? "llama-completion"
            modelPath = try container.decodeIfPresent(String.self, forKey: .modelPath) ?? "models/gemma-4-E4B-it-Q4_K_M.gguf"
            promptCache = try container.decodeIfPresent(String.self, forKey: .promptCache) ?? "models/gemma-4-E4B-it.prompt-cache"
            contextSize = try container.decodeIfPresent(Int.self, forKey: .contextSize) ?? 4096
            maxTokens = try container.decodeIfPresent(Int.self, forKey: .maxTokens) ?? 24
            temperature = try container.decodeIfPresent(Double.self, forKey: .temperature) ?? 0.2
            chatTemplate = try container.decodeIfPresent(String.self, forKey: .chatTemplate)
            gpuLayers = try container.decodeIfPresent(Int.self, forKey: .gpuLayers) ?? 99
        }
    }

    public struct Privacy: Codable, Sendable {
        public var allowNetworkInference = false
        public var logTypedContent = false

        enum CodingKeys: String, CodingKey {
            case allowNetworkInference = "allow_network_inference"
            case logTypedContent = "log_typed_content"
        }

        public init() {}

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            allowNetworkInference = try container.decodeIfPresent(Bool.self, forKey: .allowNetworkInference) ?? false
            logTypedContent = try container.decodeIfPresent(Bool.self, forKey: .logTypedContent) ?? false
        }
    }

    public struct Policy: Codable, Sendable {
        public var idleDebounceMs = 60
        public var minContextChars = 1
        public var maxTypingSpeedCps = 30

        enum CodingKeys: String, CodingKey {
            case idleDebounceMs = "idle_debounce_ms"
            case minContextChars = "min_context_chars"
            case maxTypingSpeedCps = "max_typing_speed_cps"
        }

        public init() {}

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            idleDebounceMs = try container.decodeIfPresent(Int.self, forKey: .idleDebounceMs) ?? 60
            minContextChars = try container.decodeIfPresent(Int.self, forKey: .minContextChars) ?? 1
            maxTypingSpeedCps = try container.decodeIfPresent(Int.self, forKey: .maxTypingSpeedCps) ?? 30
        }
    }
}

public enum ManagedConfigLoader {
    public static var userConfigURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Aun/managed-config.json")
    }

    public static func save(_ config: ManagedConfig) throws {
        let url = userConfigURL
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: url, options: .atomic)
    }

    public static func load(environment: [String: String] = ProcessInfo.processInfo.environment) -> ManagedConfig {
        if let path = environment["AUN_MANAGED_CONFIG"], !path.isEmpty {
            return load(path: path)
        }

        let supportPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Aun/managed-config.json")
            .path
        if FileManager.default.fileExists(atPath: supportPath) {
            return load(path: supportPath)
        }

        if let bundledPath = Bundle.main.path(forResource: "managed-config.example", ofType: "json") {
            return load(path: bundledPath)
        }

        return ManagedConfig()
    }

    private static func load(path: String) -> ManagedConfig {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: path))
            let config = try JSONDecoder().decode(ManagedConfig.self, from: data)
            return validate(config)
        } catch {
            return ManagedConfig()
        }
    }

    private static func validate(_ config: ManagedConfig) -> ManagedConfig {
        guard !config.privacy.allowNetworkInference else {
            return ManagedConfig()
        }

        guard !config.privacy.logTypedContent else {
            return ManagedConfig()
        }

        guard config.policy.idleDebounceMs >= 0,
              config.policy.minContextChars >= 0,
              config.policy.maxTypingSpeedCps >= 0
        else {
            return ManagedConfig()
        }

        guard !config.inference.llamaCli.isEmpty,
              !config.inference.modelPath.isEmpty,
              config.inference.contextSize > 0,
              config.inference.maxTokens > 0,
              config.inference.temperature >= 0,
              config.inference.temperature <= 2
        else {
            return ManagedConfig()
        }

        return config
    }
}
