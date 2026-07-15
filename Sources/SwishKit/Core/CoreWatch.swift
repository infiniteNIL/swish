// MARK: - Registration

func registerWatch(into evaluator: Evaluator) {
    evaluator.register(name: "add-watch", arity: .fixed(3),
        doc: "Adds a watch function to an atom/var/agent/ref reference. The watch fn must be a fn of 4 args: key, reference, old-state, new-state. Whenever the reference's state changes, any registered watches will have their functions called. The 'key' is an arbitrary user-chosen key to identify this watch; add-watch of a key that already exists replaces that watch. Returns the reference.",
        arglists: [["reference", "key", "fn"]],
        body: coreAddWatch)
    evaluator.register(name: "remove-watch", arity: .fixed(2),
        doc: "Removes a watch (set by add-watch) from a reference. Returns the reference.",
        arglists: [["reference", "key"]],
        body: coreRemoveWatch)
}

// MARK: - Implementations

private func coreAddWatch(_ args: [Expr]) throws -> Expr {
    switch args[0] {
    case .atom(let a):
        a.addWatch(key: args[1], fn: args[2])

    case .varRef(let v):
        v.addWatch(key: args[1], fn: args[2])

    case .agent(let a):
        a.addWatch(key: args[1], fn: args[2])

    case .ref(let r):
        r.addWatch(key: args[1], fn: args[2])

    default:
        throw EvaluatorError.invalidArgument(
            function: "add-watch",
            message: "first argument must be an atom, var, agent, or ref, got \(corePrinter.printString(args[0]))")
    }
    return args[0]
}

private func coreRemoveWatch(_ args: [Expr]) throws -> Expr {
    switch args[0] {
    case .atom(let a):
        a.removeWatch(key: args[1])

    case .varRef(let v):
        v.removeWatch(key: args[1])

    case .agent(let a):
        a.removeWatch(key: args[1])

    case .ref(let r):
        r.removeWatch(key: args[1])

    default:
        throw EvaluatorError.invalidArgument(
            function: "remove-watch",
            message: "first argument must be an atom, var, agent, or ref, got \(corePrinter.printString(args[0]))")
    }
    return args[0]
}

/// Mirrors Clojure's ARef.notifyWatches: a plain loop with no per-watcher
/// try/catch, so an exception thrown by one watch fn propagates to the
/// caller and stops any remaining watches from firing.
func notifyWatches(_ evaluator: Evaluator, watches: [Expr: Expr], ref: Expr, old: Expr, new: Expr) throws {
    for (key, fn) in watches {
        _ = try evaluator.call(fn, args: [key, ref, old, new])
    }
}
