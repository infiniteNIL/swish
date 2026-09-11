import Testing
@testable import SwishKit

/// A host type with no Swish representation. Conforming to `SwishOpaque` is the
/// entire opt-in — the default implementations do the boxing.
struct User: SwishOpaque, Equatable {
    var name: String
    var age: Int
}

final class Counter: SwishOpaque {
    var count = 0

    func bump() {
        count += 1
    }
}

@Suite("Interop: opaque Swift values")
struct ForeignObjectTests {
    @Test("A host type threads through Swish between two registered functions")
    func roundTripsThroughSwish() throws {
        let swish = Swish()
        swish.register({ (name: String) in User(name: name, age: 42) }, as: "make-user")
        swish.register({ (u: User) in u.name }, as: "user-name")
        swish.register({ (u: User) in u.age }, as: "user-age")

        #expect(try swish.eval(#"(user-name (make-user "Rod"))"#) == .string("Rod"))
        #expect(try swish.eval(#"(user-age (make-user "Rod"))"#) == .integer(42))
    }

    @Test("Opaque values survive a trip through a Swish collection")
    func survivesCollections() throws {
        let swish = Swish()
        swish.register({ (name: String) in User(name: name, age: 1) }, as: "make-user")
        swish.register({ (us: [User]) in us.map(\.name).joined(separator: ",") }, as: "names")

        #expect(try swish.eval(#"(names [(make-user "a") (make-user "b")])"#) == .string("a,b"))
        #expect(try swish.eval(#"(names (map make-user ["a" "b"]))"#) == .string("a,b"))
    }

    @Test("Reference semantics are preserved — Swish holds the same instance")
    func referenceSemantics() throws {
        let swish = Swish()
        let counter = Counter()
        swish.define(counter, as: "counter")
        swish.register({ (c: Counter) in c.bump() }, as: "bump!")

        _ = try swish.eval("(bump!  counter) (bump! counter)")
        #expect(counter.count == 2)
    }

    @Test("Equality and hashing are by identity")
    func identitySemantics() throws {
        let swish = Swish()
        swish.register({ User(name: "same", age: 1) }, as: "make-user")

        // Two boxes of an equal value are still distinct handles.
        #expect(try swish.eval("(= (make-user) (make-user))") == .boolean(false))
        #expect(try swish.eval("(let [u (make-user)] (= u u))") == .boolean(true))
        #expect(try swish.eval("(let [u (make-user)] (count (set [u u])))") == .integer(1))
        // `hash` must not crash on an opaque value.
        #expect(try swish.eval("(integer? (hash (make-user)))") == .boolean(true))
    }

    @Test("foreign? and type report the Swift type")
    func predicatesAndType() throws {
        let swish = Swish()
        swish.register({ User(name: "a", age: 1) }, as: "make-user")

        #expect(try swish.eval("(foreign? (make-user))") == .boolean(true))
        #expect(try swish.eval("(foreign? 1)") == .boolean(false))
        #expect(try swish.eval("(type (make-user))") == .keyword("User"))
    }

    @Test("Printing shows the type and an address")
    func printing() throws {
        let swish = Swish()
        swish.register({ User(name: "a", age: 1) }, as: "make-user")

        let printed = try swish.eval("(pr-str (make-user))")
        guard case .string(let text) = printed else {
            Issue.record("Expected a string, got \(printed)")
            return
        }
        #expect(text.hasPrefix("#object[User 0x"))
        #expect(text.hasSuffix("]"))
    }

    @Test("Passing the wrong opaque type is an argument error, not a crash")
    func wrongOpaqueType() throws {
        let swish = Swish()
        swish.register({ User(name: "a", age: 1) }, as: "make-user")
        swish.register({ (c: Counter) in c.count }, as: "count-of")

        expectSwishError { try swish.eval("(count-of (make-user))") }
    }

    @Test("asForeign unwraps a raw Expr")
    func asForeignAccessor() throws {
        let swish = Swish()
        swish.register({ User(name: "Rod", age: 42) }, as: "make-user")

        let value = try swish.eval("(make-user)")
        #expect(value.asForeign(User.self) == User(name: "Rod", age: 42))
        #expect(value.asForeign(Counter.self) == nil)
    }
}
