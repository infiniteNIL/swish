import Testing
import Foundation
@testable import SwishKit

@Suite("SwishArray Concurrency Tests")
struct SwishArrayConcurrencyTests {
    @Test("Concurrent aset on distinct indices of one shared array — no lost writes")
    func concurrentAsetDistinctIndices() throws {
        let swish = Swish()
        let size = 32
        _ = try swish.eval("(def arr (to-array (range \(size))))")
        let itersPerIndex = 200
        DispatchQueue.concurrentPerform(iterations: size) { idx in
            for n in 0..<itersPerIndex {
                _ = try? swish.eval("(aset arr \(idx) \(n))")
            }
        }
        for idx in 0..<size {
            let v = try swish.eval("(aget arr \(idx))")
            #expect(v == .integer(itersPerIndex - 1))
        }
    }
}
