import Testing
@testable import SwishKit

@Suite("Protocols on built-in types Tests", .serialized)
struct CoreProtocolBuiltinTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - extend-type onto concrete built-ins

    @Test("extend-type onto String dispatches on a string value")
    func extendString() throws {
        _ = try swish.eval("(defprotocol BP1 (bp1 [x]))")
        _ = try swish.eval("(extend-type String BP1 (bp1 [s] (count s)))")
        #expect(try swish.eval(#"(bp1 "abcd")"#) == .integer(4))
    }

    @Test("extend-type onto Int, Vector, Map, Keyword dispatch on matching values")
    func extendVariousConcreteTypes() throws {
        _ = try swish.eval("(defprotocol BP2 (bp2 [x]))")
        _ = try swish.eval("""
            (extend-type Int BP2 (bp2 [n] (* n 10)))
            (extend-type Vector BP2 (bp2 [v] (count v)))
            (extend-type Map BP2 (bp2 [m] :a-map))
            (extend-type Keyword BP2 (bp2 [k] :a-keyword))
            """)
        #expect(try swish.eval("(bp2 7)") == .integer(70))
        #expect(try swish.eval("(bp2 [1 2 3])") == .integer(3))
        #expect(try swish.eval("(bp2 {:a 1})") == .keyword("a-map"))
        #expect(try swish.eval("(bp2 :xyz)") == .keyword("a-keyword"))
    }

    @Test("extend-protocol onto multiple built-ins in one form")
    func extendProtocolMultipleBuiltins() throws {
        _ = try swish.eval("(defprotocol BP3 (bp3 [x]))")
        _ = try swish.eval("(extend-protocol BP3 Int (bp3 [n] :int) Double (bp3 [n] :double))")
        #expect(try swish.eval("(bp3 5)") == .keyword("int"))
        #expect(try swish.eval("(bp3 5.0)") == .keyword("double"))
    }

    @Test("extend (function form) onto a built-in via a method map")
    func extendFunctionFormOnBuiltin() throws {
        _ = try swish.eval("(defprotocol BP4 (bp4 [x]))")
        _ = try swish.eval("(extend String BP4 {:bp4 (fn [s] (str s \"!\"))})")
        #expect(try swish.eval(#"(bp4 "hi")"#) == .string("hi!"))
    }

    // MARK: - Number / Object hierarchy fan-out

    @Test("Number fans out to every numeric type")
    func numberFanOut() throws {
        _ = try swish.eval("(defprotocol BP5 (bp5 [x]))")
        _ = try swish.eval("(extend-type Number BP5 (bp5 [n] :num))")
        #expect(try swish.eval("(bp5 3)") == .keyword("num"))      // integer
        #expect(try swish.eval("(bp5 3.5)") == .keyword("num"))    // double
        #expect(try swish.eval("(bp5 1/2)") == .keyword("num"))    // ratio
        #expect(try swish.eval("(bp5 (bigint 9))") == .keyword("num"))
        #expect(try swish.eval("(bp5 (bigdec 9))") == .keyword("num"))
    }

    @Test("Object is a default for all non-nil values")
    func objectDefault() throws {
        _ = try swish.eval("(defprotocol BP6 (bp6 [x]))")
        _ = try swish.eval("(extend-protocol BP6 Object (bp6 [_] :other))")
        #expect(try swish.eval(#"(bp6 "s")"#) == .keyword("other"))
        #expect(try swish.eval("(bp6 42)") == .keyword("other"))
        #expect(try swish.eval("(bp6 [])") == .keyword("other"))
        #expect(try swish.eval("(bp6 :k)") == .keyword("other"))
    }

    @Test("a more-specific impl wins over Number and Object")
    func specificWinsOverHierarchy() throws {
        _ = try swish.eval("(defprotocol BP7 (bp7 [x]))")
        _ = try swish.eval("""
            (extend-protocol BP7
              String (bp7 [_] :string)
              Number (bp7 [_] :number)
              Object (bp7 [_] :object))
            """)
        #expect(try swish.eval(#"(bp7 "s")"#) == .keyword("string"))  // exact String
        #expect(try swish.eval("(bp7 42)") == .keyword("number"))     // Number, not Object
        #expect(try swish.eval("(bp7 [])") == .keyword("object"))     // Object fallback
    }

    @Test("Object does not catch nil; nil is extended separately")
    func objectDoesNotCatchNil() throws {
        _ = try swish.eval("(defprotocol BP8 (bp8 [x]))")
        _ = try swish.eval("(extend-protocol BP8 Object (bp8 [_] :object))")
        // nil has no Object fallback, and no nil impl yet -> throws.
        #expect(throws: (any Error).self) { try swish.eval("(bp8 nil)") }
        _ = try swish.eval("(extend-type nil BP8 (bp8 [_] :nil-impl))")
        #expect(try swish.eval("(bp8 nil)") == .keyword("nil-impl"))
    }

    // MARK: - satisfies? / instance? / extends? respect the hierarchy

    @Test("satisfies? is true via exact type, via Number, and via Object")
    func satisfiesHierarchy() throws {
        _ = try swish.eval("(defprotocol BP9 (bp9 [x]))")
        _ = try swish.eval("(defprotocol BP9b (bp9b [x]))")
        _ = try swish.eval("(extend-type String BP9 (bp9 [_] 1))")
        _ = try swish.eval("(extend-type Number BP9 (bp9 [_] 2))")
        _ = try swish.eval("(extend-type Object BP9b (bp9b [_] 3))")
        #expect(try swish.eval(#"(satisfies? BP9 "s")"#) == .boolean(true))   // exact String
        #expect(try swish.eval("(satisfies? BP9 42)") == .boolean(true))      // via Number
        #expect(try swish.eval("(satisfies? BP9 :k)") == .boolean(false))     // keyword, unextended
        #expect(try swish.eval("(satisfies? BP9b :k)") == .boolean(true))     // via Object
        #expect(try swish.eval("(satisfies? BP9b nil)") == .boolean(false))   // nil not an Object
    }

    @Test("instance? respects the built-in hierarchy")
    func instanceHierarchy() throws {
        #expect(try swish.eval(#"(instance? String "x")"#) == .boolean(true))
        #expect(try swish.eval("(instance? Number 3)") == .boolean(true))
        #expect(try swish.eval("(instance? Number 3.5)") == .boolean(true))
        #expect(try swish.eval("(instance? Object 3)") == .boolean(true))
        #expect(try swish.eval("(instance? Object nil)") == .boolean(false))
        #expect(try swish.eval(#"(instance? Int "x")"#) == .boolean(false))
    }

    @Test("extends? is true for a numeric type when only Number is extended")
    func extendsHierarchy() throws {
        _ = try swish.eval("(defprotocol BP10 (bp10 [x]))")
        _ = try swish.eval("(extend-type Number BP10 (bp10 [_] :n))")
        #expect(try swish.eval("(extends? BP10 Number)") == .boolean(true))
        #expect(try swish.eval("(extends? BP10 Int)") == .boolean(true))     // via Number
        #expect(try swish.eval("(extends? BP10 Double)") == .boolean(true))  // via Number
        #expect(try swish.eval("(extends? BP10 String)") == .boolean(false))
    }

    // MARK: - Swift-name scheme

    @Test("built-in type names are Swift-named and bound to their dispatch keyword")
    func swiftNamedTypeVars() throws {
        #expect(try swish.eval("(= String :string)") == .boolean(true))
        #expect(try swish.eval("(= Int :integer)") == .boolean(true))
        #expect(try swish.eval("(= Bool :boolean)") == .boolean(true))
        #expect(try swish.eval("(= Double :double)") == .boolean(true))
        // Java names are deliberately not provided.
        #expect(throws: (any Error).self) { try swish.eval("Long") }
        #expect(throws: (any Error).self) { try swish.eval("Boolean") }
    }

    @Test("extend-type onto Bool dispatches on a boolean value")
    func extendBool() throws {
        _ = try swish.eval("(defprotocol BP11 (bp11 [x]))")
        _ = try swish.eval("(extend-type Bool BP11 (bp11 [b] (if b :yes :no)))")
        #expect(try swish.eval("(bp11 true)") == .keyword("yes"))
        #expect(try swish.eval("(bp11 false)") == .keyword("no"))
    }
}
