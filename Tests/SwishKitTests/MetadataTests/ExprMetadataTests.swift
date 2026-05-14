import Testing
@testable import SwishKit

@Suite("Expr Metadata Tests")
struct ExprMetadataTests {
    // MARK: - Equality invariant

    @Test("Symbols with same name and different metadata are equal")
    func symbolEqualityIgnoresMeta() {
        let a = Expr.symbol("foo", metadata: [.keyword("private"): .boolean(true)])
        let b = Expr.symbol("foo", metadata: nil)
        #expect(a == b)
    }

    @Test("Lists with same elements and different metadata are equal")
    func listEqualityIgnoresMeta() {
        let a = Expr.list([.integer(1), .integer(2)], metadata: [.keyword("line"): .integer(5)])
        let b = Expr.list([.integer(1), .integer(2)], metadata: nil)
        #expect(a == b)
    }

    @Test("Vectors with same elements and different metadata are equal")
    func vectorEqualityIgnoresMeta() {
        let a = Expr.vector([.keyword("x")], metadata: [.keyword("tag"): .string("T")])
        let b = Expr.vector([.keyword("x")], metadata: nil)
        #expect(a == b)
    }

    @Test("Maps with same contents and different metadata are equal")
    func mapEqualityIgnoresMeta() {
        let a = Expr.map([.keyword("k"): .integer(1)], metadata: [.keyword("doc"): .string("hi")])
        let b = Expr.map([.keyword("k"): .integer(1)], metadata: nil)
        #expect(a == b)
    }

    // MARK: - Hash invariant

    @Test("Symbols with different metadata hash equally")
    func symbolHashIgnoresMeta() {
        let a = Expr.symbol("foo", metadata: [.keyword("x"): .boolean(true)])
        let b = Expr.symbol("foo", metadata: nil)
        #expect(a.hashValue == b.hashValue)
    }

    @Test("Vectors with different metadata hash equally")
    func vectorHashIgnoresMeta() {
        let a = Expr.vector([.integer(1)], metadata: [.keyword("x"): .boolean(true)])
        let b = Expr.vector([.integer(1)], metadata: nil)
        #expect(a.hashValue == b.hashValue)
    }
}
