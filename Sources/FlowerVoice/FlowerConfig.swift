import Foundation

/// User settings, stored as JSON in ~/.config/flowervoice/config.json.
struct FlowerConfig: Codable {
    var codexModel = "gpt-5.6-luna"
    var reasoningEffort = "low"
    var language: String? = "it"
    /// Microphone name as shown in System Settings → Sound; nil = system default input.
    var inputDevice: String?
    var isCleanupEnabled = true
    var dictionary: [String] = []
    var extraInstructions = ""
}

extension FlowerConfig {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = FlowerConfig()
        codexModel = try container.decodeIfPresent(String.self, forKey: .codexModel) ?? defaults.codexModel
        reasoningEffort = try container.decodeIfPresent(String.self, forKey: .reasoningEffort) ?? defaults.reasoningEffort
        language = try container.decodeIfPresent(String.self, forKey: .language) ?? defaults.language
        inputDevice = try container.decodeIfPresent(String.self, forKey: .inputDevice) ?? defaults.inputDevice
        isCleanupEnabled = try container.decodeIfPresent(Bool.self, forKey: .isCleanupEnabled) ?? defaults.isCleanupEnabled
        dictionary = try container.decodeIfPresent([String].self, forKey: .dictionary) ?? defaults.dictionary
        extraInstructions = try container.decodeIfPresent(String.self, forKey: .extraInstructions) ?? defaults.extraInstructions
    }
}

enum FlowerPaths {
    static let configDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: ".config/flowervoice", directoryHint: .isDirectory)
    static let configFile = configDirectory.appending(path: "config.json")
    static let historyFile = configDirectory.appending(path: "history.jsonl")
    static let modelsDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: "Library/Application Support/FlowerVoice", directoryHint: .isDirectory)
}

enum ConfigStore {
    static func load() -> FlowerConfig {
        guard let data = try? Data(contentsOf: FlowerPaths.configFile) else {
            let defaults = FlowerConfig()
            save(defaults)
            return defaults
        }
        return (try? JSONDecoder().decode(FlowerConfig.self, from: data)) ?? FlowerConfig()
    }

    static func save(_ config: FlowerConfig) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(config) else { return }
        try? FileManager.default.createDirectory(at: FlowerPaths.configDirectory, withIntermediateDirectories: true)
        try? data.write(to: FlowerPaths.configFile, options: .atomic)
    }
}
