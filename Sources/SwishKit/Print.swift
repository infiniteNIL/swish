/// Printer for Swish expressions
public class Printer {
    public init() {}

    /// Returns a human-readable string representation of a Swish expression
    public func printString(_ expr: Expr) -> String {
        switch expr {
        case .integer(let value):
            return String(value)
        }
    }
}
