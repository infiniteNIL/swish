import Testing
@testable import SwishKit

@Suite("Core bitwise Tests", .serialized)
struct CoreBitwiseTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    static let allOnesInt = -1
    static let checkerPos = 0x5555555555555555
    static let checkerNeg = -0x5555555555555556

    @Test("bit-and covers the jank fixture table")
    func bitAnd() throws {
        #expect(try swish.eval("(bit-and 12 9)") == .integer(8))
        #expect(try swish.eval("(bit-and 8 0xff)") == .integer(8))
        #expect(try swish.eval("(bit-and -1 0)") == .integer(0))
        #expect(try swish.eval("(bit-and 0 -1)") == .integer(0))
        #expect(try swish.eval("(bit-and -1 -1)") == .integer(Self.allOnesInt))
        #expect(try swish.eval("(bit-and \(Self.checkerPos) 0)") == .integer(0))
        #expect(try swish.eval("(bit-and \(Self.checkerPos) \(Self.checkerPos))") == .integer(Self.checkerPos))
        #expect(try swish.eval("(bit-and \(Self.checkerPos) -1)") == .integer(Self.checkerPos))
        #expect(try swish.eval("(bit-and \(Self.checkerPos) \(Self.checkerNeg))") == .integer(0))
    }

    @Test("bit-and-not covers the jank fixture table")
    func bitAndNot() throws {
        #expect(try swish.eval("(bit-and-not 0 0)") == .integer(0))
        #expect(try swish.eval("(bit-and-not 12 4)") == .integer(8))
        #expect(try swish.eval("(bit-and-not 0xff 0)") == .integer(0xff))
        #expect(try swish.eval("(bit-and-not 0xff 0x7f)") == .integer(0x80))
        #expect(try swish.eval("(bit-and-not -1 0)") == .integer(Self.allOnesInt))
        #expect(try swish.eval("(bit-and-not 0 -1)") == .integer(0))
        #expect(try swish.eval("(bit-and-not -1 -1)") == .integer(0))
        #expect(try swish.eval("(bit-and-not \(Self.checkerPos) 0)") == .integer(Self.checkerPos))
        #expect(try swish.eval("(bit-and-not \(Self.checkerPos) \(Self.checkerPos))") == .integer(0))
        #expect(try swish.eval("(bit-and-not \(Self.checkerPos) -1)") == .integer(0))
        #expect(try swish.eval("(bit-and-not \(Self.checkerPos) \(Self.checkerNeg))") == .integer(Self.checkerPos))
    }

    @Test("bit-clear clears the bit at index n")
    func bitClear() throws {
        #expect(try swish.eval("(bit-clear 11 3)") == .integer(3))
    }

    @Test("bit-flip toggles the bit at index n")
    func bitFlip() throws {
        #expect(try swish.eval("(bit-flip 2r1011 2)") == .integer(0b1111))
        #expect(try swish.eval("(bit-flip 2r1111 2)") == .integer(0b1011))
    }

    @Test("bit-not is bitwise complement")
    func bitNot() throws {
        #expect(try swish.eval("(bit-not 2r0111)") == .integer(-0b1000))
        #expect(try swish.eval("(bit-not -2r1000)") == .integer(0b0111))
    }

    @Test("bit-or covers the jank fixture table")
    func bitOr() throws {
        #expect(try swish.eval("(bit-or 2r1100 2r1001)") == .integer(0b1101))
        #expect(try swish.eval("(bit-or 1 0)") == .integer(1))
        #expect(try swish.eval("(bit-or \(Self.checkerPos) 0)") == .integer(Self.checkerPos))
        #expect(try swish.eval("(bit-or \(Self.checkerPos) \(Self.checkerPos))") == .integer(Self.checkerPos))
        #expect(try swish.eval("(bit-or -1 0)") == .integer(Self.allOnesInt))
        #expect(try swish.eval("(bit-or 0 -1)") == .integer(Self.allOnesInt))
        #expect(try swish.eval("(bit-or -1 -1)") == .integer(Self.allOnesInt))
        #expect(try swish.eval("(bit-or \(Self.checkerPos) -1)") == .integer(Self.allOnesInt))
        #expect(try swish.eval("(bit-or \(Self.checkerPos) \(Self.checkerNeg))") == .integer(Self.allOnesInt))
    }

    @Test("bit-set sets the bit at index n, wrapping at bit 63 (Long.MIN_VALUE)")
    func bitSet() throws {
        #expect(try swish.eval("(bit-set 2r1011 2)") == .integer(0b1111))
        #expect(try swish.eval("(bit-set 0 63)") == .integer(Int.min))
        #expect(try swish.eval("(bit-set 0 32)") == .integer(4294967296))
        #expect(try swish.eval("(bit-set 0 16)") == .integer(65536))
        #expect(try swish.eval("(bit-set 0 8)") == .integer(256))
        #expect(try swish.eval("(bit-set 0 4)") == .integer(16))
    }

    @Test("bit-shift-left shifts left")
    func bitShiftLeft() throws {
        #expect(try swish.eval("(bit-shift-left 1 10)") == .integer(1024))
        #expect(try swish.eval("(bit-shift-left 2r1101 2)") == .integer(0b110100))
    }

    @Test("bit-shift-right is an arithmetic (sign-extending) shift")
    func bitShiftRight() throws {
        #expect(try swish.eval("(bit-shift-right 2r1101 0)") == .integer(0b1101))
        #expect(try swish.eval("(bit-shift-right 2r1101 1)") == .integer(0b110))
        #expect(try swish.eval("(bit-shift-right 2r1101 2)") == .integer(0b11))
        #expect(try swish.eval("(bit-shift-right 2r1101 3)") == .integer(0b1))
        #expect(try swish.eval("(bit-shift-right 2r1101 4)") == .integer(0))
        #expect(try swish.eval("(bit-shift-right 2r1101 63)") == .integer(0))
    }

    @Test("bit-test checks each bit position")
    func bitTest() throws {
        #expect(try swish.eval("(bit-test 2r1001 0)") == .boolean(true))
        #expect(try swish.eval("(bit-test 2r1001 1)") == .boolean(false))
        #expect(try swish.eval("(bit-test 2r1001 2)") == .boolean(false))
        #expect(try swish.eval("(bit-test 2r1001 3)") == .boolean(true))
        #expect(try swish.eval("(bit-test 2r1001 4)") == .boolean(false))
        #expect(try swish.eval("(bit-test 2r1001 63)") == .boolean(false))
    }

    @Test("bit-xor covers the jank fixture table")
    func bitXor() throws {
        #expect(try swish.eval("(bit-xor 2r1100 2r1001)") == .integer(0b0101))
        #expect(try swish.eval("(bit-xor -1 0)") == .integer(Self.allOnesInt))
        #expect(try swish.eval("(bit-xor 0 -1)") == .integer(Self.allOnesInt))
        #expect(try swish.eval("(bit-xor -1 -1)") == .integer(0))
        #expect(try swish.eval("(bit-xor \(Self.checkerPos) 0)") == .integer(Self.checkerPos))
        #expect(try swish.eval("(bit-xor 0 \(Self.checkerPos))") == .integer(Self.checkerPos))
        #expect(try swish.eval("(bit-xor \(Self.checkerPos) -1)") == .integer(Self.checkerNeg))
        #expect(try swish.eval("(bit-xor \(Self.checkerPos) \(Self.checkerNeg))") == .integer(Self.allOnesInt))
    }

    @Test("unsigned-bit-shift-right is a logical (zero-filling) shift")
    func unsignedBitShiftRight() throws {
        #expect(try swish.eval("(unsigned-bit-shift-right -1 10)") == .integer(18014398509481983))
    }

    @Test("bit-and, bit-or, bit-xor, bit-and-not support 3+ variadic args")
    func variadicThreeArgs() throws {
        #expect(try swish.eval("(bit-and -1 3 6)") == .integer(2))
        #expect(try swish.eval("(bit-or 1 2 4)") == .integer(7))
        #expect(try swish.eval("(bit-xor 1 3 5)") == .integer(7))
        #expect(try swish.eval("(bit-and-not 0xff 0x0f 0xf0)") == .integer(0))
    }

    @Test("bit-and, bit-or, bit-xor, bit-and-not throw for fewer than 2 args")
    func variadicArityThrows() throws {
        #expect(throws: (any Error).self) { try swish.eval("(bit-and 1)") }
        #expect(throws: (any Error).self) { try swish.eval("(bit-or 1)") }
        #expect(throws: (any Error).self) { try swish.eval("(bit-xor 1)") }
        #expect(throws: (any Error).self) { try swish.eval("(bit-and-not 1)") }
    }

    @Test("all bit-* functions throw for nil operands")
    func nilOperandsThrow() throws {
        #expect(throws: (any Error).self) { try swish.eval("(bit-and nil 1)") }
        #expect(throws: (any Error).self) { try swish.eval("(bit-and 1 nil)") }
        #expect(throws: (any Error).self) { try swish.eval("(bit-and-not nil 1)") }
        #expect(throws: (any Error).self) { try swish.eval("(bit-and-not 1 nil)") }
        #expect(throws: (any Error).self) { try swish.eval("(bit-clear nil 1)") }
        #expect(throws: (any Error).self) { try swish.eval("(bit-flip nil 1)") }
        #expect(throws: (any Error).self) { try swish.eval("(bit-not nil)") }
        #expect(throws: (any Error).self) { try swish.eval("(bit-or nil 1)") }
        #expect(throws: (any Error).self) { try swish.eval("(bit-set nil 1)") }
        #expect(throws: (any Error).self) { try swish.eval("(bit-shift-left nil 1)") }
        #expect(throws: (any Error).self) { try swish.eval("(bit-shift-right nil 1)") }
        #expect(throws: (any Error).self) { try swish.eval("(bit-test nil 1)") }
        #expect(throws: (any Error).self) { try swish.eval("(bit-xor nil 1)") }
        #expect(throws: (any Error).self) { try swish.eval("(unsigned-bit-shift-right nil 1)") }
    }
}
