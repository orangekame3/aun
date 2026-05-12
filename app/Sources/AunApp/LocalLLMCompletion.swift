import Foundation
import AunSupport

enum LocalLLMCompletion {
    static func isConfigured(_ config: ManagedConfig) -> Bool {
        FileManager.default.isExecutableFile(atPath: config.inference.llamaCli)
            && FileManager.default.fileExists(atPath: config.inference.modelPath)
    }

    static func generate(for context: FocusedContext, config: ManagedConfig) async -> String? {
        guard isConfigured(config) else {
            return nil
        }

        let prompt = buildPrompt(for: context)

        return await Task.detached(priority: .userInitiated) {
            let process = Process()
            let stdout = Pipe()

            process.executableURL = URL(fileURLWithPath: config.inference.llamaCli)
            process.arguments = arguments(prompt: prompt, config: config)
            process.standardOutput = stdout
            process.standardError = FileHandle.nullDevice

            do {
                try process.run()
            } catch {
                return nil
            }

            let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                return nil
            }

            let output = String(data: outputData, encoding: .utf8) ?? ""
            return clean(output)
        }.value
    }

    private static func arguments(prompt: String, config: ManagedConfig) -> [String] {
        var args = [
            "-m", config.inference.modelPath,
            "-p", prompt,
            "--ctx-size", String(config.inference.contextSize),
            "--n-predict", String(config.inference.maxTokens),
            "--temp", String(format: "%.3f", config.inference.temperature),
            "--no-display-prompt",
            "--no-warmup",
            "-no-cnv"
        ]

        if let gpuLayers = config.inference.gpuLayers {
            args += ["-ngl", String(gpuLayers)]
        }

        if let promptCache = config.inference.promptCache, !promptCache.isEmpty {
            args += ["--prompt-cache", promptCache]
        }

        return args
    }

    private static func buildPrompt(for context: FocusedContext) -> String {
        let before = String(context.beforeCursor.suffix(2_000))
        let after = String(context.afterCursor.prefix(500))

        return """
        You are Aun, a local inline completion engine.
        Return only the next short natural text continuation.
        Do not explain. Do not quote the existing text.
        <before_cursor>
        \(before)
        </before_cursor>
        <after_cursor>
        \(after)
        </after_cursor>
        <completion>
        """
    }

    private static func clean(_ output: String) -> String? {
        let droppedPrefixes = [
            "build",
            "model",
            "modalities",
            "available commands",
            "/exit",
            "/regen",
            "/clear",
            "/read",
            "/glob",
            "common_memory_breakdown_print",
            "ggml_",
            "[ Prompt:",
            "Exiting"
        ]

        var trimmedOutput = output
        if let range = trimmedOutput.range(of: "common_perf_print:") {
            trimmedOutput = String(trimmedOutput[..<range.lowerBound])
        }
        if let range = trimmedOutput.range(of: "common_memory_breakdown_print:") {
            trimmedOutput = String(trimmedOutput[..<range.lowerBound])
        }

        let lines = trimmedOutput
            .replacingOccurrences(of: "<completion>", with: "")
            .replacingOccurrences(of: "</completion>", with: "")
            .replacingOccurrences(of: "[end of text]", with: "")
            .replacingOccurrences(of: "<end_of_turn>", with: "")
            .replacingOccurrences(of: "<eos>", with: "")
            .replacingOccurrences(of: "**例：**", with: "")
            .replacingOccurrences(of: "[Start thinking]", with: "")
            .replacingOccurrences(of: "Thinking Process:", with: "")
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { !$0.hasPrefix(">") }
            .filter { line in
                !droppedPrefixes.contains { line.hasPrefix($0) }
            }
            .filter { line in
                !line.contains("▄▄")
                    && !line.contains("██")
                    && !line.contains("▀▀")
            }

        guard !lines.isEmpty else {
            return nil
        }

        var text = lines.joined(separator: " ")
        text = String(text.prefix(80))
        return text.isEmpty ? nil : text
    }
}
