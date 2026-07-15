import Testing
@testable import SwishKit

@Suite("Core Ref Tests", .serialized)
struct CoreRefTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - ref creation and deref

    @Test("(deref (ref 42)) returns initial value")
    func derefReturnsInitialValue() throws {
        #expect(try swish.eval("(deref (ref 42))") == .integer(42))
    }

    @Test("@r returns ref value via reader macro")
    func atReaderMacroDeref() throws {
        #expect(try swish.eval("(def r (ref 42)) @r") == .integer(42))
    }

    @Test("ref? returns true for refs")
    func refPredicateTrue() throws {
        #expect(try swish.eval("(ref? (ref 1))") == .boolean(true))
    }

    @Test("ref? returns false for non-refs")
    func refPredicateFalse() throws {
        #expect(try swish.eval("(ref? 42)") == .boolean(false))
        #expect(try swish.eval("(ref? (atom 42))") == .boolean(false))
    }

    @Test("deref inside a transaction returns the in-progress value")
    func derefInsideTransactionReturnsInProgressValue() throws {
        #expect(try swish.eval("""
            (def r (ref 1))
            (dosync (ref-set r 5) @r)
            """) == .integer(5))
    }

    // MARK: - ref-set / alter / commute / ensure

    @Test("ref-set changes the ref's value inside a transaction")
    func refSetChangesValue() throws {
        #expect(try swish.eval("(def r (ref 1)) (dosync (ref-set r 99)) @r") == .integer(99))
    }

    @Test("ref-set returns the new value")
    func refSetReturnsNewValue() throws {
        #expect(try swish.eval("(def r (ref 0)) (dosync (ref-set r 7))") == .integer(7))
    }

    @Test("alter applies f to the current value")
    func alterAppliesF() throws {
        #expect(try swish.eval("(def r (ref 10)) (dosync (alter r + 5)) @r") == .integer(15))
    }

    @Test("alter returns the new value")
    func alterReturnsNewValue() throws {
        #expect(try swish.eval("(def r (ref 10)) (dosync (alter r * 2))") == .integer(20))
    }

    @Test("alter with no extra args")
    func alterNoExtraArgs() throws {
        #expect(try swish.eval("(def r (ref 10)) (dosync (alter r inc)) @r") == .integer(11))
    }

    @Test("commute behaves the same as alter")
    func commuteBehavesLikeAlter() throws {
        #expect(try swish.eval("(def r (ref 10)) (dosync (commute r + 5)) @r") == .integer(15))
        #expect(try swish.eval("(def r2 (ref 10)) (dosync (commute r2 inc))") == .integer(11))
    }

    @Test("ensure returns the current value and can be used inside a transaction")
    func ensureReturnsValue() throws {
        #expect(try swish.eval("(def r (ref 42)) (dosync (ensure r))") == .integer(42))
    }

    @Test("ref-set outside dosync throws")
    func refSetOutsideTransactionThrows() throws {
        #expect(throws: (any Error).self) { try swish.eval("(ref-set (ref 1) 2)") }
    }

    @Test("alter outside dosync throws")
    func alterOutsideTransactionThrows() throws {
        #expect(throws: (any Error).self) { try swish.eval("(alter (ref 1) inc)") }
    }

    @Test("commute outside dosync throws")
    func commuteOutsideTransactionThrows() throws {
        #expect(throws: (any Error).self) { try swish.eval("(commute (ref 1) inc)") }
    }

    @Test("ensure outside dosync throws")
    func ensureOutsideTransactionThrows() throws {
        #expect(throws: (any Error).self) { try swish.eval("(ensure (ref 1))") }
    }

    // MARK: - nested dosync

    @Test("nested dosync joins the outer transaction — single commit, watch fires once")
    func nestedDosyncJoinsOuterTransaction() throws {
        #expect(try swish.eval("""
            (def r (ref 1))
            (def calls (atom 0))
            (add-watch r :k (fn [k ref old new] (swap! calls inc)))
            (dosync (dosync (alter r inc)))
            [@r @calls]
            """) == .vector([.integer(2), .integer(1)], metadata: nil))
    }

    // MARK: - exceptions abort without retrying

    @Test("an exception thrown from the transaction body aborts and does not retry")
    func exceptionAbortsWithoutRetry() throws {
        #expect(try swish.eval("""
            (def r (ref 1))
            (def calls (atom 0))
            (try
              (dosync (swap! calls inc) (throw "boom") (alter r inc))
              (catch Exception e nil))
            [@calls @r]
            """) == .vector([.integer(1), .integer(1)], metadata: nil))
    }

    // MARK: - :meta / :validator options

    @Test("ref :meta sets metadata")
    func refMetaOption() throws {
        #expect(try swish.eval("(meta (ref 1 :meta {:foo \"bar\"}))") == .map([.keyword("foo"): .string("bar")], metadata: nil))
    }

    @Test("meta on ref with no metadata returns nil")
    func refNoMeta() throws {
        #expect(try swish.eval("(meta (ref 1))") == .nil)
    }

    @Test("get-validator returns nil when no validator set on a ref")
    func getValidatorNoneOnRef() throws {
        #expect(try swish.eval("(get-validator (ref 1))") == .nil)
    }

    @Test("get-validator returns the validator function set on a ref")
    func getValidatorSetOnRef() throws {
        #expect(try swish.eval("(nil? (get-validator (ref 1 :validator odd?)))") == .boolean(false))
    }

    @Test("ref :validator rejects invalid initial value")
    func refValidatorRejectsInitial() throws {
        #expect(throws: (any Error).self) { try swish.eval("(ref 2 :validator odd?)") }
    }

    @Test("ref :validator accepts valid initial value")
    func refValidatorAcceptsInitial() throws {
        #expect(try swish.eval("(deref (ref 1 :validator odd?))") == .integer(1))
    }

    @Test("alter runs validator and throws when result is invalid")
    func alterValidatorRejects() throws {
        #expect(throws: (any Error).self) { try swish.eval("(dosync (alter (ref 1 :validator odd?) + 1))") }
    }

    @Test("alter runs validator and accepts valid result")
    func alterValidatorAccepts() throws {
        #expect(try swish.eval("(dosync (alter (ref 1 :validator odd?) + 2))") == .integer(3))
    }

    // MARK: - watch notification

    @Test("add-watch fires once per successful commit with correct old/new")
    func addWatchFiresOnCommit() throws {
        #expect(try swish.eval("""
            (def log (atom nil))
            (def r (ref 1))
            (add-watch r :k (fn [k ref old new] (reset! log [k old new])))
            (dosync (alter r inc))
            @log
            """) == .vector([.keyword("k"), .integer(1), .integer(2)], metadata: nil))
    }

    @Test("remove-watch stops further notifications")
    func removeWatchStopsNotifications() throws {
        #expect(try swish.eval("""
            (def calls (atom 0))
            (def r (ref 1))
            (add-watch r :k (fn [k ref old new] (swap! calls inc)))
            (dosync (alter r inc))
            (remove-watch r :k)
            (dosync (alter r inc))
            @calls
            """) == .integer(1))
    }
}
