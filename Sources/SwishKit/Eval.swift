/// Evaluates a Swish expression
public func eval(_ expr: Expr) -> Expr {
    switch expr {
    case .integer:
        return expr
    }
}
