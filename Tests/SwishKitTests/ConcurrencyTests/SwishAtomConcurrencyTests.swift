import Testing
import Foundation
import Synchronization
@testable import SwishKit

@Suite("SwishAtom Concurrency Tests")
struct SwishAtomConcurrencyTests {
    @Test("N threads concurrently swap! the same atom with no lost updates")
    func concurrentSwapNoLostUpdates() throws {
        let swish = Swish()
        _ = try swish.eval("(def a (atom 0))")
        let threads = 8
        let itersPerThread = 500
        DispatchQueue.concurrentPerform(iterations: threads) { _ in
            for _ in 0..<itersPerThread {
                _ = try? swish.eval("(swap! a inc)")
            }
        }
        let result = try swish.eval("@a")
        #expect(result == .integer(threads * itersPerThread))
    }

    @Test("N threads concurrently reset! the same atom — every write lands, none corrupted")
    func concurrentResetNoCorruption() throws {
        let swish = Swish()
        _ = try swish.eval("(def a (atom -1))")
        let threads = 8
        DispatchQueue.concurrentPerform(iterations: threads) { i in
            _ = try? swish.eval("(reset! a \(i))")
        }
        let result = try swish.eval("@a")
        guard case .integer(let v) = result else {
            Issue.record("Expected .integer, got \(result)")
            return
        }
        #expect((0..<threads).contains(v))
    }
}
