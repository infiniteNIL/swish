import Testing
import Foundation
import Synchronization
@testable import SwishKit

@Suite("Ref Concurrency Tests")
struct RefConcurrencyTests {
    @Test("N threads concurrently dosync-alter the same ref — no lost updates")
    func concurrentAlterNoLostUpdates() throws {
        let swish = Swish()
        _ = try swish.eval("(def r (ref 0))")
        let threads = 8
        let itersPerThread = 500
        DispatchQueue.concurrentPerform(iterations: threads) { _ in
            for _ in 0..<itersPerThread {
                _ = try? swish.eval("(dosync (alter r inc))")
            }
        }
        let result = try swish.eval("@r")
        #expect(result == .integer(threads * itersPerThread))
    }

    /// Two refs whose sum must always equal a constant. A concurrent reader does
    /// a plain (dosync (+ @a @b)) — no `ensure` needed — and must never observe a
    /// torn/intermediate sum, validating the "all touched refs conflict-check"
    /// design (both the read of a and the read of b participate in the same
    /// transaction's commit-time version verification).
    @Test("Two refs summing to a constant never appear torn to a concurrent reader")
    func multiRefAtomicity() throws {
        let swish = Swish()
        _ = try swish.eval("(def a (ref 500)) (def b (ref 500))")
        let stop = Mutex(false)
        let sawTorn = Mutex(false)
        let readerDone = DispatchSemaphore(value: 0)

        DispatchQueue.global().async {
            while !stop.withLock({ $0 }) {
                if let sum = try? swish.eval("(dosync (+ @a @b))"), sum != .integer(1000) {
                    sawTorn.withLock { $0 = true }
                }
            }
            readerDone.signal()
        }

        DispatchQueue.concurrentPerform(iterations: 8) { _ in
            for _ in 0..<200 {
                _ = try? swish.eval("(dosync (alter a - 1) (alter b + 1))")
            }
        }

        stop.withLock { $0 = true }
        readerDone.wait()

        #expect(sawTorn.withLock { $0 } == false)
        #expect(try swish.eval("(+ @a @b)") == .integer(1000))
    }
}
