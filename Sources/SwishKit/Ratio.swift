/// Represents a rational number (ratio) with automatic GCD reduction
public struct Ratio: Equatable, Hashable, Sendable {
    public let numerator: Int
    public let denominator: Int  // Always positive

    public init(_ numerator: Int, _ denominator: Int) {
        precondition(denominator != 0, "Ratio denominator cannot be zero")
        let absN = Self.magnitude(numerator)
        let absD = Self.magnitude(denominator)
        let g = Self.gcd(absN, absD)
        let sign = denominator < 0 ? -1 : 1
        self.numerator = sign * (numerator / Int(g))
        self.denominator = Int(absD / g)
    }

    // Returns the absolute value as UInt, safe even for Int.min.
    private static func magnitude(_ x: Int) -> UInt {
        if x >= 0 { return UInt(x) }
        if x == .min { return UInt(bitPattern: Int.min) }
        return UInt(-x)
    }

    private static func gcd(_ a: UInt, _ b: UInt) -> UInt {
        var a = a, b = b
        while b != 0 { (a, b) = (b, a % b) }
        return a == 0 ? 1 : a
    }
}
