import Testing
@testable import SwishKit

@Suite("Core vec Tests", .serialized)
struct CoreVecTests {
    nonisolated(unsafe) static let _shared = Swish()
    var swish: Swish { Self._shared }

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
}
