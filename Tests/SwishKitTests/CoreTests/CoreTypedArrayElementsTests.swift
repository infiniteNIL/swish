import Testing
@testable import SwishKit

/// Typed array constructors coerce their elements to the array's element type.
///
/// `SwishArray` still carries no element *tag* — that stays deferred — but each ctor now
/// converts what it is handed at construction, so `(float-array (range 3))` really holds
/// floats. Without it `(reduce + (float-array (range 50)))` summed to the integer `1225`
/// where Clojure gives `1225.0`, which is how the jank suite's rewritten `reduce` test
/// found this.
@Suite("Core Typed Array Element Tests", .serialized)
struct CoreTypedArrayElementsTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - Element type after construction from a seq

    @Test("float-array and double-array coerce integer input to floating point")
    func floatingPointCtors() throws {
        #expect(try swish.eval("(vec (double-array (range 3)))")
                == .vector([.double(0.0), .double(1.0), .double(2.0)], metadata: nil))
        #expect(try swish.eval("(vec (float-array (range 3)))")
                == .vector([.float(0.0), .float(1.0), .float(2.0)], metadata: nil))
        // The regression this fixes: the sum is a double, not an integer.
        #expect(try swish.eval("(reduce + (double-array (range 50)))") == .double(1225.0))
        #expect(try swish.eval("(reduce + (float-array (range 50)))") == .double(1225.0))
        #expect(try swish.eval("(reduce + 3 (double-array (range 50)))") == .double(1228.0))
    }

    @Test("The integral ctors truncate floating-point input toward zero")
    func integralCtors() throws {
        for ctor in ["int-array", "long-array", "short-array", "byte-array"] {
            #expect(try swish.eval("(vec (\(ctor) [1.9 2.9]))")
                    == .vector([.integer(1), .integer(2)], metadata: nil), "\(ctor)")
        }
    }

    @Test("char-array coerces code points, and still accepts a string")
    func charCtor() throws {
        #expect(try swish.eval("(vec (char-array [65 66]))")
                == .vector([.character("A"), .character("B")], metadata: nil))
        #expect(try swish.eval(#"(apply str (char-array "abc"))"#) == .string("abc"))
    }

    @Test("boolean-array coerces by truthiness, so only nil and false are false")
    func booleanCtor() throws {
        #expect(try swish.eval("(vec (boolean-array [nil 1 false 0 \"\"]))")
                == .vector([.boolean(false), .boolean(true), .boolean(false),
                            .boolean(true), .boolean(true)], metadata: nil))
    }

    @Test("object-array coerces nothing — an Object[] holds anything")
    func objectArrayIsUncoerced() throws {
        #expect(try swish.eval(#"(vec (object-array [1 "a" :k nil 2.5]))"#)
                == .vector([.integer(1), .string("a"), .keyword("k"), .nil, .double(2.5)],
                           metadata: nil))
    }

    // MARK: - The other two construction shapes

    @Test("A scalar fill is coerced too")
    func scalarFillIsCoerced() throws {
        #expect(try swish.eval("(vec (double-array 3 7))")
                == .vector([.double(7.0), .double(7.0), .double(7.0)], metadata: nil))
        #expect(try swish.eval("(vec (int-array 2 9.7))")
                == .vector([.integer(9), .integer(9)], metadata: nil))
    }

    /// Size plus a shorter seq: the supplied prefix is coerced and the tail takes the
    /// default fill, which is already of the element type.
    @Test("Size plus a short seq coerces the prefix and default-fills the tail")
    func sizePlusShortSeq() throws {
        #expect(try swish.eval("(vec (double-array 4 [1 2]))")
                == .vector([.double(1.0), .double(2.0), .double(0.0), .double(0.0)], metadata: nil))
        #expect(try swish.eval("(vec (char-array 3 [65]))")
                == .vector([.character("A"),
                            .character(Character(UnicodeScalar(0))),
                            .character(Character(UnicodeScalar(0)))], metadata: nil))
    }

    @Test("A bare size fills entirely with the element type's default")
    func bareSize() throws {
        #expect(try swish.eval("(vec (double-array 2))")
                == .vector([.double(0.0), .double(0.0)], metadata: nil))
        #expect(try swish.eval("(vec (boolean-array 2))")
                == .vector([.boolean(false), .boolean(false)], metadata: nil))
        #expect(try swish.eval("(count (char-array 3))") == .integer(3))
        #expect(try swish.eval("(vec (int-array 0))") == .vector([], metadata: nil))
    }

    // MARK: - Range checking comes along with the coercion

    @Test("The narrow integral ctors reject out-of-range values, as Clojure does")
    func rangeChecks() throws {
        #expect(throws: (any Error).self) { try swish.eval("(byte-array [200])") }
        #expect(throws: (any Error).self) { try swish.eval("(byte-array [-200])") }
        #expect(throws: (any Error).self) { try swish.eval("(short-array [70000])") }
        // In range: no throw.
        #expect(try swish.eval("(vec (byte-array [127 -128]))")
                == .vector([.integer(127), .integer(-128)], metadata: nil))
    }

    @Test("A value the element type cannot represent throws")
    func uncoercibleElements() throws {
        #expect(throws: (any Error).self) { try swish.eval("(int-array [:k])") }
        #expect(throws: (any Error).self) { try swish.eval(#"(double-array ["x"])"#) }
        #expect(throws: (any Error).self) { try swish.eval("(char-array [:k])") }
    }

    // MARK: - What the missing element tag still costs

    /// Coercion is construction-time only. `SwishArray` has no element type to check
    /// against, so `aset` will happily store a value of any type afterwards — the
    /// documented limitation that keeps `bytes?` unimplemented.
    @Test("aset is still unchecked — no element-type tag exists to validate against")
    func asetRemainsUnchecked() throws {
        _ = try swish.eval("(def da (double-array 2))")
        #expect(try swish.eval("(aset da 0 :not-a-double)") == .keyword("not-a-double"))
        #expect(try swish.eval("(aget da 0)") == .keyword("not-a-double"))
    }
}
