import XCTest
@testable import Plugin

class SemanticSearchTests: XCTestCase {
    func testNormaliseProducesUnitVector() {
        let v = VectorStore.normalise([3, 4])
        XCTAssertEqual(v[0], 0.6, accuracy: 0.0001)
        XCTAssertEqual(v[1], 0.8, accuracy: 0.0001)
    }

    func testSearchRanksByDotProductAndUpsertReplaces() {
        let col = VectorCollection(lang: "en", revision: 1)
        col.upsert(id: "a", vector: [1, 0], metadata: "")
        col.upsert(id: "b", vector: [0, 1], metadata: "")
        col.upsert(id: "a", vector: [0.6, 0.8], metadata: "updated")

        XCTAssertEqual(col.items.count, 2)
        let hits = col.search([0, 1], topK: 5, minScore: 0)
        XCTAssertEqual(hits.map { $0.id }, ["b", "a"])
        XCTAssertEqual(hits[1].metadata, "updated")
        XCTAssertEqual(col.remove(ids: ["a", "missing"]), 1)
    }

    private func vec(_ i: Int) -> [Float] {
        VectorStore.normalise((0..<8).map { Double(($0 * 7 + i * 3) % 11) + 1 })
    }

    func testPersistReloadReupsertRemoveDelete() throws {
        let name = "xctest-\(UUID().uuidString)"
        let store = VectorStore()
        let col = store.collection(name, lang: "en", revision: 1)
        for i in 0..<50 { col.upsert(id: "id\(i)", vector: vec(i), metadata: "m\(i)") }
        try store.save(name)

        // Test 3: a fresh store (as after relaunch) reads 50 items from disk
        let reloaded = try XCTUnwrap(VectorStore().existing(name))
        XCTAssertEqual(reloaded.items.count, 50)
        XCTAssertEqual(reloaded.lang, "en")
        XCTAssertEqual(reloaded.revision, 1)

        // Test 6: same ids, new content keeps the count and replaces the item
        let store2 = VectorStore()
        let col2 = store2.collection(name, lang: "en", revision: 1)
        for i in 0..<50 { col2.upsert(id: "id\(i)", vector: vec(i + 1), metadata: "new\(i)") }
        try store2.save(name)
        XCTAssertEqual(VectorStore().existing(name)?.items.count, 50)
        XCTAssertEqual(col2.search(vec(6), topK: 1, minScore: 0).first?.metadata, "new5")

        // Revision change replaces the collection instead of mixing vectors
        XCTAssertEqual(VectorStore().collection(name, lang: "en", revision: 2).items.count, 0)

        // Test 7: remove two, then delete
        XCTAssertEqual(col2.remove(ids: ["id0", "id1"]), 2)
        try store2.save(name)
        XCTAssertEqual(VectorStore().existing(name)?.items.count, 48)
        store2.delete(name)
        XCTAssertNil(VectorStore().existing(name))
    }
}
