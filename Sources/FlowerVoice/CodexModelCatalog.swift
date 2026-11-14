import Foundation

struct CodexModelInfo: Hashable {
    let slug: String
    let reasoningEfforts: [String]
}

/// Models available to the user's Codex subscription, from the cache the Codex CLI keeps up to date.
enum CodexModelCatalog {
    private static let CACHE_FILE = FileManager.default.homeDirectoryForCurrentUser
        .appending(path: ".codex/models_cache.json")
    private static let FALLBACK_EFFORTS = ["low", "medium", "high"]

    static func load() -> [CodexModelInfo] {
        guard let data = try? Data(contentsOf: CACHE_FILE),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = json["models"] as? [[String: Any]] else { return [] }
        return models.compactMap(parseModel)
    }

    static func efforts(for slug: String, in models: [CodexModelInfo]) -> [String] {
        models.first { $0.slug == slug }?.reasoningEfforts ?? FALLBACK_EFFORTS
    }

    private static func parseModel(_ model: [String: Any]) -> CodexModelInfo? {
        guard let slug = model["slug"] as? String else { return nil }
        let levels = model["supported_reasoning_levels"] as? [[String: Any]] ?? []
        let efforts = levels.compactMap { $0["effort"] as? String }
        return CodexModelInfo(slug: slug, reasoningEfforts: efforts.isEmpty ? FALLBACK_EFFORTS : efforts)
    }
}
