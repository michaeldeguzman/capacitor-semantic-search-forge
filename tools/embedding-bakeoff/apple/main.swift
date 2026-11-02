// Dumps Apple embedding vectors for the bake-off.
// usage: apple <data.json> <out.json>
import Foundation
import NaturalLanguage

struct D: Decodable { struct I: Decodable { let id: String; let text: String; let metadata: String }; let items: [I]; let queries: [[String]] }
let d = try! JSONDecoder().decode(D.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[1])))
let docs = d.items.map { $0.text }, titles = d.items.map { $0.metadata }, queries = d.queries.map { $0[0] }

func ms(_ t: DispatchTime) -> Double { Double(DispatchTime.now().uptimeNanoseconds - t.uptimeNanoseconds) / 1e6 }

func run(_ embed: (String) -> [Double]) -> [String: Any] {
    for q in queries { _ = embed(q) } // warm-up
    var qms: [Double] = []
    let qv: [[Double]] = queries.map { q in let t = DispatchTime.now(); let v = embed(q); qms.append(ms(t)); return v }
    let t = DispatchTime.now()
    let dv = docs.map(embed)
    let indexMs = ms(t)
    return ["docs": dv, "titles": titles.map(embed), "queries": qv, "query_ms": qms, "index_ms": indexMs]
}

var out: [String: Any] = [:]

// Engine 1: NLEmbedding sentence embedding
let s = NLEmbedding.sentenceEmbedding(for: .english)!
var e1 = run { s.vector(for: $0)! }
e1["info"] = "NLEmbedding.sentenceEmbedding(en) dim \(s.dimension) rev \(s.revision)"
out["nl_sentence"] = e1

// Engine 2: NLContextualEmbedding, mean-pooled token vectors
let c = NLContextualEmbedding(language: .english)!
let hadAssets = c.hasAvailableAssets
if !hadAssets {
    let sem = DispatchSemaphore(value: 0)
    c.requestAssets { result, error in print("requestAssets:", result.rawValue, error as Any); sem.signal() }
    sem.wait()
}
try! c.load()
func pooled(_ text: String) -> [Double] {
    let r = try! c.embeddingResult(for: text, language: .english)
    var sum = [Double](repeating: 0, count: c.dimension); var n = 0
    r.enumerateTokenVectors(in: text.startIndex..<text.endIndex) { v, _ in
        for i in 0..<v.count { sum[i] += v[i] }; n += 1; return true
    }
    return sum.map { $0 / Double(max(n, 1)) }
}
var e2 = run(pooled)
e2["info"] = "NLContextualEmbedding(en) model \(c.modelIdentifier) dim \(c.dimension) rev \(c.revision) maxSeq \(c.maximumSequenceLength) assetsAlreadyPresent \(hadAssets)"
out["nl_contextual"] = e2

try! JSONSerialization.data(withJSONObject: out).write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
print(e1["info"]!); print(e2["info"]!)
