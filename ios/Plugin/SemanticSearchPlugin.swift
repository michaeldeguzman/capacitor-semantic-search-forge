import Foundation
import Capacitor

@objc(SemanticSearchPlugin)
public class SemanticSearchPlugin: CAPPlugin {
    private let store = VectorStore()
    private let queue = DispatchQueue(label: "semantic-search")

    /// Returns the embedder for a language, or nil if unsupported.
    /// v1 supports "en" only. See MiniLMEmbedder.
    private func model(_ lang: String) -> Embedder? {
        lang.lowercased().hasPrefix("en") ? MiniLMEmbedder.shared : nil
    }

    @objc func isAvailable(_ call: CAPPluginCall) {
        let m = model(call.getString("lang") ?? "en")
        call.resolve([
            "available": m != nil,
            "dimension": m?.dimension ?? 0,
            "revision": m?.revision ?? 0
        ])
    }

    @objc func upsertMany(_ call: CAPPluginCall) {
        guard let name = call.getString("collection"), !name.isEmpty else {
            return call.reject("collection is required")
        }
        let lang = call.getString("lang") ?? "en"
        guard let m = model(lang) else {
            return call.reject("Sentence embedding not available for language '\(lang)'")
        }
        let items = call.getArray("items", JSObject.self) ?? []

        queue.async {
            var skipped: [String] = []
            var count = 0
            let col = self.store.collection(name, lang: lang, revision: m.revision)
            for item in items {
                guard let id = item["id"] as? String,
                      let text = item["text"] as? String,
                      let raw = m.vector(for: text) else {
                    if let id = item["id"] as? String { skipped.append(id) }
                    continue
                }
                col.upsert(id: id, vector: VectorStore.normalise(raw),
                           metadata: item["metadata"] as? String ?? "")
                count += 1
            }
            do {
                try self.store.save(name)
                call.resolve(["count": count, "skipped": skipped])
            } catch {
                call.reject("Failed to save collection: \(error.localizedDescription)")
            }
        }
    }

    @objc func search(_ call: CAPPluginCall) {
        guard let name = call.getString("collection"),
              let query = call.getString("query"), !query.isEmpty else {
            return call.reject("collection and query are required")
        }
        let topK = call.getInt("topK") ?? 5
        let minScore = Float(call.getDouble("minScore") ?? 0)

        queue.async {
            guard let col = self.store.existing(name) else {
                return call.reject("Collection '\(name)' not found")
            }
            guard let m = self.model(col.lang), let raw = m.vector(for: query) else {
                return call.resolve(["results": []])
            }
            let q = VectorStore.normalise(raw)
            let results = col.search(q, topK: topK, minScore: minScore).map {
                ["id": $0.id, "score": Double($0.score), "metadata": $0.metadata] as JSObject
            }
            call.resolve(["results": results])
        }
    }

    @objc func remove(_ call: CAPPluginCall) {
        guard let name = call.getString("collection") else {
            return call.reject("collection is required")
        }
        let ids = call.getArray("ids", String.self) ?? []
        queue.async {
            guard let col = self.store.existing(name) else {
                return call.resolve(["count": 0])
            }
            let removed = col.remove(ids: Set(ids))
            try? self.store.save(name)
            call.resolve(["count": removed])
        }
    }

    @objc func clear(_ call: CAPPluginCall) {
        guard let name = call.getString("collection") else {
            return call.reject("collection is required")
        }
        queue.async {
            self.store.delete(name)
            call.resolve()
        }
    }

    @objc func getCollectionInfo(_ call: CAPPluginCall) {
        guard let name = call.getString("collection") else {
            return call.reject("collection is required")
        }
        queue.async {
            guard let col = self.store.existing(name) else {
                return call.resolve(["exists": false, "count": 0, "lang": "",
                                     "revision": 0, "currentRevision": 0,
                                     "needsReindex": false])
            }
            let current = self.model(col.lang)?.revision ?? 0
            call.resolve([
                "exists": true, "count": col.items.count, "lang": col.lang,
                "revision": col.revision, "currentRevision": current,
                "needsReindex": current != col.revision
            ])
        }
    }
}
