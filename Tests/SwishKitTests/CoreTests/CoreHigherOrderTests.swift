import Testing
@testable import SwishKit

@Suite("Core Higher Order Tests", .serialized)
struct CoreHigherOrderTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - identity

    @Test("(identity 42) returns 42")
    func identityInt() throws {
        #expect(try swish.eval("(identity 42)") == .integer(42))
    }

    @Test("(identity :foo) returns :foo")
    func identityKeyword() throws {
        #expect(try swish.eval("(identity :foo)") == .keyword("foo"))
    }

    @Test("(identity nil) returns nil")
    func identityNil() throws {
        #expect(try swish.eval("(identity nil)") == .nil)
    }

    @Test("(identity [1 2]) returns [1 2]")
    func identityVector() throws {
        #expect(try swish.eval("(identity [1 2])") == .vector([.integer(1), .integer(2)], metadata: nil))
    }

    // MARK: - complement

    @Test("((complement odd?) 2) returns true")
    func complementOddEven() throws {
        #expect(try swish.eval("((complement odd?) 2)") == .boolean(true))
    }

    @Test("((complement odd?) 3) returns false")
    func complementOddOdd() throws {
        #expect(try swish.eval("((complement odd?) 3)") == .boolean(false))
    }

    @Test("((complement nil?) 1) returns true")
    func complementNilNonNil() throws {
        #expect(try swish.eval("((complement nil?) 1)") == .boolean(true))
    }

    @Test("((complement nil?) nil) returns false")
    func complementNilNil() throws {
        #expect(try swish.eval("((complement nil?) nil)") == .boolean(false))
    }

    // MARK: - every?

    @Test("(every? odd? [1 3 5]) returns true")
    func everyAllOdd() throws {
        #expect(try swish.eval("(every? odd? [1 3 5])") == .boolean(true))
    }

    @Test("(every? odd? [1 2 3]) returns false")
    func everySomeEven() throws {
        #expect(try swish.eval("(every? odd? [1 2 3])") == .boolean(false))
    }

    @Test("(every? odd? []) returns true")
    func everyEmpty() throws {
        #expect(try swish.eval("(every? odd? [])") == .boolean(true))
    }

    @Test("(every? number? [1 2 3]) returns true")
    func everyNumbers() throws {
        #expect(try swish.eval("(every? number? [1 2 3])") == .boolean(true))
    }

    // MARK: - not-every?

    @Test("(not-every? even? [2 4 5]) returns true")
    func notEverySomeOdd() throws {
        #expect(try swish.eval("(not-every? even? [2 4 5])") == .boolean(true))
    }

    @Test("(not-every? even? [2 4 6]) returns false")
    func notEveryAllEven() throws {
        #expect(try swish.eval("(not-every? even? [2 4 6])") == .boolean(false))
    }

    @Test("(not-every? even? []) returns false")
    func notEveryEmpty() throws {
        #expect(try swish.eval("(not-every? even? [])") == .boolean(false))
    }

    // MARK: - some

    @Test("(some odd? [2 3 4]) returns truthy value")
    func someFindsOdd() throws {
        let result = try swish.eval("(some odd? [2 3 4])")
        #expect(result == .boolean(true))
    }

    @Test("(some odd? [2 4 6]) returns nil")
    func someNoMatch() throws {
        #expect(try swish.eval("(some odd? [2 4 6])") == .nil)
    }

    @Test("(some odd? []) returns nil")
    func someEmpty() throws {
        #expect(try swish.eval("(some odd? [])") == .nil)
    }

    @Test("(some identity [nil false 3]) returns 3")
    func someIdentity() throws {
        #expect(try swish.eval("(some identity [nil false 3])") == .integer(3))
    }

    // MARK: - constantly

    @Test("constantly returns a fn that always returns x regardless of args")
    func constantlyMultiArgs() throws {
        #expect(try swish.eval("((constantly 42) 1 2 3)") == .integer(42))
    }

    @Test("constantly with no args call returns x")
    func constantlyNoArgs() throws {
        #expect(try swish.eval("((constantly nil))") == .nil)
    }

    @Test("juxt is a function")
    func juxtIsFunction() throws {
        #expect(try swish.eval("(fn? juxt)") == .boolean(true))
    }

    @Test("(juxt inc dec) returns a function")
    func juxtReturnsFunction() throws {
        #expect(try swish.eval("(fn? (juxt inc dec))") == .boolean(true))
    }

    @Test("((juxt inc dec) 5) returns [6 4]")
    func juxtApplied() throws {
        #expect(try swish.eval("((juxt inc dec) 5)") == .vector([.integer(6), .integer(4)], metadata: nil))
    }

    @Test("((juxt + - *) 2 3) returns [5 -1 6]")
    func juxtMultipleArgs() throws {
        #expect(try swish.eval("((juxt + - *) 2 3)") == .vector([.integer(5), .integer(-1), .integer(6)], metadata: nil))
    }

    // MARK: - partial

    @Test("((partial + 5) 3) returns 8")
    func partialAddsArg() throws {
        #expect(try swish.eval("((partial + 5) 3)") == .integer(8))
    }

    @Test("((partial str \"hello-\") \"world\") returns concatenated string")
    func partialStr() throws {
        #expect(try swish.eval("((partial str \"hello-\") \"world\")") == .string("hello-world"))
    }

    @Test("(fn? (partial + 1)) returns true")
    func partialReturnsFn() throws {
        #expect(try swish.eval("(fn? (partial + 1))") == .boolean(true))
    }

    // MARK: - name

    @Test("(name :foo) returns \"foo\"")
    func nameKeyword() throws {
        #expect(try swish.eval("(name :foo)") == .string("foo"))
    }

    @Test("(name :ns/foo) returns \"foo\"")
    func nameNamespacedKeyword() throws {
        #expect(try swish.eval("(name :ns/foo)") == .string("foo"))
    }

    @Test("(name \"bar\") returns \"bar\"")
    func nameString() throws {
        #expect(try swish.eval("(name \"bar\")") == .string("bar"))
    }

    // MARK: - namespace

    @Test("(namespace :ns/foo) returns \"ns\"")
    func namespaceKeyword() throws {
        #expect(try swish.eval("(namespace :ns/foo)") == .string("ns"))
    }

    @Test("(namespace :foo) returns nil")
    func namespaceUnqualifiedKeyword() throws {
        #expect(try swish.eval("(namespace :foo)") == .nil)
    }

    @Test("(namespace \"foo\") returns nil")
    func namespaceString() throws {
        #expect(try swish.eval("(namespace \"foo\")") == .nil)
    }

    // MARK: - mapv / filterv

    @Test("mapv returns a real vector")
    func mapvReturnsVector() throws {
        #expect(try swish.eval("(mapv inc [1 2 3])") == .vector([.integer(2), .integer(3), .integer(4)], metadata: nil))
        #expect(try swish.eval("(vector? (mapv inc [1 2 3]))") == .boolean(true))
    }

    @Test("mapv over multiple colls")
    func mapvMultiColl() throws {
        #expect(try swish.eval("(mapv + [1 2 3] [10 20 30])") == .vector([.integer(11), .integer(22), .integer(33)], metadata: nil))
    }

    @Test("filterv returns a real vector of matching items")
    func filtervReturnsVector() throws {
        #expect(try swish.eval("(filterv even? [1 2 3 4])") == .vector([.integer(2), .integer(4)], metadata: nil))
        #expect(try swish.eval("(vector? (filterv even? [1 2]))") == .boolean(true))
    }

    // MARK: - reduce-kv

    @Test("reduce-kv over a map passes key and value")
    func reduceKvMap() throws {
        #expect(
            try swish.eval("(reduce-kv (fn [a k v] (assoc a v k)) {} {:a 1 :b 2})")
                == .map([.integer(1): .keyword("a"), .integer(2): .keyword("b")], metadata: nil))
    }

    @Test("reduce-kv over a vector passes index and element")
    func reduceKvVector() throws {
        #expect(
            try swish.eval("(reduce-kv (fn [a i x] (conj a [i x])) [] [:x :y])")
                == .vector(
                    [.vector([.integer(0), .keyword("x")], metadata: nil),
                     .vector([.integer(1), .keyword("y")], metadata: nil)], metadata: nil))
    }

    @Test("reduce-kv honors reduced early termination")
    func reduceKvReduced() throws {
        #expect(
            try swish.eval("(reduce-kv (fn [a k v] (if (= k 1) (reduced :stop) a)) :init [:zero :one :two])")
                == .keyword("stop"))
    }

    // MARK: - every-pred

    @Test("every-pred all/one/no-args")
    func everyPred() throws {
        #expect(try swish.eval("((every-pred pos? even?) 2 4)") == .boolean(true))
        #expect(try swish.eval("((every-pred pos? even?) 2 3)") == .boolean(false))
        #expect(try swish.eval("((every-pred pos?))") == .boolean(true))
    }

    // MARK: - reductions

    @Test("reductions returns the running reduction values")
    func reductions() throws {
        #expect(
            try swish.eval("(reductions + [1 2 3 4])")
                == .list([.integer(1), .integer(3), .integer(6), .integer(10)], metadata: nil))
        #expect(
            try swish.eval("(reductions + 100 [1 2 3])")
                == .list([.integer(100), .integer(101), .integer(103), .integer(106)], metadata: nil))
    }

    @Test("reductions over a large input does not overflow the stack")
    func reductionsLargeInput() throws {
        #expect(try swish.eval("(count (reductions + (range 3000)))") == .integer(3000))
    }

    // MARK: - memoize

    @Test("memoize only invokes the underlying fn once per distinct args")
    func memoizeCachesPerArgs() throws {
        #expect(
            try swish.eval("""
                (let [calls (atom 0)
                      f (memoize (fn [x] (swap! calls inc) (* x x)))]
                  (f 5) (f 5) (f 5) (f 6)
                  @calls)
                """) == .integer(2))
    }

    @Test("memoize correctly caches an actual nil return, not just re-invoking every time")
    func memoizeCachesNilReturn() throws {
        #expect(
            try swish.eval("""
                (let [calls (atom 0)
                      f (memoize (fn [x] (swap! calls inc) nil))]
                  (f 5) (f 5)
                  @calls)
                """) == .integer(1))
    }

    // MARK: - trampoline

    @Test("trampoline resolves mutual recursion at a depth that would stack-overflow directly")
    func trampolineAvoidsStackOverflow() throws {
        #expect(
            try swish.eval("""
                (letfn [(mcf-even? [n] (if (zero? n) true (fn [] (mcf-odd? (dec n)))))
                        (mcf-odd? [n] (if (zero? n) false (fn [] (mcf-even? (dec n)))))]
                  (trampoline mcf-even? 20000))
                """) == .boolean(true))
    }

    @Test("trampoline with extra args form")
    func trampolineWithArgs() throws {
        #expect(try swish.eval("(trampoline (fn [x y] (+ x y)) 3 4)") == .integer(7))
    }
}
