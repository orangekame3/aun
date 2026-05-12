import Foundation
import AunSupport

func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fputs("managed config check failed: \(message)\n", stderr)
        exit(1)
    }
}

func writeConfig(_ contents: String) throws -> String {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("json")
    try contents.data(using: .utf8)?.write(to: url)
    return url.path
}

let defaults = ManagedConfigLoader.load(
    environment: ["AUN_MANAGED_CONFIG": "/nonexistent/aun-managed-config.json"]
)
expect(defaults.inference.llamaCli.isEmpty == false, "default llama cli")
expect(defaults.inference.modelPath.hasSuffix(".gguf"), "default model path")
expect(defaults.privacy.allowNetworkInference == false, "default network inference must be false")
expect(defaults.privacy.logTypedContent == false, "default typed-content logging must be false")
expect(defaults.policy.idleDebounceMs == 120, "default debounce")
expect(defaults.policy.minContextChars == 1, "default min context")
expect(defaults.policy.maxTypingSpeedCps == 8, "default typing speed")

let partialPath = try writeConfig("""
{
  "policy": {
    "idle_debounce_ms": 250
  }
}
""")
let partial = ManagedConfigLoader.load(environment: ["AUN_MANAGED_CONFIG": partialPath])
expect(partial.policy.idleDebounceMs == 250, "partial debounce override")
expect(partial.policy.minContextChars == 1, "partial config keeps min context default")
expect(partial.privacy.allowNetworkInference == false, "partial config keeps privacy default")

let rejectedPath = try writeConfig("""
{
  "privacy": {
    "allow_network_inference": true
  },
  "policy": {
    "idle_debounce_ms": 250
  }
}
""")
let rejected = ManagedConfigLoader.load(environment: ["AUN_MANAGED_CONFIG": rejectedPath])
expect(rejected.privacy.allowNetworkInference == false, "network inference config rejected")
expect(rejected.policy.idleDebounceMs == 120, "rejected config falls back to default")

print("managed config check passed")
