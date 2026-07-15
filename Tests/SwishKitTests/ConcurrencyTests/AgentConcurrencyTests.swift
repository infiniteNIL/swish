import Testing
import Foundation
import Synchronization
@testable import SwishKit

@Suite("Agent Concurrency Tests")
struct AgentConcurrencyTests {
    @Test("N threads concurrently send to the same agent — no lost updates")
    func concurrentSendNoLostUpdates() throws {
        let swish = Swish()
        _ = try swish.eval("(def a (agent 0))")
        let threads = 8
        let itersPerThread = 200
        DispatchQueue.concurrentPerform(iterations: threads) { _ in
            for _ in 0..<itersPerThread {
                _ = try? swish.eval("(send a inc)")
            }
        }
        _ = try swish.eval("(await a)")
        let result = try swish.eval("@a")
        #expect(result == .integer(threads * itersPerThread))
    }

    @Test("N threads concurrently create and deref independent futures — no crashes or wrong results")
    func concurrentIndependentFutures() throws {
        let swish = Swish()
        let threads = 16
        let results = Mutex<[Int: Bool]>([:])
        DispatchQueue.concurrentPerform(iterations: threads) { i in
            let v = try? swish.eval("@(future (+ \(i) 1))")
            results.withLock { $0[i] = (v == .integer(i + 1)) }
        }
        let all = results.withLock { $0 }
        #expect(all.count == threads)
        #expect(all.values.allSatisfy { $0 })
    }
}
