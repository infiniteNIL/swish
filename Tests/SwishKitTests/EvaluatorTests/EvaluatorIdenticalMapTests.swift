import Testing
@testable import SwishKit

@Suite("identical? for maps", .serialized)
struct EvaluatorIdenticalMapTests {
    static let _shared = Evaluator()
    var evaluator: Evaluator { Self._shared }

    @Test("two fresh empty maps are not identical")
    func twoEmptyMapsNotIdentical() throws {
        #expect(try evaluator.eval("(identical? (hash-map) (hash-map))") == .boolean(false))
    }

    @Test("a map bound to the same var is identical to itself")
    func sameBindingIsIdentical() throws {
        #expect(try evaluator.eval("(let [x {}] (identical? x x))") == .boolean(true))
    }

    @Test("two separately created empty maps are structurally equal")
    func twoEmptyMapsAreEqual() throws {
        #expect(try evaluator.eval("(let [x {} y {}] (= x y))") == .boolean(true))
    }

    @Test("two separately created empty maps are not identical")
    func twoEmptyMapsNotIdenticalViaLet() throws {
        #expect(try evaluator.eval("(let [x {} y {}] (identical? x y))") == .boolean(false))
    }

    @Test("dissoc'd-to-empty map is not identical to a fresh empty map")
    func dissocToEmptyNotIdenticalToFresh() throws {
        #expect(try evaluator.eval(
            "(let [x (hash-map) y (-> (hash-map :a-key :a-val) (dissoc :a-key))] (identical? x y))"
        ) == .boolean(false))
    }
}
