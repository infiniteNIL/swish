import Testing
@testable import SwishKit

@Suite("clojure.walk Tests", .serialized)
struct ClojureWalkTests {
    static let _shared: Swish = {
        let swish = Swish()
        _ = try? swish.eval("(require '[clojure.walk :as walk])")
        return swish
    }()
    var swish: Swish { Self._shared }

    @Test("keywordize-keys/stringify-keys handle nested maps and round-trip")
    func walkKeys() throws {
        #expect(
            try swish.eval(#"(walk/keywordize-keys {"a" 1 "b" {"c" 2}})"#)
                == .map([.keyword("a"): .integer(1),
                         .keyword("b"): .map([.keyword("c"): .integer(2)], metadata: nil)], metadata: nil))
        #expect(
            try swish.eval(#"(walk/stringify-keys {:a 1 :b {:c 2}})"#)
                == .map([.string("a"): .integer(1),
                         .string("b"): .map([.string("c"): .integer(2)], metadata: nil)], metadata: nil))
        #expect(
            try swish.eval(#"(= {:a {:b 1}} (walk/keywordize-keys (walk/stringify-keys {:a {:b 1}})))"#)
                == .boolean(true))
    }

    // MARK: - prewalk / prewalk-replace / macroexpand-all

    @Test("prewalk transforms depth-first pre-order")
    func prewalk() throws {
        #expect(try swish.eval("(walk/prewalk (fn [x] (if (number? x) (inc x) x)) [1 [2 [3]]])")
            == .vector([.integer(2), .vector([.integer(3), .vector([.integer(4)], metadata: nil)], metadata: nil)], metadata: nil))
    }

    @Test("prewalk-replace replaces from the root down")
    func prewalkReplace() throws {
        #expect(try swish.eval("(walk/prewalk-replace {1 :a} [1 [1 2]])")
            == .vector([.keyword("a"), .vector([.keyword("a"), .integer(2)], metadata: nil)], metadata: nil))
    }

    @Test("macroexpand-all recursively expands nested macros")
    func macroexpandAll() throws {
        // (when true (when false 1)) -> both `when`s expand, incl. the nested one
        #expect(try swish.eval("(= (walk/macroexpand-all '(when true (when false 1))) '(if true (do (if false (do 1)))))")
            == .boolean(true))
    }
}
