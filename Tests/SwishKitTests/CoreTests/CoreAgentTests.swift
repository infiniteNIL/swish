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
}
