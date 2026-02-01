/// Evaluator for Swish expressions
public class Evaluator {
    public init() {}

    /// Evaluates a Swish expression
    public func eval(_ expr: Expr) -> Expr {
        switch expr {
        case .integer:
            return expr
        case .float:
            return expr
        case .ratio:
            return expr
        }
    }
}
