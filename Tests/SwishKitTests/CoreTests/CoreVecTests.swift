import Testing
@testable import SwishKit

@Suite("Core vec Tests", .serialized)
struct CoreVecTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - lazy-seq thunk errors propagate instead of silently truncating

    @Test("vec propagates a lazy-seq thunk's error instead of silently truncating the result")
    func vecPropagatesThunkError() throws {
        #expect(throws: (any Error).self) {
            try swish.eval("(vec (map (fn [x] (if (= x 3) (throw \"boom\") x)) [1 2 3 4 5]))")
        }
    }

    // MARK: - bad shape inputs throw

    @Test("(vec 42) throws for integer")
    func vecThrowsForInteger() {
        #expect(throws: (any Error).self) { try swish.eval("(vec 42)") }
    }

    @Test("(vec 3.14) throws for double")
    func vecThrowsForDouble() {
        #expect(throws: (any Error).self) { try swish.eval("(vec 3.14)") }
    }

    @Test("(vec true) throws for boolean")
    func vecThrowsForBoolean() {
        #expect(throws: (any Error).self) { try swish.eval("(vec true)") }
    }

    @Test("(vec :a) throws for keyword")
    func vecThrowsForKeyword() {
        #expect(throws: (any Error).self) { try swish.eval("(vec :a)") }
    }

    @Test("(vec (transient [])) throws for transient")
    func vecThrowsForTransient() {
        #expect(throws: (any Error).self) { try swish.eval("(vec (transient []))") }
    }

    // MARK: - array aliasing

    @Test("(vec arr) aliases the array so aset mutations are visible through v")
    func vecAliasesArrayStorage() throws {
        let result = try swish.eval("""
            (let [arr (to-array [1 2 3])
                  v   (vec arr)]
              (aset arr 0 -1)
              (= [-1 2 3] v))
            """)
        #expect(result == .boolean(true))
    }

    @Test("arrays are not equal to vectors with same elements")
    func arrayNotEqualToVector() throws {
        #expect(try swish.eval("(= (to-array [1 2]) [1 2])") == .boolean(false))
    }

    @Test("(vector? (object-array 3)) is false")
    func objectArrayIsNotVector() throws {
        #expect(try swish.eval("(vector? (object-array 3))") == .boolean(false))
    }
}
