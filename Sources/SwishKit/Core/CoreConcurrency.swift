import Foundation

// Single dedicated serial queue for all tap dispatch — matches real Clojure's
// single background tap-loop thread, so taps for a given tap> call always run
// after taps for an earlier one (real Clojure's tap-loop processes its queue
// strictly one value at a time).
private let tapQueue = DispatchQueue(label: "swish.tap")

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

    // MARK: Tap (backs tap>)

    evaluator.register(name: "tap-dispatch!", arity: .fixed(2),
        doc: "Internal. Asynchronously sends x to every function currently in the tapset atom, on a dedicated serial queue, catching and discarding any error each tap raises. Backs tap>.",
        arglists: [["tapset-atom", "x"]]) { [evaluator] args in
        guard case .atom(let tapsetAtom) = args[0] else {
            throw EvaluatorError.invalidArgument(function: "tap-dispatch!", message: "first argument must be an atom")
        }
        let x = args[1]
        let frames = evaluator.captureCurrentBindings()
        tapQueue.async {
            evaluator.withInstalledBindings(frames, callDepth: 0) {
                guard case .set(let ss) = tapsetAtom.value else { return }
                for tapFn in ss.elements {
                    _ = try? evaluator.call(tapFn, args: [x])
                }
            }
        }
        return .boolean(true)
    }

    // MARK: sleep (backs the jank suite's `sleep` portability shim)

    evaluator.register(name: "sleep!", arity: .fixed(1),
        doc: "Blocks the current thread for approximately ms milliseconds. Polls a cancellation check installed by future-call, so a cancelled future's sleep exits early.",
        arglists: [["ms"]]) { [evaluator] args in
        guard case .integer(let ms) = args[0] else {
            throw EvaluatorError.invalidArgument(function: "sleep!", message: "argument must be an integer")
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
    evaluator.register(name: "await-for", arity: .atLeastOne,
        doc: "Blocks the current thread until all actions dispatched thus far to each of the agents have occurred, or the timeout (in milliseconds) has elapsed. Returns false if it returned due to timeout, true otherwise.",
        arglists: [["timeout-ms", "&", "agents"]]) { [evaluator] args in
        guard case .integer(let ms) = args[0] else {
            throw EvaluatorError.invalidArgument(function: "await-for", message: "first argument must be an integer timeout in milliseconds")
        }
        let group = DispatchGroup()
        for a in args.dropFirst() {
            guard case .agent(let agent) = a else {
                throw EvaluatorError.invalidArgument(function: "await-for", message: "argument must be an agent, got \(corePrinter.printString(a))")
            }
            agent.awaitAsync(evaluator: evaluator, agentExpr: a, group: group)
        }
        let result = group.wait(timeout: .now() + .milliseconds(ms))
        return .boolean(result == .success)
    }
    evaluator.register(name: "agent-error", arity: .fixed(1),
        doc: "Returns the exception thrown during an asynchronous action of the agent if the agent is failed, else nil.",
        arglists: [["a"]]) { args in
        guard case .agent(let agent) = args[0] else {
            throw EvaluatorError.invalidArgument(function: "agent-error", message: "argument must be an agent")
        }
        return agent.error ?? .nil
    }
    evaluator.register(name: "restart-agent", arity: .atLeastOne,
        doc: "When an agent is failed, changes the agent state to new-state (which must pass the validator, if any) and then un-fails the agent so that sends are allowed again. Accepts an optional :clear-actions option for API compatibility; since Swish dispatches actions eagerly rather than holding a real backlog while failed, this implementation has no observable effect (see CLAUDE.md Known Limitations).",
        arglists: [["a", "new-state"], ["a", "new-state", "&", "options"]]) { [evaluator] args in
        guard args.count >= 2 else {
            throw EvaluatorError.invalidArgument(function: "restart-agent", message: "requires at least 2 arguments")
        }
        guard case .agent(let agent) = args[0] else {
            throw EvaluatorError.invalidArgument(function: "restart-agent", message: "first argument must be an agent")
        }
        var i = 2
        while i + 1 < args.count {
            if args[i] == .keyword("clear-actions") {
                guard case .boolean = args[i + 1] else {
                    throw EvaluatorError.invalidArgument(function: "restart-agent", message: ":clear-actions must be a boolean")
                }
            }
            i += 2
        }
        try agent.restart(evaluator: evaluator, newValue: args[1])
        return args[1]
    }
    evaluator.register(name: "set-error-handler!", arity: .fixed(2),
        doc: "Sets the error-handler of agent a to handler-fn (nil to clear). If an action run by the agent throws, handler-fn will be called with two arguments: the agent and the exception. Returns nil.",
        arglists: [["a", "handler-fn"]]) { args in
        guard case .agent(let agent) = args[0] else {
            throw EvaluatorError.invalidArgument(function: "set-error-handler!", message: "first argument must be an agent")
        }
        agent.errorHandler = (args[1] == .nil) ? nil : args[1]
        return .nil
    }
    evaluator.register(name: "error-handler", arity: .fixed(1),
        doc: "Returns the error-handler of agent a, or nil if there is none.",
        arglists: [["a"]]) { args in
        guard case .agent(let agent) = args[0] else {
            throw EvaluatorError.invalidArgument(function: "error-handler", message: "argument must be an agent")
        }
        return agent.errorHandler ?? .nil
    }
    evaluator.register(name: "set-error-mode!", arity: .fixed(2),
        doc: "Sets the error-mode of agent a to mode, which must be :continue or :fail. Overrides the dynamic default (see error-mode) regardless of whether an error-handler is set. In :fail mode, an action that throws fails the agent (further sends no-op until restart-agent). In :continue mode, the agent's value is left unchanged and processing continues with the next queued action. Returns nil.",
        arglists: [["a", "mode"]]) { args in
        guard case .agent(let agent) = args[0] else {
            throw EvaluatorError.invalidArgument(function: "set-error-mode!", message: "first argument must be an agent")
        }
        guard case .keyword(let k) = args[1], k == "continue" || k == "fail" else {
            throw EvaluatorError.invalidArgument(function: "set-error-mode!", message: "mode must be :continue or :fail")
        }
        agent.errorMode = args[1]
        return .nil
    }
    evaluator.register(name: "error-mode", arity: .fixed(1),
        doc: "Returns the error-mode of agent a (:continue or :fail). If never explicitly set via set-error-mode!, defaults to :continue once an error-handler has been set (see set-error-handler!), else :fail.",
        arglists: [["a"]]) { args in
        guard case .agent(let agent) = args[0] else {
            throw EvaluatorError.invalidArgument(function: "error-mode", message: "argument must be an agent")
        }
        return agent.errorMode
    }
    evaluator.register(name: "shutdown-agents", arity: .fixed(0),
        doc: "No-op in this implementation. Real Clojure shuts down the shared thread pools backing send/send-off; Swish instead dispatches each agent's actions on its own dedicated queue, so there is no shared executor to shut down. Provided for source compatibility with programs that call it defensively.",
        arglists: [[]]) { _ in .nil }

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
    let (agentMeta, agentValidator) = try parseMetaValidatorOptions(args, startingAt: 1, functionName: "agent")

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
