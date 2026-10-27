import XCTest
@testable import Plugin

/// Parity with the Python reference: Fixtures/minilm_parity.json holds token ids
/// from Hugging Face's fast tokenizer and sentence-transformers vectors.
class MiniLMParityTests: XCTestCase {
    struct Fixture: Decodable {
        struct Case: Decodable { let text: String; let ids: [Int]; let vector: [Double]? }
        let maxTokens: Int
        let cases: [Case]
    }

    private func fixture() throws -> Fixture {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "minilm_parity", withExtension: "json"))
        return try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
    }

    func testTokenizerMatchesPython() throws {
        let f = try fixture()
        XCTAssertEqual(f.maxTokens, MiniLMEmbedder.maxTokens)
        let vocab = try XCTUnwrap(MiniLMEmbedder.resourceBundle.url(forResource: "vocab", withExtension: "txt"))
        let tokenizer = try XCTUnwrap(WordPieceTokenizer(vocabURL: vocab))
        for c in f.cases {
            XCTAssertEqual(tokenizer.encode(c.text, maxLength: f.maxTokens), c.ids, "text: \(c.text.debugDescription)")
        }
    }

    func testEmbeddingsMatchSentenceTransformers() throws {
        let f = try fixture()
        let embedder = try XCTUnwrap(MiniLMEmbedder.shared, "model resources missing")
        XCTAssertEqual(embedder.dimension, 384)
        var worst = 1.0
        for c in f.cases {
            let v = embedder.vector(for: c.text)
            guard let expected = c.vector else {
                XCTAssertNil(v, "empty text should give no vector: \(c.text.debugDescription)")
                continue
            }
            let got = VectorStore.normalise(try XCTUnwrap(v, "no vector for \(c.text.debugDescription)"))
            let cosine = zip(got, expected).reduce(0.0) { $0 + Double($1.0) * $1.1 }
            worst = min(worst, cosine)
            XCTAssertGreaterThanOrEqual(cosine, 0.99, "text: \(c.text.debugDescription)")
        }
        print("MiniLM parity: lowest cosine \(worst)")
    }
}
