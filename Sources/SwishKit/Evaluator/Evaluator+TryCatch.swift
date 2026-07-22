private struct CatchClause {
    let typeName: String
    let bindingName: String
    let body: [Expr]
}

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
            if let clause = catches.first(where: { $0.typeName == "Exception" }) {
                do {
                    let catchEnv = Environment(parent: env)
                    catchEnv.set(clause.bindingName, exprForError(error))
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

    func exprForError(_ error: Error) -> Expr {
        if let e = error as? SwishException {
            return e.value
        }
        return .string("\(error)")
    }
}
