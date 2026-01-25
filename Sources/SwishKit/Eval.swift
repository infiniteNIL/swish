/// Evaluates a Swish expression
public func evaluate(_ expr: Expr) -> Expr {
    switch expr {
    case .integer:
        return expr
    }
}
