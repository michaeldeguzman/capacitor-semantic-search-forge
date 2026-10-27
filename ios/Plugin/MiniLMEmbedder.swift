import Foundation
import CoreML

/// all-MiniLM-L6-v2 sentence embeddings from the bundled Core ML model
/// (see THIRD-PARTY-NOTICES.md). The model graph does the
/// attention-mask-weighted mean pooling and L2 normalisation itself.
/// Not thread-safe: the plugin calls it only from its serial queue.
final class MiniLMEmbedder: Embedder {
    /// nil if the model or vocabulary is missing from the app bundle.
    static let shared: MiniLMEmbedder? = MiniLMEmbedder()

    /// Tokens per input, including [CLS] and [SEP]. Fixed by the converted model.
    static let maxTokens = 128

    let dimension = 384
    /// Bump whenever the bundled model or the tokenizer changes.
    let revision = 1

    private let tokenizer: WordPieceTokenizer
    private let modelURL: URL
    private var model: MLModel?

    init?(bundle: Bundle = MiniLMEmbedder.resourceBundle) {
        guard let vocab = bundle.url(forResource: "vocab", withExtension: "txt"),
              let modelURL = bundle.url(forResource: "MiniLM", withExtension: "mlmodelc"),
              let tokenizer = WordPieceTokenizer(vocabURL: vocab) else { return nil }
        self.tokenizer = tokenizer
        self.modelURL = modelURL
    }

    /// The CocoaPods resource bundle, or the plugin's own bundle when the
    /// resources are copied in directly (as in ios/Plugin.xcodeproj).
    static var resourceBundle: Bundle {
        let own = Bundle(for: MiniLMEmbedder.self)
        if let url = own.url(forResource: "SemanticSearchModel", withExtension: "bundle"),
           let bundle = Bundle(url: url) {
            return bundle
        }
        return own
    }

    func vector(for text: String) -> [Double]? {
        let ids = tokenizer.encode(text, maxLength: Self.maxTokens)
        guard ids.count > 2 else { return nil } // only [CLS] [SEP]: empty or whitespace
        guard let model = loadModel(),
              let idArray = try? MLMultiArray(shape: [1, NSNumber(value: Self.maxTokens)], dataType: .float32),
              let maskArray = try? MLMultiArray(shape: [1, NSNumber(value: Self.maxTokens)], dataType: .float32) else {
            return nil
        }
        for i in 0..<Self.maxTokens {
            idArray[i] = NSNumber(value: i < ids.count ? Float(ids[i]) : 0)
            maskArray[i] = NSNumber(value: i < ids.count ? Float(1) : 0)
        }
        guard let input = try? MLDictionaryFeatureProvider(dictionary: ["ids": idArray, "mask": maskArray]),
              let output = try? model.prediction(from: input),
              let embedding = output.featureValue(for: "embedding")?.multiArrayValue,
              embedding.count == dimension else {
            return nil
        }
        return (0..<dimension).map { embedding[$0].doubleValue }
    }

    private func loadModel() -> MLModel? {
        if model == nil {
            model = try? MLModel(contentsOf: modelURL, configuration: MLModelConfiguration())
        }
        return model
    }
}
