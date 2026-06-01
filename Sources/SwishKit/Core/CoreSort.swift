// MARK: - Registration

func registerSort(into evaluator: Evaluator) {
    evaluator.register(name: "sort", arity: .atLeastOne,
        doc: "Returns a sorted sequence of the items in coll. comp can be a boolean-valued comparison function, or a -/0/+ valued comparator. Comp defaults to compare.",
        arglists: [["coll"], ["comp", "coll"]]) { [evaluator] args in try coreSort(evaluator, args) }
}

// MARK: - Implementation

private func coreSort(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    let compExpr: Expr?
    let collExpr: Expr
    switch args.count {
    case 1:
        compExpr = nil
        collExpr = args[0]

    default:
        compExpr = args[0]
        collExpr = args[1]
    }

    let elements = try seqOf(collExpr, function: "sort")
    let sorted = try elements.sorted { a, b in
        if let comp = compExpr {
            let result = try evaluator.call(comp, args: [b, a])
            switch result {
            case .integer(let n):
                return n > 0

            case .boolean(let v):
                return !v

            default:
                throw EvaluatorError.invalidArgument(function: "sort",
                    message: "comparator must return an integer or boolean")
            }
        } else {
            return try compareExprValue(a, b) < 0
        }
    }
    return .list(sorted, metadata: nil)
}
