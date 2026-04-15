/// Registers all built-in functions into the evaluator's core environment.
func registerCoreFunctions(into evaluator: Evaluator) {
    registerArithmetic(into: evaluator)
    registerComparison(into: evaluator)
    registerMacros(into: evaluator)
    registerIO(into: evaluator)
}
