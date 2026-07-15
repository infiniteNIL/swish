import Testing
@testable import SwishKit

@Suite("Core Agent Tests", .serialized)
struct CoreAgentTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    @Test("agent returns an agent object")
    func agentReturnsAgent() throws {
        let result = try swish.eval("(agent 1)")
        if case .agent = result { }
        else { Issue.record("Expected .agent, got \(result)") }
    }

    @Test("agent? recognizes an agent")
    func agentPredicate() throws {
        #expect(try swish.eval("(agent? (agent 1))") == .boolean(true))
        #expect(try swish.eval("(agent? 1)") == .boolean(false))
    }

    @Test("deref returns the agent's current value without blocking")
    func derefReturnsValue() throws {
        #expect(try swish.eval("(deref (agent 42))") == .integer(42))
    }

    @Test("send + await applies the action and updates the value")
    func sendAwaitUpdatesValue() throws {
        #expect(try swish.eval("""
            (def a (agent 1))
            (send a inc)
            (await a)
            @a
            """) == .integer(2))
    }

    @Test("send returns the agent immediately")
    func sendReturnsAgent() throws {
        #expect(try swish.eval("(def a (agent 1)) (= a (send a inc))") == .boolean(true))
    }

    @Test("send with extra args applies them after the current value")
    func sendWithExtraArgs() throws {
        #expect(try swish.eval("""
            (def a (agent 1))
            (send a + 10 100)
            (await a)
            @a
            """) == .integer(111))
    }

    @Test("agent-error is nil for a healthy agent")
    func agentErrorNilWhenHealthy() throws {
        #expect(try swish.eval("(agent-error (agent 1))") == .nil)
    }

    @Test("a throwing action fails the agent, agent-error captures it, and further sends no-op")
    func failedAgentRejectsSends() throws {
        #expect(try swish.eval("""
            (def a (agent 1))
            (send a (fn [x] (throw "boom")))
            (await a)
            (nil? (agent-error a))
            """) == .boolean(false))
        #expect(try swish.eval("""
            (send a inc)
            (await a)
            @a
            """) == .integer(1))
    }

    @Test("restart-agent clears the error and sets a new value, allowing sends again")
    func restartAgentClearsError() throws {
        #expect(try swish.eval("""
            (def a (agent 1))
            (send a (fn [x] (throw "boom")))
            (await a)
            (restart-agent a 5)
            (nil? (agent-error a))
            """) == .boolean(true))
        #expect(try swish.eval("""
            (send a inc)
            (await a)
            @a
            """) == .integer(6))
    }

    @Test("validator rejects an invalid new state and fails the agent")
    func validatorRejectsInvalidState() throws {
        #expect(try swish.eval("""
            (def a (agent 1 :validator odd?))
            (send a inc)
            (await a)
            (nil? (agent-error a))
            """) == .boolean(false))
    }

    @Test("add-watch fires on a real state change")
    func addWatchFiresOnChange() throws {
        // await's own no-op sentinel action also fires watches (old == new) —
        // see awaitFiresWatchesAsNoOp below — so filter to the real change,
        // matching the jank suite's own established convention for this.
        #expect(try swish.eval("""
            (def log (atom nil))
            (def a (agent 1))
            (add-watch a :k (fn [k r o n] (when (not= o n) (reset! log [k o n]))))
            (send a inc)
            (await a)
            @log
            """) == .vector([.keyword("k"), .integer(1), .integer(2)], metadata: nil))
    }

    @Test("await fires watches even for its own no-op sentinel action (old == new)")
    func awaitFiresWatchesAsNoOp() throws {
        #expect(try swish.eval("""
            (def calls (atom 0))
            (def a (agent 1))
            (add-watch a :k (fn [k r o n] (swap! calls inc)))
            (await a)
            @calls
            """) == .integer(1))
    }

    @Test("remove-watch stops further notifications")
    func removeWatchStopsNotifications() throws {
        #expect(try swish.eval("""
            (def calls (atom 0))
            (def a (agent 1))
            (add-watch a :k (fn [k r o n] (when (not= o n) (swap! calls inc))))
            (send a inc)
            (await a)
            (remove-watch a :k)
            (send a inc)
            (await a)
            @calls
            """) == .integer(1))
    }

    // MARK: - error-handler / error-mode

    @Test("error-handler is nil by default")
    func errorHandlerNilByDefault() throws {
        #expect(try swish.eval("(error-handler (agent 1))") == .nil)
    }

    @Test("set-error-handler!/error-handler roundtrip, including nil clearing")
    func setErrorHandlerRoundtrip() throws {
        #expect(try swish.eval("""
            (def a (agent 1))
            (set-error-handler! a (fn [ag ex] nil))
            (nil? (error-handler a))
            """) == .boolean(false))
        #expect(try swish.eval("""
            (set-error-handler! a nil)
            (error-handler a)
            """) == .nil)
    }

    @Test("error handler is called with [agent, exception] when an action throws")
    func errorHandlerInvokedOnThrow() throws {
        #expect(try swish.eval("""
            (def a (agent 1))
            (def log (atom nil))
            (set-error-handler! a (fn [ag ex] (reset! log [(= ag a) ex])))
            (send a (fn [x] (throw "boom")))
            (await a)
            @log
            """) == .vector([.boolean(true), .string("boom")], metadata: nil))
    }

    @Test("error-mode defaults to :fail")
    func errorModeDefaultsToFail() throws {
        #expect(try swish.eval("(error-mode (agent 1))") == .keyword("fail"))
    }

    @Test("set-error-mode!/error-mode roundtrip")
    func setErrorModeRoundtrip() throws {
        #expect(try swish.eval("""
            (def a (agent 1))
            (set-error-mode! a :continue)
            (error-mode a)
            """) == .keyword("continue"))
    }

    @Test("set-error-mode! rejects an invalid mode keyword")
    func setErrorModeRejectsInvalid() throws {
        #expect(throws: (any Error).self) { try swish.eval("(set-error-mode! (agent 1) :bogus)") }
    }

    @Test("error-mode defaults to :continue once an error-handler is set, with no explicit set-error-mode!")
    func errorModeDefaultsToContinueOnceHandlerSet() throws {
        #expect(try swish.eval("""
            (def a (agent 1))
            (set-error-handler! a (fn [ag ex] nil))
            (error-mode a)
            """) == .keyword("continue"))
    }

    @Test("clearing the handler reverts error-mode back to :fail, if never explicitly set")
    func errorModeRevertsToFailWhenHandlerCleared() throws {
        #expect(try swish.eval("""
            (def a (agent 1))
            (set-error-handler! a (fn [ag ex] nil))
            (set-error-handler! a nil)
            (error-mode a)
            """) == .keyword("fail"))
    }

    @Test("an explicit set-error-mode! wins over the handler-presence default, both directions")
    func explicitErrorModeWinsOverHandlerDefault() throws {
        #expect(try swish.eval("""
            (def a (agent 1))
            (set-error-mode! a :fail)
            (set-error-handler! a (fn [ag ex] nil))
            (error-mode a)
            """) == .keyword("fail"))
        #expect(try swish.eval("""
            (def b (agent 1))
            (set-error-handler! b (fn [ag ex] nil))
            (set-error-mode! b :fail)
            (set-error-handler! b nil)
            (error-mode b)
            """) == .keyword("fail"))
    }

    @Test("the dynamic :continue default actually swallows a throwing action's exception, not just the getter")
    func dynamicContinueDefaultActuallyContinuesProcessing() throws {
        #expect(try swish.eval("""
            (def a (agent 1))
            (set-error-handler! a (fn [ag ex] nil))
            (send a (fn [x] (throw "boom")))
            (send a inc)
            (await a)
            [(agent-error a) @a]
            """) == .vector([.nil, .integer(2)], metadata: nil))
    }

    @Test(":continue mode swallows a throwing action, leaves value unchanged, and keeps processing")
    func continueModeSwallowsException() throws {
        #expect(try swish.eval("""
            (def a (agent 1))
            (set-error-mode! a :continue)
            (send a (fn [x] (throw "boom")))
            (send a inc)
            (await a)
            [(agent-error a) @a]
            """) == .vector([.nil, .integer(2)], metadata: nil))
    }

    @Test(":fail mode (explicit) still fails the agent on a throwing action")
    func failModeExplicitStillFails() throws {
        #expect(try swish.eval("""
            (def a (agent 1))
            (set-error-mode! a :fail)
            (send a (fn [x] (throw "boom")))
            (await a)
            (nil? (agent-error a))
            """) == .boolean(false))
    }

    // MARK: - restart-agent validator + :clear-actions

    @Test("restart-agent throws when new-state fails the validator, and the agent remains failed")
    func restartAgentValidatorRejects() throws {
        _ = try swish.eval("""
            (def a (agent 1 :validator odd?))
            (send a (fn [x] (throw "boom")))
            (await a)
            """)
        #expect(throws: (any Error).self) { try swish.eval("(restart-agent a 2)") }
        #expect(try swish.eval("(nil? (agent-error a))") == .boolean(false))
    }

    @Test("restart-agent accepts :clear-actions true/false without erroring")
    func restartAgentAcceptsClearActionsOption() throws {
        #expect(try swish.eval("""
            (def a (agent 1))
            (send a (fn [x] (throw "boom")))
            (await a)
            (restart-agent a 5 :clear-actions true)
            @a
            """) == .integer(5))
        #expect(try swish.eval("""
            (def b (agent 1))
            (send b (fn [x] (throw "boom")))
            (await b)
            (restart-agent b 9 :clear-actions false)
            @b
            """) == .integer(9))
    }

    // MARK: - shutdown-agents

    @Test("shutdown-agents returns nil and doesn't prevent subsequent send/await")
    func shutdownAgentsIsNoOp() throws {
        #expect(try swish.eval("(shutdown-agents)") == .nil)
        #expect(try swish.eval("""
            (def a (agent 1))
            (send a inc)
            (await a)
            @a
            """) == .integer(2))
    }
}
