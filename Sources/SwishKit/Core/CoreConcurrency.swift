import Foundation

// MARK: - Registration

func registerConcurrency(into evaluator: Evaluator) {
    // MARK: Future

    evaluator.register(name: "future-call", arity: .fixed(1),
        doc: "Takes a function of no args and yields a future object that will invoke the function in another thread, and will cache the result and return it on all subsequent calls to deref. If the computation has not yet finished, calls to deref will block, unless the variant of deref with timeout is used.",
        arglists: [["f"]]) { [evaluator] args in
        let box = FutureBox()
        let frames = evaluator.captureCurrentBindings()
        let fn = args[0]
        box.run(evaluator: evaluator, frames: frames) { try evaluator.call(fn, args: []) }
        return .future(box)
    }
    evaluator.register(name: "future-cancel", arity: .fixed(1),
        doc: "Cancels the future, if possible.",
        arglists: [["f"]]) { args in
        guard case .future(let box) = args[0] else {
            throw EvaluatorError.invalidArgument(function: "future-cancel", message: "first argument must be a future")
        }
        return .boolean(box.cancel())
    }
    evaluator.register(name: "future-cancelled?", arity: .fixed(1),
        doc: "Returns true if the future has been cancelled.",
        arglists: [["f"]]) { args in
        guard case .future(let box) = args[0] else {
            throw EvaluatorError.invalidArgument(function: "future-cancelled?", message: "first argument must be a future")
        }
        return .boolean(box.isCancelled)
    }
    evaluator.register(name: "future-done?", arity: .fixed(1),
        doc: "Returns true if the future is done executing (cancelled, completed, or errored).",
        arglists: [["f"]]) { args in
        guard case .future(let box) = args[0] else {
            throw EvaluatorError.invalidArgument(function: "future-done?", message: "first argument must be a future")
        }
        return .boolean(box.isRealized)
    }
    evaluator.register(name: "future?", arity: .fixed(1),
        doc: "Returns true if x is a future.",
        arglists: [["x"]]) { args in
        if case .future = args[0] { return .boolean(true) }
        return .boolean(false)
    }

    // MARK: Promise

    evaluator.register(name: "promise", arity: .fixed(0),
        doc: "Returns a promise object that can be read with deref/@, and set, once only, with deliver. Calls to deref/@ prior to delivery will block, unless the variant of deref with timeout is used. All subsequent derefs will return the same delivered value without blocking.",
        arglists: [[]]) { _ in .promise(PromiseBox()) }
    evaluator.register(name: "deliver", arity: .fixed(2),
        doc: "Delivers the supplied value to the promise, releasing any pending derefs. A subsequent call to deliver on a promise that has already been delivered is a no-op and returns nil.",
        arglists: [["promise", "val"]]) { args in
        guard case .promise(let box) = args[0] else {
            throw EvaluatorError.invalidArgument(function: "deliver", message: "first argument must be a promise")
        }
        return box.deliver(args[1]) ? args[0] : .nil
    }

    // MARK: sleep (backs the jank suite's `sleep` portability shim)

    evaluator.register(name: "swish-sleep!", arity: .fixed(1),
        doc: "Blocks the current thread for approximately ms milliseconds. Polls a cancellation check installed by future-call, so a cancelled future's sleep exits early.",
        arglists: [["ms"]]) { [evaluator] args in
        guard case .integer(let ms) = args[0] else {
            throw EvaluatorError.invalidArgument(function: "swish-sleep!", message: "argument must be an integer")
        }
        let deadline = Date().addingTimeInterval(Double(ms) / 1000)
        let tick = 0.02
        while Date() < deadline {
            if evaluator.currentCancellationCheck?() == true { break }
            Thread.sleep(forTimeInterval: min(tick, deadline.timeIntervalSinceNow))
        }
        return .nil
    }

    // MARK: Agent

    evaluator.register(name: "agent", arity: .atLeastOne,
        doc: "Creates and returns an agent with an initial value of state and zero or more options (in any order): :meta metadata-map, :validator validate-fn. If metadata-map is supplied, it will become the metadata on the agent. validate-fn must be nil or a side-effect-free fn of one argument, which will be passed the intended new state on any state change.",
        arglists: [["state"], ["state", "&", "options"]]) { [evaluator] args in try coreAgent(evaluator, args) }
    evaluator.register(name: "agent?", arity: .fixed(1),
        doc: "Returns true if x is an agent.",
        arglists: [["x"]]) { args in
        if case .agent = args[0] { return .boolean(true) }
        return .boolean(false)
    }
    evaluator.register(name: "send", arity: .atLeastOne,
        doc: "Dispatches an action to an agent. Returns the agent immediately. Actions are run in order, and only one at a time per agent.",
        arglists: [["a", "f"], ["a", "f", "&", "args"]]) { [evaluator] args in try coreSend(evaluator, args) }
    evaluator.register(name: "send-off", arity: .atLeastOne,
        doc: "Dispatches an action to an agent, same semantics as send in this implementation.",
        arglists: [["a", "f"], ["a", "f", "&", "args"]]) { [evaluator] args in try coreSend(evaluator, args) }
    evaluator.register(name: "await", arity: .atLeastOne,
        doc: "Blocks the current thread until all actions dispatched thus far to each of the agents have occurred.",
        arglists: [["&", "agents"]]) { [evaluator] args in
        for a in args {
            guard case .agent(let agent) = a else {
                throw EvaluatorError.invalidArgument(function: "await", message: "argument must be an agent, got \(corePrinter.printString(a))")
            }
            agent.await(evaluator: evaluator, agentExpr: a)
        }
        return .nil
    }
    evaluator.register(name: "agent-error", arity: .fixed(1),
        doc: "Returns the exception thrown during an asynchronous action of the agent if the agent is failed, else nil.",
        arglists: [["a"]]) { args in
        guard case .agent(let agent) = args[0] else {
            throw EvaluatorError.invalidArgument(function: "agent-error", message: "argument must be an agent")
        }
        return agent.error ?? .nil
    }
    evaluator.register(name: "restart-agent", arity: .fixed(2),
        doc: "When an agent is failed, changes the agent state to new-state and then un-fails the agent so that sends are allowed again.",
        arglists: [["a", "new-state"]]) { args in
        guard case .agent(let agent) = args[0] else {
            throw EvaluatorError.invalidArgument(function: "restart-agent", message: "first argument must be an agent")
        }
        agent.restart(newValue: args[1])
        return args[1]
    }

    // MARK: bound-fn*

    evaluator.register(name: "bound-fn*", arity: .fixed(1),
        doc: "Returns a function, which will install the same bindings in effect as in the thread at the time bound-fn* was called and then call f with any given arguments.",
        arglists: [["f"]]) { [evaluator] args in
        let fn = args[0]
        let capturedFrames = evaluator.captureCurrentBindings()
        return .nativeFunction(name: "bound-fn", arity: .variadic) { callArgs in
            // Merge (not replace) onto whatever's active on the calling thread right
            // now — matches real Clojure's push-thread-bindings, which layers the
            // captured frame's entries on top of the current frame rather than
            // wholesale resetting it (unlike future/send's binding-conveyor-fn,
            // which does reset — futures run on a fresh/pooled thread with no
            // relevant "current" context to preserve). Vars present in the captured
            // frame override; vars absent from it fall through to whatever's
            // currently bound on the calling thread.
            let currentFrames = evaluator.bindingFrames
            return try evaluator.withInstalledBindings(currentFrames + capturedFrames, callDepth: evaluator.callDepth) {
                try evaluator.call(fn, args: callArgs)
            }
        }
    }
}

// MARK: - Helpers

private func coreAgent(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    let initialValue = args[0]
    var agentMeta: [Expr: Expr]? = nil
    var agentValidator: Expr? = nil

    var i = 1
    while i + 1 < args.count {
        let key = args[i]
        let val = args[i + 1]
        if key == .keyword("meta") {
            switch val {
            case .map(let sm):
                agentMeta = sm.dict
            case .sortedMap(let m, _):
                agentMeta = m
            case .nil:
                agentMeta = nil
            default:
                throw EvaluatorError.invalidArgument(function: "agent",
                    message: "metadata must be a map or nil, got \(corePrinter.printString(val))")
            }
        }
        else if key == .keyword("validator") {
            agentValidator = (val == .nil) ? nil : val
        }
        i += 2
    }

    let a = SwishAgent(initialValue, metadata: agentMeta, validator: agentValidator)
    if let vf = agentValidator {
        try checkValidator(evaluator, fn: vf, value: initialValue, context: "agent")
    }
    return .agent(a)
}

private func coreSend(_ evaluator: Evaluator, _ args: [Expr]) throws -> Expr {
    guard args.count >= 2 else {
        throw EvaluatorError.invalidArgument(function: "send", message: "requires at least 2 arguments")
    }
    guard case .agent(let a) = args[0] else {
        throw EvaluatorError.invalidArgument(function: "send", message: "first argument must be an agent, got \(corePrinter.printString(args[0]))")
    }
    a.enqueue(evaluator: evaluator, agentExpr: args[0], actionFn: args[1], extraArgs: Array(args.dropFirst(2)))
    return args[0]
}
