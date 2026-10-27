import Foundation

protocol Embedder {
    var dimension: Int { get }
    var revision: Int { get }
    func vector(for text: String) -> [Double]?
}
