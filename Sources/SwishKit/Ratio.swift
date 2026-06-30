import BigInt

/// Represents a rational number (ratio) with automatic GCD reduction
public struct Ratio: Equatable, Hashable, Sendable {
    public let numerator: BigInt
    public let denominator: BigInt  // Always positive

    public init(_ numerator: BigInt, _ denominator: BigInt) {
        precondition(denominator != 0, "Ratio denominator cannot be zero")
        let absN = numerator < 0 ? -numerator : numerator
        let absD = denominator < 0 ? -denominator : denominator
        let g = Self.gcd(absN, absD)
        let sign: BigInt = denominator < 0 ? -1 : 1
        self.numerator = sign * (numerator / g)
        self.denominator = absD / g
    }

    public init(_ numerator: Int, _ denominator: Int) {
        self.init(BigInt(numerator), BigInt(denominator))
    }

    private static func gcd(_ a: BigInt, _ b: BigInt) -> BigInt {
        var a = a, b = b
        while b != 0 { (a, b) = (b, a % b) }
        return a == 0 ? 1 : a
    }
}
