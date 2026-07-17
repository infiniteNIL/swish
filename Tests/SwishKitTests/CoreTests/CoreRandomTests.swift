import Testing
@testable import SwishKit

@Suite("Core rand-nth/random-sample/random-uuid/uuid? Tests", .serialized)
struct CoreRandomTests {
    static let _shared: Swish = {
        let swish = Swish()
        _ = try? swish.eval("(require '[clojure.string :as str])")
        return swish
    }()
    var swish: Swish { Self._shared }

    // MARK: - rand-nth

    @Test("rand-nth returns members of the collection and is not constant across draws")
    func randNthBasic() throws {
        // 20 draws over 100 unique values is still an astronomically reliable
        // "not constant" check (a coincidentally-constant result has
        // probability (1/100)^19), while running far faster than the
        // original 1000-item/100-draw sizing.
        #expect(try swish.eval("""
            (let [n-items 100
                  coll (doall (range n-items))
                  samples (repeatedly 20 #(rand-nth coll))]
              (and (> (count (set samples)) 1)
                   (every? #(< -1 % n-items) samples)))
            """) == .boolean(true))
    }

    @Test("(rand-nth nil) returns nil")
    func randNthNil() throws {
        #expect(try swish.eval("(rand-nth nil)") == .nil)
    }

    @Test("(rand-nth 1) throws")
    func randNthNonCollection() throws {
        #expect(throws: (any Error).self) { try swish.eval("(rand-nth 1)") }
    }

    // MARK: - random-sample, 2-arity (coll form)

    // prob 0/1/>1/negative are deterministic outcomes — they don't depend on
    // rand's actual output at all, so repeating them 10 times (as the jank
    // fixture does) proves nothing an unrepeated check doesn't; a single draw
    // over a small collection is just as conclusive and far faster.

    @Test("random-sample with prob 0 always returns an empty seq")
    func randomSampleProbZero() throws {
        #expect(try swish.eval("(nil? (seq (random-sample 0 (range 20))))") == .boolean(true))
    }

    @Test("random-sample with prob 1 always returns the whole collection")
    func randomSampleProbOne() throws {
        #expect(try swish.eval("(= (random-sample 1 (range 20)) (range 20))") == .boolean(true))
    }

    @Test("random-sample with prob 10 (>1) always returns the whole collection")
    func randomSampleProbAboveOne() throws {
        #expect(try swish.eval("(= (random-sample 10 (range 20)) (range 20))") == .boolean(true))
    }

    @Test("random-sample with negative prob always returns an empty seq")
    func randomSampleNegativeProb() throws {
        #expect(try swish.eval("(nil? (seq (random-sample -1 (range 20))))") == .boolean(true))
    }

    @Test("random-sample with mid-range prob returns a non-constant subset of the collection")
    func randomSampleMidProb() throws {
        // prob=0.5 is genuinely random, so this one still benefits from
        // repeated draws to check "not constant" — nitems just needs to be
        // large enough to make every subset-size/membership check meaningful.
        #expect(try swish.eval("""
            (let [nitems 100
                  coll (doall (range nitems))
                  xs (repeatedly 10 #(random-sample 0.5 coll))]
              (and (> (count (set xs)) 1)
                   (every? #(and (>= (count %) 0) (< (count %) nitems)) xs)
                   (every? (fn [sub] (every? (fn [item] (and (>= item 0) (< item nitems))) sub)) xs)))
            """) == .boolean(true))
    }

    @Test("random-sample on nil collection always returns an empty seq")
    func randomSampleNilColl() throws {
        #expect(try swish.eval("(every? (comp nil? seq) (repeatedly 10 #(random-sample -1 nil)))") == .boolean(true))
    }

    @Test("random-sample on an empty collection always returns an empty seq")
    func randomSampleEmptyColl() throws {
        #expect(try swish.eval("(every? (comp nil? seq) (repeatedly 10 #(random-sample 1 [])))") == .boolean(true))
    }

    @Test("random-sample with nil prob throws when the result is seq'd")
    func randomSampleNilProb() throws {
        #expect(throws: (any Error).self) { try swish.eval("(seq (random-sample nil (range 100)))") }
    }

    @Test("random-sample on a non-collection throws when the result is seq'd")
    func randomSampleNonCollection() throws {
        #expect(throws: (any Error).self) { try swish.eval("(seq (random-sample 0.5 42))") }
        #expect(throws: (any Error).self) { try swish.eval("(seq (random-sample 0.5 :foo))") }
    }

    // MARK: - random-sample, 1-arity (transducer form)

    @Test("random-sample transducer form matches the 2-arity form's behavior via transduce")
    func randomSampleTransducer() throws {
        #expect(try swish.eval("(nil? (seq (transduce (random-sample 0) conj [] (range 20))))") == .boolean(true))
        #expect(try swish.eval("(= (transduce (random-sample 1) conj [] (range 20)) (range 20))") == .boolean(true))
    }

    // MARK: - random-uuid

    @Test("random-uuid returns a uuid")
    func randomUUIDReturnsUUID() throws {
        #expect(try swish.eval("(uuid? (random-uuid))") == .boolean(true))
    }

    @Test("random-uuid calls are unique")
    func randomUUIDUnique() throws {
        #expect(try swish.eval("(let [uuids (repeatedly 10 random-uuid)] (= (count uuids) (count (set uuids))))") == .boolean(true))
    }

    @Test("random-uuid produces version-4 UUIDs (third dash-group starts with 4)")
    func randomUUIDFormat4() throws {
        #expect(try swish.eval("""
            (every? (fn [u] (= \\4 (get-in (clojure.string/split (str u) #"-") [2 0])))
                    (repeatedly 10 random-uuid))
            """) == .boolean(true))
    }

    // MARK: - uuid?

    @Test("uuid? is true for uuids")
    func uuidPredicateTrue() throws {
        #expect(try swish.eval("(uuid? (random-uuid))") == .boolean(true))
        #expect(try swish.eval(#"(uuid? (parse-uuid "550e8400-e29b-41d4-a716-446655440000"))"#) == .boolean(true))
    }

    @Test("uuid? is false for non-uuid types")
    func uuidPredicateFalse() throws {
        #expect(try swish.eval("(uuid? nil)") == .boolean(false))
        #expect(try swish.eval(#"(uuid? "550e8400-e29b-41d4-a716-446655440000")"#) == .boolean(false))
        #expect(try swish.eval("(uuid? 42)") == .boolean(false))
        #expect(try swish.eval("(uuid? :key)") == .boolean(false))
        #expect(try swish.eval("(uuid? [])") == .boolean(false))
    }
}
