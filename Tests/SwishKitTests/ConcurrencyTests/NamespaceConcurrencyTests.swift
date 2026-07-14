import Testing
import Foundation
import Synchronization
@testable import SwishKit

@Suite("Namespace Concurrency Tests")
struct NamespaceConcurrencyTests {
    @Test("Concurrent intern of the same name never creates duplicate Vars")
    func concurrentInternSameNameNoDuplicates() throws {
        let evaluator = Evaluator()
        let ns = evaluator.findOrCreateNs("concurrency-test-intern-same")
        let collected = Mutex<[Var]>([])
        let threads = 16
        DispatchQueue.concurrentPerform(iterations: threads) { i in
            let v = ns.intern(name: "shared-name", value: .integer(i))
            collected.withLock { $0.append(v) }
        }
        let vars = collected.withLock { $0 }
        #expect(vars.count == threads)
        let first = vars[0]
        #expect(vars.allSatisfy { $0 === first })
    }

    @Test("Concurrent intern of distinct names loses none")
    func concurrentInternDistinctNamesNoneLost() throws {
        let evaluator = Evaluator()
        let ns = evaluator.findOrCreateNs("concurrency-test-intern-distinct")
        let threads = 64
        DispatchQueue.concurrentPerform(iterations: threads) { i in
            _ = ns.intern(name: "var-\(i)", value: .integer(i))
        }
        for i in 0..<threads {
            #expect(ns.findVar(name: "var-\(i)")?.value == .integer(i))
        }
    }

    @Test("Concurrent def of distinct names via the full eval pipeline loses none")
    func concurrentDefDistinctNamesViaEval() throws {
        let swish = Swish()
        let threads = 32
        DispatchQueue.concurrentPerform(iterations: threads) { i in
            _ = try? swish.eval("(def concurrency-def-var-\(i) \(i))")
        }
        for i in 0..<threads {
            let v = try swish.eval("concurrency-def-var-\(i)")
            #expect(v == .integer(i))
        }
    }
}
