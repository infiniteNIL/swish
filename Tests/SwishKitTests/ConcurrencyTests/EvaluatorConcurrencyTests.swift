import Testing
import Foundation
import Synchronization
@testable import SwishKit

@Suite("Evaluator Concurrency Tests")
struct EvaluatorConcurrencyTests {
    @Test("gensym produces globally unique symbols under concurrent access")
    func gensymUniqueUnderConcurrency() throws {
        let evaluator = Evaluator()
        let threads = 16
        let itersPerThread = 200
        let collected = Mutex<[String]>([])
        DispatchQueue.concurrentPerform(iterations: threads) { _ in
            var local: [String] = []
            for _ in 0..<itersPerThread {
                local.append(evaluator.gensym())
            }
            collected.withLock { $0.append(contentsOf: local) }
        }
        let all = collected.withLock { $0 }
        #expect(all.count == threads * itersPerThread)
        #expect(Set(all).count == all.count)
    }

    @Test("N threads each running a loop/recur + def workload against one shared Evaluator — no corruption")
    func concurrentLoopRecurDefWorkload() throws {
        let swish = Swish()
        let threads = 16
        let itersPerThread = 10
        DispatchQueue.concurrentPerform(iterations: threads) { t in
            for i in 0..<itersPerThread {
                _ = try? swish.eval("""
                    (def evaluator-concurrency-var-\(t)-\(i)
                      (loop [x 0] (if (< x 5) (recur (inc x)) x)))
                    """)
            }
        }
        for t in 0..<threads {
            for i in 0..<itersPerThread {
                let v = try swish.eval("evaluator-concurrency-var-\(t)-\(i)")
                #expect(v == .integer(5))
            }
        }
    }
}
