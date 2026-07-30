import Testing
@testable import SwishKit

@Suite("Core stdlib additions Tests", .serialized)
struct CoreStdlibAdditionsTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - update-vals / update-keys

    @Test("update-vals maps f over the values")
    func updateVals() throws {
        #expect(try swish.eval("(update-vals {:a 1 :b 2} inc)")
            == .map([.keyword("a"): .integer(2), .keyword("b"): .integer(3)], metadata: nil))
    }

    @Test("update-vals preserves a sorted-map's sortedness")
    func updateValsSorted() throws {
        #expect(try swish.eval("(sorted? (update-vals (sorted-map :a 1) inc))") == .boolean(true))
    }

    @Test("update-keys maps f over the keys")
    func updateKeys() throws {
        #expect(try swish.eval("(update-keys {:a 1 :b 2} name)")
            == .map([.string("a"): .integer(1), .string("b"): .integer(2)], metadata: nil))
    }

    // MARK: - with-redefs

    @Test("with-redefs redefines within the body and restores after")
    func withRedefs() throws {
        #expect(try swish.eval("(with-redefs [inc dec] (inc 5))") == .integer(4))
        #expect(try swish.eval("(do (with-redefs [inc dec] nil) (inc 5))") == .integer(6))
    }

    @Test("with-redefs restores the root even when the body throws")
    func withRedefsRestoresOnThrow() throws {
        #expect(try swish.eval("""
            (do (try (with-redefs [inc dec] (throw (ex-info "boom" {})))
                     (catch Exception e nil))
                (inc 5))
            """) == .integer(6))
    }

    // MARK: - halt-when

    @Test("halt-when leaves transduction unaffected when pred never true")
    func haltWhenUntriggered() throws {
        #expect(try swish.eval("(transduce (halt-when neg?) conj [1 2 3])")
            == .vector([.integer(1), .integer(2), .integer(3)], metadata: nil))
    }

    @Test("halt-when returns the triggering input when pred is true")
    func haltWhenTriggered() throws {
        #expect(try swish.eval("(transduce (comp (map inc) (halt-when neg?)) conj [1 -5 3])") == .integer(-4))
    }

    // MARK: - iteration

    @Test("iteration produces values until step returns a non-somef result")
    func iteration() throws {
        #expect(try swish.eval("(vec (iteration (fn [k] (when (< k 4) (inc k))) :initk 0))")
            == .vector(SwishPersistentVector([1, 2, 3, 4].map { .integer($0) }), metadata: nil))
    }

    @Test("iteration honors :vf and :kf")
    func iterationVfKf() throws {
        // step returns {:v .. :next ..}; kf pulls :next, vf pulls :v
        #expect(try swish.eval("""
            (vec (iteration (fn [k] (when (< k 3) {:v (* 10 k) :next (inc k)}))
                            :initk 0 :vf :v :kf :next))
            """) == .vector(SwishPersistentVector([0, 10, 20].map { .integer($0) }), metadata: nil))
    }

    // MARK: - infinite?

    @Test("infinite? on ±Inf, finite doubles, and integers")
    func infinite() throws {
        #expect(try swish.eval("[(infinite? ##Inf) (infinite? ##-Inf) (infinite? 1.5) (infinite? 5)]")
            == .vector([.boolean(true), .boolean(true), .boolean(false), .boolean(false)], metadata: nil))
    }

    // MARK: - typed array constructors

    @Test("char-array coerces a string and round-trips via str")
    func charArrayFromString() throws {
        #expect(try swish.eval(#"(apply str (char-array "abc"))"#) == .string("abc"))
        #expect(try swish.eval("(count (char-array 3))") == .integer(3))
    }

    @Test("double-array / long-array / boolean-array construct from seqs and sizes")
    func typedArrays() throws {
        #expect(try swish.eval("(vec (double-array [1.0 2.5]))")
            == .vector([.double(1.0), .double(2.5)], metadata: nil))
        #expect(try swish.eval("(vec (long-array [1 2 3]))")
            == .vector(SwishPersistentVector([1, 2, 3].map { .integer($0) }), metadata: nil))
        #expect(try swish.eval("(vec (boolean-array 2))")
            == .vector([.boolean(false), .boolean(false)], metadata: nil))
    }
}
