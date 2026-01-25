import BigInt

/// Represents a Swish number - uses Int for small values, BigInt for large ones
public enum Number: Equatable, CustomStringConvertible {
    case int(Int)
    case bigInt(BigInt)

    public init(_ string: String) {
        if let value = Int(string) {
            self = .int(value)
        }
        else if let value = BigInt(string) {
            self = .bigInt(value)
        }
        else {
            self = .int(0)
        }
    }

    public var description: String {
        switch self {
        case .int(let value):
            return String(value)
        case .bigInt(let value):
            return String(value)
        }
    }
}
