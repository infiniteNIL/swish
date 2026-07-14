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
}
