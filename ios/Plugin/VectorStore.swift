import Foundation

final class VectorCollection: Codable {
    struct Item: Codable { let id: String; var vector: [Float]; var metadata: String }
    struct Hit { let id: String; let score: Float; let metadata: String }

    let lang: String
    let revision: Int
    var items: [Item] = []

    init(lang: String, revision: Int) { self.lang = lang; self.revision = revision }

    func upsert(id: String, vector: [Float], metadata: String) {
        if let i = items.firstIndex(where: { $0.id == id }) {
            items[i].vector = vector; items[i].metadata = metadata
        } else {
            items.append(Item(id: id, vector: vector, metadata: metadata))
        }
    }

    func remove(ids: Set<String>) -> Int {
        let before = items.count
        items.removeAll { ids.contains($0.id) }
        return before - items.count
    }

    func search(_ q: [Float], topK: Int, minScore: Float) -> [Hit] {
        items.compactMap { item -> Hit? in
            var dot: Float = 0
            for i in 0..<min(q.count, item.vector.count) { dot += q[i] * item.vector[i] }
            return dot >= minScore ? Hit(id: item.id, score: dot, metadata: item.metadata) : nil
        }
        .sorted { $0.score > $1.score }
        .prefix(topK)
        .map { $0 }
    }
}

final class VectorStore {
    private var cache: [String: VectorCollection] = [:]

    private var folder: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("semantic-search", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func file(_ name: String) -> URL {
        let safe = name.replacingOccurrences(of: "[^A-Za-z0-9_-]", with: "_",
                                             options: .regularExpression)
        return folder.appendingPathComponent("\(safe).json")
    }

    func existing(_ name: String) -> VectorCollection? {
        if let c = cache[name] { return c }
        guard let data = try? Data(contentsOf: file(name)),
              let c = try? JSONDecoder().decode(VectorCollection.self, from: data) else { return nil }
        cache[name] = c
        return c
    }

    /// Returns the collection, creating it (or replacing it if the language
    /// or model revision changed, since old vectors would no longer compare).
    func collection(_ name: String, lang: String, revision: Int) -> VectorCollection {
        if let c = existing(name), c.lang == lang, c.revision == revision { return c }
        let c = VectorCollection(lang: lang, revision: revision)
        cache[name] = c
        return c
    }

    func save(_ name: String) throws {
        guard let c = cache[name] else { return }
        try JSONEncoder().encode(c).write(to: file(name), options: .atomic)
    }

    func delete(_ name: String) {
        cache[name] = nil
        try? FileManager.default.removeItem(at: file(name))
    }

    static func normalise(_ v: [Double]) -> [Float] {
        let norm = sqrt(v.reduce(0) { $0 + $1 * $1 })
        return norm > 0 ? v.map { Float($0 / norm) } : v.map { Float($0) }
    }
}
