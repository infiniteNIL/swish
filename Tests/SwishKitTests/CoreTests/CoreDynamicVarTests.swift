import Testing
@testable import SwishKit
import Foundation

@Suite("Dynamic vars and binding Tests", .serialized)
struct CoreDynamicVarTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - ^:dynamic def

    @Test("dynamic var has its root value outside binding")
    func dynamicVarRoot() throws {
        #expect(try swish.eval("(def ^:dynamic *dv* 42)  *dv*") == .integer(42))
    }

    @Test("binding temporarily overrides a dynamic var")
    func bindingOverrides() throws {
        _ = try swish.eval("(def ^:dynamic *x* 1)")
        #expect(try swish.eval("(binding [*x* 99] *x*)") == .integer(99))
    }

    @Test("binding restores root value after the form")
    func bindingRestores() throws {
        _ = try swish.eval("(def ^:dynamic *y* :root)")
        _ = try swish.eval("(binding [*y* :override] *y*)")
        #expect(try swish.eval("*y*") == .keyword("root"))
    }

    @Test("binding restores root value even if body throws")
    func bindingRestoresOnThrow() throws {
        _ = try swish.eval("(def ^:dynamic *z* :original)")
        _ = try? swish.eval("(binding [*z* :changed] (throw \"boom\"))")
        #expect(try swish.eval("*z*") == .keyword("original"))
    }

    @Test("nested binding uses innermost value")
    func nestedBinding() throws {
        _ = try swish.eval("(def ^:dynamic *n* 0)")
        let result = try swish.eval("""
            (binding [*n* 10]
              (binding [*n* 20]
                *n*))
            """)
        #expect(result == .integer(20))
    }

    @Test("nested binding restores outer value after inner binding")
    func nestedBindingRestoresOuter() throws {
        _ = try swish.eval("(def ^:dynamic *m* 0)")
        let result = try swish.eval("""
            (binding [*m* 10]
              (binding [*m* 20] *m*)
              *m*)
            """)
        #expect(result == .integer(10))
    }

    @Test("binding a non-dynamic var throws")
    func bindingNonDynamic() throws {
        _ = try swish.eval("(def not-dynamic 5)")
        #expect(throws: (any Error).self) {
            try swish.eval("(binding [not-dynamic 9] not-dynamic)")
        }
    }

    // MARK: - *out* binding

    @Test("*out* binding redirects println to a writer")
    func outBindingPrintln() throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).path
        defer { try? FileManager.default.removeItem(atPath: path) }
        _ = try swish.eval("(require '[clojure.swift.io :as io])")
        _ = try swish.eval("""
            (with-open [wtr (io/writer \"\(path)\")]
              (binding [*out* wtr]
                (println "hello")
                (println "world")))
            """)
        #expect(try String(contentsOfFile: path, encoding: .utf8) == "hello\nworld\n")
    }

    @Test("*out* is restored to stdout after binding")
    func outBindingRestored() throws {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).path
        defer { try? FileManager.default.removeItem(atPath: path) }
        _ = try swish.eval("(require '[clojure.swift.io :as io])")
        _ = try swish.eval("""
            (with-open [wtr (io/writer \"\(path)\")]
              (binding [*out* wtr]
                (println "inside")))
            """)
        // After binding, *out* is nil (stdout) again
        #expect(try swish.eval("(nil? *out*)") == .boolean(true))
    }

    // MARK: - set!

    @Test("set! updates a thread-bound dynamic var within its binding scope")
    func setUpdatesWithinScope() throws {
        _ = try swish.eval("(def ^:dynamic *sd* 1)")
        #expect(try swish.eval("(binding [*sd* 2] (set! *sd* 3) *sd*)") == .integer(3))
    }

    @Test("set! returns the new value")
    func setReturnsNewValue() throws {
        _ = try swish.eval("(def ^:dynamic *sd* 1)")
        #expect(try swish.eval("(binding [*sd* 2] (set! *sd* 7))") == .integer(7))
    }

    @Test("set! does not affect the root value after the binding scope exits")
    func setDoesNotLeakToRoot() throws {
        _ = try swish.eval("(def ^:dynamic *sd2* :root)")
        _ = try swish.eval("(binding [*sd2* :a] (set! *sd2* :b))")
        #expect(try swish.eval("*sd2*") == .keyword("root"))
    }

    @Test("set! mutates only the innermost frame; the outer binding is preserved")
    func setMutatesInnermostFrameOnly() throws {
        _ = try swish.eval("(def ^:dynamic *sn* 0)")
        let result = try swish.eval("""
            (binding [*sn* 1]
              (let [inner (binding [*sn* 2] (set! *sn* 99) *sn*)]
                [inner *sn*]))
            """)
        #expect(result == .vector([.integer(99), .integer(1)], metadata: nil))
    }

    @Test("set! from inside a fn body resolves the alias-expanded target var")
    func setFromInsideFnBody() throws {
        _ = try swish.eval("(def ^:dynamic *sf* 0)")
        _ = try swish.eval("(defn set-sf-setter [] (set! *sf* 42))")
        #expect(try swish.eval("(binding [*sf* 0] (set-sf-setter) *sf*)") == .integer(42))
    }

    @Test("set! on a var that is not thread-bound throws")
    func setNotThreadBoundThrows() throws {
        _ = try swish.eval("(def ^:dynamic *nb* 1)")
        #expect(throws: EvaluatorError.self) {
            try swish.eval("(set! *nb* 2)")
        }
    }

    @Test("set! on a non-dynamic var throws")
    func setNonDynamicThrows() throws {
        _ = try swish.eval("(def set-plain 1)")
        #expect(throws: EvaluatorError.self) {
            try swish.eval("(set! set-plain 2)")
        }
    }

    @Test("set! with wrong arity throws")
    func setWrongArityThrows() throws {
        _ = try swish.eval("(def ^:dynamic *nb* 1)")
        #expect(throws: EvaluatorError.self) {
            try swish.eval("(set! *nb*)")
        }
        #expect(throws: EvaluatorError.self) {
            try swish.eval("(binding [*nb* 0] (set! *nb* 1 2))")
        }
    }

    @Test("set! with a non-symbol target throws")
    func setNonSymbolTargetThrows() throws {
        #expect(throws: EvaluatorError.self) {
            try swish.eval("(set! 5 1)")
        }
    }
}
