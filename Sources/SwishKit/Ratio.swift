/// Represents a rational number (ratio) with automatic GCD reduction
public struct Ratio: Equatable, Hashable, Sendable {
    public let numerator: Int
    public let denominator: Int  // Always positive

    public init(_ numerator: Int, _ denominator: Int) {
        precondition(denominator != 0, "Ratio denominator cannot be zero")
        let g = Self.gcd(abs(numerator), abs(denominator))
        let sign = denominator < 0 ? -1 : 1
        self.numerator = sign * numerator / g
        self.denominator = abs(denominator) / g
    }

    private static func gcd(_ a: Int, _ b: Int) -> Int {
        var a = a, b = b
        while b != 0 { (a, b) = (b, a % b) }
        return a == 0 ? 1 : a
    }
}
