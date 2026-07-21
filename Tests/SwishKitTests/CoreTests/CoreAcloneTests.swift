import Testing
@testable import SwishKit

@Suite("Core aclone Tests", .serialized)
struct CoreAcloneTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - int-array

    @Test("(int-array 3) creates array of length 3")
    func intArraySize() throws {
        #expect(try swish.eval("(alength (int-array 3))") == .integer(3))
    }

    @Test("(int-array 3) fills with zeros")
    func intArrayFillsZero() throws {
        #expect(try swish.eval("(aget (int-array 3) 0)") == .integer(0))
        #expect(try swish.eval("(aget (int-array 3) 2)") == .integer(0))
    }

    @Test("(int-array 0) creates empty array")
    func intArrayEmpty() throws {
        #expect(try swish.eval("(alength (int-array 0))") == .integer(0))
    }

    @Test("(int-array 2 42) fills with init value")
    func intArrayWithInit() throws {
        #expect(try swish.eval("(aget (int-array 2 42) 1)") == .integer(42))
    }

    // MARK: - object-array

    @Test("(object-array 3) creates array of length 3")
    func objectArraySize() throws {
        #expect(try swish.eval("(alength (object-array 3))") == .integer(3))
    }

    @Test("(object-array 3) fills with nil")
    func objectArrayFillsNil() throws {
        #expect(try swish.eval("(aget (object-array 3) 0)") == .nil)
    }

    @Test("(object-array 0) creates empty array")
    func objectArrayEmpty() throws {
        #expect(try swish.eval("(alength (object-array 0))") == .integer(0))
    }

    // MARK: - aget / alength

    @Test("aget returns set value")
    func agetReturnsSetValue() throws {
        #expect(try swish.eval("(let [a (int-array 3)] (aset a 1 99) (aget a 1))") == .integer(99))
    }

    @Test("aget out of bounds throws")
    func agetOutOfBounds() throws {
        #expect(throws: (any Error).self) { try swish.eval("(aget (int-array 3) 5)") }
    }

    @Test("alength on non-array throws")
    func alengthNonArray() throws {
        #expect(throws: (any Error).self) { try swish.eval("(alength [1 2 3])") }
    }

    // MARK: - aclone

    @Test("aclone produces same element values")
    func acloneSameElements() throws {
        let result = try swish.eval("""
            (let [a (int-array 3)]
              (aset a 0 1) (aset a 1 2) (aset a 2 3)
              (let [a' (aclone a)]
                (every? identity (map #(= (aget a %) (aget a' %)) (range 3)))))
            """)
        #expect(result == .boolean(true))
    }

    @Test("aclone has same length")
    func acloneSameLength() throws {
        #expect(try swish.eval("(alength (aclone (int-array 3)))") == .integer(3))
    }

    @Test("aclone of empty array has length 0")
    func acloneEmptyLength() throws {
        #expect(try swish.eval("(alength (aclone (int-array 0)))") == .integer(0))
    }

    @Test("aclone is not identical? to original")
    func acloneNotIdentical() throws {
        #expect(try swish.eval("(let [a (int-array 3) a' (aclone a)] (not (identical? a a')))") == .boolean(true))
    }

    @Test("mutating original does not affect clone")
    func acloneOriginalMutationIsolated() throws {
        let result = try swish.eval("""
            (let [a (int-array 3)]
              (aset a 1 2)
              (let [a' (aclone a)]
                (aset a 1 11)
                (= 2 (aget a' 1))))
            """)
        #expect(result == .boolean(true))
    }

    @Test("mutating clone does not affect original")
    func acloneCloneMutationIsolated() throws {
        let result = try swish.eval("""
            (let [a (int-array 3)]
              (aset a 2 3)
              (let [a' (aclone a)]
                (aset a' 2 12)
                (= 3 (aget a 2))))
            """)
        #expect(result == .boolean(true))
    }

    @Test("aclone works with object-array")
    func acloneObjectArray() throws {
        let result = try swish.eval("""
            (let [a (object-array 3)]
              (aset a 0 :x)
              (let [a' (aclone a)]
                (and (= :x (aget a' 0))
                     (not (identical? a a')))))
            """)
        #expect(result == .boolean(true))
    }

    @Test("aclone on non-array throws")
    func acloneNonArray() throws {
        #expect(throws: (any Error).self) { try swish.eval("(aclone [1 2 3])") }
    }

    // MARK: - into-array

    @Test("into-array collects elements of a vector")
    func intoArrayFromVector() throws {
        #expect(try swish.eval("(alength (into-array [1 2 3]))") == .integer(3))
        #expect(try swish.eval("(aget (into-array [1 2 3]) 1)") == .integer(2))
    }

    @Test("into-array collects elements of a list")
    func intoArrayFromList() throws {
        #expect(try swish.eval("(alength (into-array '(:a :b)))") == .integer(2))
        #expect(try swish.eval("(aget (into-array '(:a :b)) 0)") == .keyword("a"))
    }

    @Test("into-array on nil produces an empty array")
    func intoArrayNil() throws {
        #expect(try swish.eval("(alength (into-array nil))") == .integer(0))
    }

    @Test("into-array 2-arity accepts and ignores a type argument")
    func intoArrayWithTypeArg() throws {
        #expect(try swish.eval("(alength (into-array :int [1 2 3]))") == .integer(3))
        #expect(try swish.eval("(aget (into-array :int [1 2 3]) 2)") == .integer(3))
    }

    @Test("into-array on a non-seqable argument throws")
    func intoArrayNonSeqableThrows() throws {
        #expect(throws: (any Error).self) { try swish.eval("(into-array 5)") }
    }
}
