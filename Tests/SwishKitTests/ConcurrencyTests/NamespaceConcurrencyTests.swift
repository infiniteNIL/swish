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

    @Test("Concurrent qualified-var-cache resolution of the same name is safe and converges to one Var")
    func concurrentQualifiedResolutionSameNameSafe() throws {
        let swish = Swish()
        _ = try swish.eval("(def shared-global 42)")
        let threads = 16
        let collected = Mutex<[Var]>([])
        DispatchQueue.concurrentPerform(iterations: threads) { _ in
            if let v = try? swish.evaluator.resolveQualifiedVar(name: "user/shared-global") {
                collected.withLock { $0.append(v) }
            }
        }
        let vars = collected.withLock { $0 }
        #expect(vars.count == threads)
        let first = vars[0]
        #expect(vars.allSatisfy { $0 === first })
    }

    @Test("Concurrent qualified-var-cache resolution of distinct names loses none")
    func concurrentQualifiedResolutionDistinctNamesSafe() throws {
        let swish = Swish()
        let threads = 32
        for i in 0..<threads {
            _ = try swish.eval("(def concurrent-qvar-\(i) \(i))")
        }
        DispatchQueue.concurrentPerform(iterations: threads) { i in
            _ = try? swish.evaluator.resolveQualifiedVar(name: "user/concurrent-qvar-\(i)")
        }
        for i in 0..<threads {
            let v = try swish.evaluator.resolveQualifiedVar(name: "user/concurrent-qvar-\(i)")
            #expect(v?.value == .integer(i))
        }
    }
}
