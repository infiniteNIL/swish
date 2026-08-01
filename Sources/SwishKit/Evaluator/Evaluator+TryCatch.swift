private struct CatchClause {
    let typeName: String
    let bindingName: String
    let body: [Expr]
}

/// `catch`-clause types that catch any thrown value. Swish has no throwable
/// hierarchy, so these are the universal catch-alls (as `Exception` always was).
private let catchAllTypeNames: Set<String> = ["Exception", "Throwable", "Error"]

extension Evaluator {

    // MARK: - throw / try

    func evalThrow(_ elements: [Expr], in env: Environment) throws -> Expr {
        guard elements.count == 2
        else {
            throw EvaluatorError.invalidArgument(function: "throw",
                                                 message: "requires exactly 1 argument")
        }
        throw SwishException(value: try eval(elements[1], in: env))
    }

    private func parseTryForm(
        _ elements: [Expr]
    ) throws -> (body: [Expr], catches: [CatchClause], finally: [Expr]) {
        var body: [Expr] = []
        var catches: [CatchClause] = []
        var finallyExprs: [Expr] = []
        var seenFinally = false

        for elem in elements.dropFirst() {
            if case .list(let inner, _) = elem, let head = inner.first {
                if case .symbol("catch", _) = head {
                    guard !seenFinally
                    else {
                        throw EvaluatorError.invalidArgument(function: "try",
                                                             message: "catch clause after finally")
                    }
                    guard inner.count >= 3,
                          case .symbol(let typeName, _) = inner[1],
                          case .symbol(let bindingName, _) = inner[2]
                    else {
                        throw EvaluatorError.invalidArgument(function: "catch",
                                                             message: "requires a type and binding name")
                    }
                    catches.append(CatchClause(typeName: typeName,
                                               bindingName: bindingName,
                                               body: Array(inner.dropFirst(3))))
                    continue
                }

                if case .symbol("finally", _) = head {
                    guard !seenFinally
                    else {
                        throw EvaluatorError.invalidArgument(function: "try",
                                                             message: "multiple finally clauses")
                    }
                    seenFinally = true
                    finallyExprs = Array(inner.dropFirst())
                    continue
                }
            }

            guard catches.isEmpty && !seenFinally
            else {
                throw EvaluatorError.invalidArgument(function: "try",
                                                     message: "body forms must appear before catch/finally")
            }
            body.append(elem)
        }

        return (body, catches, finallyExprs)
    }

    func evalTry(_ elements: [Expr], in env: Environment) throws -> Expr {
        let (body, catches, finallyExprs) = try parseTryForm(elements)
        var result: Expr = .nil
        var thrownError: Error? = nil

        do {
            result = try evalBody(body, in: env)
        }
        catch let signal as RecurSignal {
            throw signal
        }
        catch let e as EvaluatorError where e == .interrupted {
            throw e
        }
        catch {
            let thrownValue = exprForError(error)
            if let clause = catches.first(where: { catchClauseMatches($0.typeName, thrownValue: thrownValue, in: env) }) {
                do {
                    let catchEnv = Environment(parent: env)
                    catchEnv.set(clause.bindingName, thrownValue)
                    result = try evalBody(clause.body, in: catchEnv)
                }
                catch let catchBodyError {
                    thrownError = catchBodyError
                }
            }
            else {
                thrownError = error
            }
        }

        if !finallyExprs.isEmpty {
            _ = try evalBody(finallyExprs, in: env)
        }

        if let err = thrownError {
            throw err
        }
        return result
    }

    /// Whether a `catch` clause declaring `typeName` matches `thrownValue`, using the
    /// same type test as `instance?`: a catch-all name matches any value; otherwise
    /// the declared type symbol is resolved (eval → `dispatchTypeName`) and matched
    /// against the thrown value's type name (`Expr.description`) via `builtinAncestors`.
    /// Anything that doesn't resolve to a dispatchable type is a **non-match**, so an
    /// undefined / JVM class name (which Swish has no type for) propagates as before —
    /// e.g. native errors, stringified to type `string`, are caught only by a catch-all
    /// or a literal `(catch String e …)`.
    private func catchClauseMatches(_ typeName: String, thrownValue: Expr, in env: Environment) -> Bool {
        if catchAllTypeNames.contains(typeName) {
            return true
        }
        guard let typeExpr = try? eval(.symbol(typeName, metadata: nil), in: env),
              let dispatchName = try? dispatchTypeName(for: typeExpr, formName: "catch")
        else {
            return false
        }
        let valueType = thrownValue.description
        if valueType == dispatchName {
            return true
        }
        return builtinAncestors(ofTypeKeyword: valueType).contains(dispatchName)
    }

    func exprForError(_ error: Error) -> Expr {
        if let e = error as? SwishException {
            return e.value
        }
        return .string("\(error)")
    }
}
