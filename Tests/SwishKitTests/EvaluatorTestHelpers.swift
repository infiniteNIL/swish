@testable import SwishKit

extension Evaluator {
    func eval(_ source: String) throws -> Expr {
        let exprs = try Reader.readString(source)
        var result: Expr = .nil
        for expr in exprs { result = try eval(expr) }
        return result
    }
}
