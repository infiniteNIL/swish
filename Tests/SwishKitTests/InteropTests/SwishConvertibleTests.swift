import Foundation
import Testing
import BigInt
@testable import SwishKit

@Suite("Interop: value conversion")
struct SwishConvertibleTests {
    @Test("Scalars round-trip")
    func scalarRoundTrips() throws {
        #expect(Int(swishValue: 42.swishValue) == 42)
        #expect(Double(swishValue: 2.5.swishValue) == 2.5)
        #expect(Float(swishValue: Float(2.5).swishValue) == 2.5)
        #expect(Bool(swishValue: true.swishValue) == true)
        #expect(String(swishValue: "hi".swishValue) == "hi")
        #expect(Character(swishValue: Character("x").swishValue) == "x")
        #expect(BigInt(swishValue: BigInt(9).swishValue) == BigInt(9))

        let uuid = UUID()
        #expect(UUID(swishValue: uuid.swishValue) == uuid)
        let date = Date(timeIntervalSince1970: 1_000_000)
        #expect(Date(swishValue: date.swishValue) == date)
    }

    @Test("Encoded Swish values have the expected shape")
    func encodedShapes() {
        #expect(42.swishValue == .integer(42))
        #expect("hi".swishValue == .string("hi"))
        #expect(true.swishValue == .boolean(true))
        #expect([1, 2].swishValue == .vector(SwishPersistentVector([.integer(1), .integer(2)]), metadata: nil))
        #expect(["a": 1].swishValue == .map([.string("a"): .integer(1)], metadata: nil))
        #expect(Optional<Int>.none.swishValue == .nil)
        #expect(Optional(3).swishValue == .integer(3))
    }

    @Test("Expr converts to itself, so a raw value can pass through unchanged")
    func exprIdentity() {
        let value = Expr.keyword("kw")
        #expect(value.swishValue == value)
        #expect(Expr(swishValue: value) == value)
    }

    @Test("Optional decodes nil from .nil and a value otherwise")
    func optionalDecoding() {
        #expect(Int?(swishValue: .nil) == .some(.none))
        #expect(Int?(swishValue: .integer(3)) == .some(.some(3)))
        // A present-but-wrong-typed value is still a failure, not nil.
        #expect(Int?(swishValue: .string("x")) == nil)
    }

    @Test("Integer decoding is exact — no truncation, no overflow")
    func integerDecodingIsExact() {
        #expect(Int(swishValue: .integer(5)) == 5)
        #expect(Int(swishValue: .bigInteger(BigInt(5))) == 5)
        #expect(Int(swishValue: .double(5.0)) == nil)
        #expect(Int(swishValue: .ratio(Ratio(BigInt(1), BigInt(2)))) == nil)
        #expect(Int8(swishValue: .integer(300)) == nil)
        #expect(UInt8(swishValue: .integer(-1)) == nil)
    }

    @Test("Floating-point decoding widens from the integer tower")
    func floatDecodingWidens() {
        #expect(Double(swishValue: .integer(5)) == 5.0)
        #expect(Double(swishValue: .float(2.5)) == 2.5)
        #expect(Double(swishValue: .ratio(Ratio(BigInt(1), BigInt(2)))) == 0.5)
        #expect(Double(swishValue: .string("x")) == nil)
    }

    @Test("Arrays decode from every seqable shape")
    func arrayDecodingAcceptsSeqables() throws {
        let evaluator = Evaluator()
        for source in ["[1 2 3]", "'(1 2 3)", "(range 1 4)", "(seq [1 2 3])"] {
            let value = try evaluator.eval(source)
            #expect([Int](swishValue: value) == [1, 2, 3], "failed for \(source)")
        }
    }

    @Test("A collection with one wrong element fails rather than silently dropping it")
    func collectionDecodingIsStrict() {
        let mixed = Expr.vector(SwishPersistentVector([.integer(1), .string("x")]), metadata: nil)
        #expect([Int](swishValue: mixed) == nil)
    }

    @Test("Sets and dictionaries round-trip")
    func setAndDictionaryRoundTrips() {
        let set: Set<Int> = [1, 2, 3]
        #expect(Set<Int>(swishValue: set.swishValue) == set)

        let dict = ["a": 1, "b": 2]
        #expect([String: Int](swishValue: dict.swishValue) == dict)
    }

    @Test("Nested collections round-trip")
    func nestedRoundTrips() {
        let nested: [String: [Int]] = ["a": [1, 2], "b": [3]]
        #expect([String: [Int]](swishValue: nested.swishValue) == nested)
    }

    @Test("asSequence now covers eager collections, not just seqs")
    func asSequenceCoversEagerCollections() throws {
        let evaluator = Evaluator()
        for source in ["[1 2 3]", "'(1 2 3)", "(range 1 4)", "(seq [1 2 3])"] {
            let value = try evaluator.eval(source)
            let elements = value.asSequence().map { Array($0) }
            #expect(elements == [.integer(1), .integer(2), .integer(3)], "failed for \(source)")
        }
        #expect(Expr.integer(1).asSequence() == nil)
    }

    @Test("asArray realizes a lazy seq")
    func asArrayRealizesLazySeq() throws {
        let evaluator = Evaluator()
        let value = try evaluator.eval("(map inc [1 2 3])")
        #expect(value.asArray() == [.integer(2), .integer(3), .integer(4)])
    }
}
