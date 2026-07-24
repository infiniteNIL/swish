import Testing
@testable import SwishKit

@Suite("clojure.string index-of Tests", .serialized)
struct ClojureStringIndexOfTests {
    static let _shared: Swish = {
        let swish = Swish()
        _ = try? swish.eval("(require '[clojure.string :as str])")
        return swish
    }()
    var swish: Swish { Self._shared }

    @Test("index-of: found, from-index, not-found, char value")
    func indexOf() throws {
        #expect(try swish.eval(#"(str/index-of "abcabc" "b")"#) == .integer(1))
        #expect(try swish.eval(#"(str/index-of "abcabc" "b" 2)"#) == .integer(4))
        #expect(try swish.eval(#"(str/index-of "abc" "z")"#) == .nil)
        #expect(try swish.eval(#"(str/index-of "abc" \c)"#) == .integer(2))
    }

    @Test("last-index-of: found, from-index")
    func lastIndexOf() throws {
        #expect(try swish.eval(#"(str/last-index-of "abcabc" "b")"#) == .integer(4))
        #expect(try swish.eval(#"(str/last-index-of "abcabc" "b" 3)"#) == .integer(1))
        #expect(try swish.eval(#"(str/last-index-of "abc" "z")"#) == .nil)
    }
}
