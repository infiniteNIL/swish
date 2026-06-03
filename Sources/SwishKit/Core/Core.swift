let corePrinter = Printer()

/// Registers all built-in functions into the evaluator's core environment.
func registerCoreFunctions(into evaluator: Evaluator) {
    registerArithmetic(into: evaluator)
    registerComparison(into: evaluator)
    registerMacros(into: evaluator)
    registerIO(into: evaluator)
    registerNamespace(into: evaluator)
    registerString(into: evaluator)
    registerPredicates(into: evaluator)
    registerSequence(into: evaluator)
    registerHOF(into: evaluator)
    registerMap(into: evaluator)
    registerSet(into: evaluator)
    registerMeta(into: evaluator)
    registerAtom(into: evaluator)
    registerTransient(into: evaluator)
    registerSort(into: evaluator)
    registerSwiftIONamespace(into: evaluator)
}
