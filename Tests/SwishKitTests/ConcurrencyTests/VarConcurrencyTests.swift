import Testing
import Foundation
@testable import SwishKit

@Suite("Var Concurrency Tests")
struct VarConcurrencyTests {
    @Test("N threads concurrently alter-var-root the same var with no lost updates")
    func concurrentAlterVarRootNoLostUpdates() throws {
        let swish = Swish()
        _ = try swish.eval("(def x 0)")
        let threads = 8
        let itersPerThread = 500
        DispatchQueue.concurrentPerform(iterations: threads) { _ in
            for _ in 0..<itersPerThread {
                _ = try? swish.eval("(alter-var-root (var x) inc)")
            }
        }
        let result = try swish.eval("x")
        #expect(result == .integer(threads * itersPerThread))
    }
}
