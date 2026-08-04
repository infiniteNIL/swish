import Testing
@testable import SwishKit

/// Mutable `deftype` fields (`^:unsynchronized-mutable` / `^:volatile-mutable`) and
/// the field form of `set!`. Each test evaluates a self-contained `(do …)` program.
@Suite("Evaluator mutable deftype field Tests", .serialized)
struct EvaluatorMutableDeftypeTests {
    static let _shared = Evaluator()
    var evaluator: Evaluator { Self._shared }

    // MARK: - Live reads

    @Test("a read after set! in the same method sees the new value")
    func readAfterSetIsLive() throws {
        let result = try evaluator.eval("""
            (do
              (defprotocol IAcc (add-twice [this x]))
              (deftype Acc [^:unsynchronized-mutable n]
                IAcc
                (add-twice [this x] (set! n (+ n x)) (set! n (+ n x)) n))
              (add-twice (->Acc 3) 10))
            """)
        #expect(result == .integer(23))
    }

    @Test("mutation persists across method calls")
    func mutationPersistsAcrossCalls() throws {
        let result = try evaluator.eval("""
            (do
              (defprotocol ICtr (bump [this]) (val [this]))
              (deftype Ctr [^:unsynchronized-mutable n]
                ICtr
                (bump [this] (set! n (inc n)))
                (val [this] n))
              (let [c (->Ctr 0)]
                (bump c) (bump c) (bump c)
                (val c)))
            """)
        #expect(result == .integer(3))
    }

    @Test("^:volatile-mutable behaves the same as ^:unsynchronized-mutable")
    func volatileMutableWorks() throws {
        let result = try evaluator.eval("""
            (do
              (defprotocol IVol (touch [this]) (peek-val [this]))
              (deftype Vol [^:volatile-mutable n]
                IVol
                (touch [this] (set! n (inc n)))
                (peek-val [this] n))
              (let [v (->Vol 41)] (touch v) (peek-val v)))
            """)
        #expect(result == .integer(42))
    }

    // MARK: - Identity semantics

    @Test("a mutable instance and its alias share storage and are = / identical?")
    func mutableInstanceHasIdentity() throws {
        #expect(try evaluator.eval("""
            (do
              (defprotocol IId (bump [this]) (val [this]))
              (deftype IdCtr [^:unsynchronized-mutable n]
                IId
                (bump [this] (set! n (inc n)))
                (val [this] n))
              (let [c (->IdCtr 0) alias c]
                (bump alias)
                [(val c) (= c alias) (identical? c alias)]))
            """) == .vector([.integer(1), .boolean(true), .boolean(true)], metadata: nil))
    }

    @Test("two separately-constructed mutable instances are not =")
    func distinctMutableInstancesNotEqual() throws {
        #expect(try evaluator.eval("""
            (do
              (defprotocol IEq2 (noop [this]))
              (deftype Eq2 [^:unsynchronized-mutable n] IEq2 (noop [this] n))
              (= (->Eq2 0) (->Eq2 0)))
            """) == .boolean(false))
    }

    @Test("mutable instances key a set by identity (same dedups, distinct don't)")
    func mutableInstancesKeyBySetIdentity() throws {
        #expect(try evaluator.eval("""
            (do
              (defprotocol ISet1 (noop [this]))
              (deftype SetT [^:unsynchronized-mutable n] ISet1 (noop [this] n))
              (let [c (->SetT 0)]
                [(count (set [c c])) (count (set [c (->SetT 0)]))]))
            """) == .vector([.integer(1), .integer(2)], metadata: nil))
    }

    // MARK: - Immutable fields alongside mutable

    @Test("an immutable field alongside a mutable one still reads correctly")
    func immutableAndMutableTogether() throws {
        #expect(try evaluator.eval("""
            (do
              (defprotocol IPair (touch [this]) (view [this]))
              (deftype Pear [label ^:volatile-mutable slot]
                IPair
                (touch [this] (set! slot (inc slot)))
                (view [this] [label slot]))
              (let [p (->Pear "hits" 41)] (touch p) (view p)))
            """) == .vector([.string("hits"), .integer(42)], metadata: nil))
    }

    @Test("a mutable deftype prints its current field values")
    func mutablePrintsCurrentValues() throws {
        #expect(try evaluator.eval("""
            (do
              (defprotocol IPr (touch [this]))
              (deftype Prn [label ^:volatile-mutable slot]
                IPr
                (touch [this] (set! slot (inc slot))))
              (let [p (->Prn "hits" 41)] (touch p) (pr-str p)))
            """) == .string("#Prn[\"hits\" 42]"))
    }

    // MARK: - set! separation

    @Test("set! of a dynamic var inside a method still uses the dynamic-var path")
    func dynamicVarSetInsideMethodStillWorks() throws {
        #expect(try evaluator.eval("""
            (do
              (def ^:dynamic *d* 0)
              (defprotocol IDyn (run-it [this]))
              (deftype Dyn [^:unsynchronized-mutable n]
                IDyn
                (run-it [this] (binding [*d* 1] (set! *d* 99) *d*)))
              (run-it (->Dyn 7)))
            """) == .integer(99))
    }

    // MARK: - Shadowing and boundaries

    @Test("a let binding shadows a mutable field name")
    func letShadowsFieldName() throws {
        #expect(try evaluator.eval("""
            (do
              (defprotocol IShad (shadowed [this]))
              (deftype Shad [^:unsynchronized-mutable n]
                IShad
                (shadowed [this] (let [n 5] n)))
              (shadowed (->Shad 7)))
            """) == .integer(5))
    }

    @Test("a mutable field read inside a nested fn is inaccessible (throws)")
    func nestedFnFieldAccessThrows() throws {
        _ = try evaluator.eval("""
            (do
              (defprotocol IClo (via-closure [this]))
              (deftype Clo [^:unsynchronized-mutable n]
                IClo
                (via-closure [this] ((fn [] n)))))
            """)
        #expect(throws: EvaluatorError.self) {
            try evaluator.eval("(via-closure (->Clo 1))")
        }
    }

    // MARK: - No regression for non-mutable types

    @Test("an immutable-only deftype keeps value equality")
    func immutableDeftypeKeepsValueEquality() throws {
        #expect(try evaluator.eval("""
            (do
              (deftype Point [x y])
              (= (->Point 1 2) (->Point 1 2)))
            """) == .boolean(true))
    }

    @Test("immutable-only deftype instances dedup by value in a set")
    func immutableDeftypeValueSetDedup() throws {
        #expect(try evaluator.eval("""
            (do
              (deftype Pt [x y])
              (count (set [(->Pt 1 2) (->Pt 1 2)])))
            """) == .integer(1))
    }

    @Test("reify still works (no mutable storage box)")
    func reifyStillWorks() throws {
        #expect(try evaluator.eval("""
            (do
              (defprotocol IRfy (rval [this]))
              (rval (reify IRfy (rval [this] :reified))))
            """) == .keyword("reified"))
    }
}
