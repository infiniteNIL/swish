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
}
