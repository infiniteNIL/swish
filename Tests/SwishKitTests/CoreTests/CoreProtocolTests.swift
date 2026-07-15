import Testing
@testable import SwishKit

@Suite("Core Protocol Tests", .serialized)
struct CoreProtocolTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - defprotocol

    @Test("defprotocol creates a resolvable var bound to a protocol descriptor map")
    func defprotocolCreatesResolvableVar() throws {
        _ = try swish.eval("(defprotocol P1 (m1 [this]))")
        let result = try swish.eval("(map? P1)")
        #expect(result == .boolean(true))
    }

    @Test("defprotocol's dispatching functions have correct arglists metadata")
    func defprotocolMethodArglistsMetadata() throws {
        _ = try swish.eval("(defprotocol P2 (m2 [this] [this x]))")
        let result = try swish.eval("(:arglists (meta (var m2)))")
        #expect(result == .list([
            .vector([.symbol("this", metadata: nil)], metadata: nil),
            .vector([.symbol("this", metadata: nil), .symbol("x", metadata: nil)], metadata: nil),
        ], metadata: nil))
    }

    @Test("calling a protocol method with no implementation throws with the expected message shape")
    func noImplementationThrows() throws {
        _ = try swish.eval("(defprotocol P3 (m3 [this]))")
        #expect(throws: (any Error).self) { try swish.eval("(m3 42)") }
    }

    @Test("redefining a protocol preserves existing implementations")
    func redefinitionPreservesImpls() throws {
        _ = try swish.eval("""
            (defprotocol P4 (m4 [this]))
            (deftype P4Type [] P4 (m4 [this] :original))
            (defprotocol P4 (m4 [this]) (m4b [this]))
            """)
        #expect(try swish.eval("(m4 (->P4Type))") == .keyword("original"))
    }

    // MARK: - deftype

    @Test("deftype creates instances via the arrow constructor")
    func deftypeCreatesInstances() throws {
        _ = try swish.eval("(deftype DT1 [a b])")
        let result = try swish.eval("(->DT1 1 2)")
        if case .deftype(let t, let fields, let data, _) = result {
            #expect(t.hasSuffix("/DT1"))
            #expect(fields == ["a", "b"])
            #expect(data[.keyword("a")] == .integer(1))
            #expect(data[.keyword("b")] == .integer(2))
        } else {
            Issue.record("Expected .deftype, got \(result)")
        }
    }

    @Test("deftype method dispatches correctly, with unqualified field access")
    func deftypeMethodDispatchWithFieldAccess() throws {
        _ = try swish.eval("""
            (defprotocol P5 (area5 [this]))
            (deftype Rect5 [w h] P5 (area5 [this] (* w h)))
            """)
        #expect(try swish.eval("(area5 (->Rect5 3 4))") == .integer(12))
    }

    @Test("deftype method with multiple arities dispatches to the right one")
    func deftypeMultiArityMethod() throws {
        _ = try swish.eval("""
            (defprotocol P6 (greet6 [this] [this name]))
            (deftype Greeter6 [] P6
              (greet6 [this] "hi")
              (greet6 [this name] (str "hi " name)))
            """)
        #expect(try swish.eval("(greet6 (->Greeter6))") == .string("hi"))
        #expect(try swish.eval("(greet6 (->Greeter6) \"bob\")") == .string("hi bob"))
    }

    @Test("deftype instances are not map-like: map? is false")
    func deftypeNotMapLike() throws {
        _ = try swish.eval("(deftype DT2 [x])")
        #expect(try swish.eval("(map? (->DT2 1))") == .boolean(false))
    }

    @Test("deftype instances are not map-like: assoc throws")
    func deftypeAssocThrows() throws {
        _ = try swish.eval("(deftype DT3 [x])")
        #expect(throws: (any Error).self) { try swish.eval("(assoc (->DT3 1) :y 2)") }
    }

    @Test("deftype instances are not directly callable as a function")
    func deftypeNotCallable() throws {
        _ = try swish.eval("(deftype DT4 [x])")
        #expect(throws: (any Error).self) { try swish.eval("((->DT4 1) :x)") }
    }

    // MARK: - defrecord retrofit

    @Test("defrecord protocol methods dispatch correctly")
    func defrecordProtocolDispatch() throws {
        _ = try swish.eval("""
            (defprotocol P7 (area7 [this]))
            (defrecord Square7 [side] P7 (area7 [this] (* side side)))
            """)
        #expect(try swish.eval("(area7 (->Square7 5))") == .integer(25))
    }

    @Test("defrecord retrofit does not break existing map-like behavior")
    func defrecordRetrofitPreservesMapBehavior() throws {
        _ = try swish.eval("""
            (defprotocol P8 (area8 [this]))
            (defrecord Square8 [side] P8 (area8 [this] (* side side)))
            """)
        #expect(try swish.eval("(:side (->Square8 4))") == .integer(4))
        #expect(try swish.eval("(map? (->Square8 4))") == .boolean(true))
    }

    // MARK: - extend / extend-type / extend-protocol

    @Test("extend-type adds an implementation after the fact")
    func extendTypeAddsImpl() throws {
        _ = try swish.eval("""
            (defprotocol P9 (label9 [this]))
            (deftype ET1 [])
            (extend-type ET1 P9 (label9 [this] "labeled"))
            """)
        #expect(try swish.eval("(label9 (->ET1))") == .string("labeled"))
    }

    @Test("extend-protocol adds implementations for multiple types")
    func extendProtocolMultipleTypes() throws {
        _ = try swish.eval("""
            (defprotocol P10 (hello10 [this]))
            (deftype EP1 [])
            (deftype EP2 [])
            (extend-protocol P10
              EP1 (hello10 [this] "one")
              EP2 (hello10 [this] "two"))
            """)
        #expect(try swish.eval("(hello10 (->EP1))") == .string("one"))
        #expect(try swish.eval("(hello10 (->EP2))") == .string("two"))
    }

    @Test("extend adds an implementation via a raw method map, including onto nil")
    func extendRawMethodMap() throws {
        _ = try swish.eval("""
            (defprotocol P11 (present11? [this]))
            (extend nil P11 {:present11? (fn [this] false)})
            """)
        #expect(try swish.eval("(present11? nil)") == .boolean(false))
    }

    @Test("extend-over-extend replaces the implementation without throwing")
    func extendOverExtendReplaces() throws {
        _ = try swish.eval("""
            (defprotocol P12 (v12 [this]))
            (deftype ET2 [])
            (extend-type ET2 P12 (v12 [this] :v1))
            (extend-type ET2 P12 (v12 [this] :v2))
            """)
        #expect(try swish.eval("(v12 (->ET2))") == .keyword("v2"))
    }

    @Test("extend-type on a type that already inline-implements the same protocol throws")
    func inlineConflictThrows() throws {
        _ = try swish.eval("""
            (defprotocol P13 (v13 [this]))
            (deftype DT5 [] P13 (v13 [this] :inline))
            """)
        #expect(throws: (any Error).self) { try swish.eval("(extend-type DT5 P13 (v13 [this] :extended))") }
    }

    // MARK: - satisfies? / extends? / extenders / instance?

    @Test("satisfies? is true for a value whose type implements the protocol")
    func satisfiesTrueForImplementingValue() throws {
        _ = try swish.eval("""
            (defprotocol P14 (m14 [this]))
            (deftype DT6 [] P14 (m14 [this] nil))
            """)
        #expect(try swish.eval("(satisfies? P14 (->DT6))") == .boolean(true))
    }

    @Test("satisfies? is false for a value whose type does not implement the protocol")
    func satisfiesFalseForNonImplementingValue() throws {
        _ = try swish.eval("(defprotocol P15 (m15 [this]))")
        #expect(try swish.eval("(satisfies? P15 {:a 1})") == .boolean(false))
    }

    @Test("extends? checks a type, not a value")
    func extendsChecksType() throws {
        _ = try swish.eval("""
            (defprotocol P16 (m16 [this]))
            (deftype DT7 [] P16 (m16 [this] nil))
            """)
        #expect(try swish.eval("(extends? P16 DT7)") == .boolean(true))
    }

    @Test("extenders returns the extending types")
    func extendersReturnsTypes() throws {
        _ = try swish.eval("""
            (defprotocol P17 (m17 [this]))
            (deftype DT8 [] P17 (m17 [this] nil))
            """)
        #expect(try swish.eval("(= [DT8] (extenders P17))") == .boolean(true))
    }

    @Test("instance? checks exact type match")
    func instanceCheckExactType() throws {
        _ = try swish.eval("(deftype DT9 [])")
        _ = try swish.eval("(deftype DT10 [])")
        #expect(try swish.eval("(instance? DT9 (->DT9))") == .boolean(true))
        #expect(try swish.eval("(instance? DT9 (->DT10))") == .boolean(false))
    }
}
