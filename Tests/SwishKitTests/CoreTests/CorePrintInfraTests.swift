import Testing
@testable import SwishKit

/// Print infrastructure: the now-honored print-control vars, `#:ns{}` namespaced-map
/// printing, `print-method` extensibility, and the tagged-literal data types.
@Suite("Core print infrastructure Tests", .serialized)
struct CorePrintInfraTests {
    static let _shared = Evaluator()
    var evaluator: Evaluator { Self._shared }

    // MARK: - Print-control vars (previously nominal)

    @Test("*print-length* is honored dynamically")
    func printLength() throws {
        #expect(try evaluator.eval("(binding [*print-length* 3] (pr-str (range 10)))") == .string("(0 1 2 ...)"))
        #expect(try evaluator.eval("(pr-str (range 5))") == .string("(0 1 2 3 4)"))
    }

    @Test("*print-level* caps nesting depth with #")
    func printLevel() throws {
        #expect(try evaluator.eval("(binding [*print-level* 1] (pr-str [1 [2 [3]]]))") == .string("[1 #]"))
        #expect(try evaluator.eval("(binding [*print-level* 2] (pr-str [1 [2 [3]]]))") == .string("[1 [2 #]]"))
        #expect(try evaluator.eval("(binding [*print-level* 0] (pr-str [1 2]))") == .string("#"))
    }

    @Test("*print-readably* false renders strings/chars unquoted in pr")
    func printReadably() throws {
        #expect(try evaluator.eval(#"(binding [*print-readably* false] (pr-str ["hi" \a]))"#) == .string("[hi a]"))
        #expect(try evaluator.eval(#"(pr-str ["hi" \a])"#) == .string("[\"hi\" \\a]"))
    }

    // MARK: - Namespaced maps

    @Test("a map whose keys share a namespace prints as #:ns{...}")
    func namespacedMap() throws {
        #expect(try evaluator.eval("(pr-str {:a/x 1 :a/y 2})") == .string("#:a{:x 1 :y 2}"))
        // mixed namespaces → no compaction
        #expect(try evaluator.eval("(pr-str {:a/x 1 :b/y 2})") == .string("{:a/x 1 :b/y 2}"))
        // an unqualified key present → no compaction
        #expect(try evaluator.eval("(pr-str {:a/x 1 :y 2})") == .string("{:a/x 1 :y 2}"))
        // opt-out
        #expect(try evaluator.eval("(binding [*print-namespace-maps* false] (pr-str {:a/x 1 :a/y 2}))") == .string("{:a/x 1 :a/y 2}"))
    }

    @Test("a namespaced map round-trips through the reader")
    func namespacedMapRoundTrips() throws {
        #expect(try evaluator.eval("(= {:a/x 1 :a/y 2} (read-string (pr-str {:a/x 1 :a/y 2})))") == .boolean(true))
    }

    // MARK: - print-method

    @Test("print-method customizes how a user type prints, including nested")
    func printMethodCustom() throws {
        _ = try evaluator.eval("""
            (do
              (defrecord PMPoint [x y])
              (defmethod print-method PMPoint [p w] (print (str "#pt(" (:x p) "," (:y p) ")"))))
            """)
        #expect(try evaluator.eval("(pr-str (->PMPoint 1 2))") == .string("#pt(1,2)"))
        #expect(try evaluator.eval("(pr-str [(->PMPoint 1 2) (->PMPoint 3 4)])") == .string("[#pt(1,2) #pt(3,4)]"))
    }

    @Test("a user type with no print-method prints the native default")
    func printMethodDefault() throws {
        #expect(try evaluator.eval("(do (defrecord PMPlain [a]) (pr-str (->PMPlain 9)))") == .string("#PMPlain{:a 9}"))
    }

    // MARK: - Tagged literals / reader conditionals

    @Test("tagged-literal constructs, tests, and prints as #tag form")
    func taggedLiteral() throws {
        #expect(try evaluator.eval("(pr-str (tagged-literal 'foo/bar 42))") == .string("#foo/bar 42"))
        #expect(try evaluator.eval("(tagged-literal? (tagged-literal 'x 1))") == .boolean(true))
        #expect(try evaluator.eval("(tagged-literal? 5)") == .boolean(false))
        #expect(try evaluator.eval("(:tag (tagged-literal 'foo 1))") == .symbol("foo", metadata: nil))
    }

    @Test("reader-conditional constructs and tests")
    func readerConditional() throws {
        #expect(try evaluator.eval("(reader-conditional? (reader-conditional '(:clj 1) false))") == .boolean(true))
        #expect(try evaluator.eval("(reader-conditional? 5)") == .boolean(false))
        #expect(try evaluator.eval("(:splicing? (reader-conditional '(:clj 1) true))") == .boolean(true))
    }

    // MARK: - flush

    @Test("flush does not throw")
    func flush() throws {
        #expect(try evaluator.eval("(flush)") == .nil)
        #expect(try evaluator.eval("(with-out-str (print \"x\") (flush))") == .string("x"))
    }
}
