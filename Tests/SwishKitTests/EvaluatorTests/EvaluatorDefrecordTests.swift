import Testing
@testable import SwishKit

@Suite("Evaluator defrecord Tests", .serialized)
struct EvaluatorDefrecordTests {
    nonisolated(unsafe) static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - Constructor registration

    @Test("defrecord interns positional constructor (TypeName.)")
    func defrecordInternsPositionalConstructor() throws {
        _ = try swish.eval("(defrecord DRPoint [x y])")
        let result = try swish.eval("(DRPoint. 1 2)")
        if case .record(let t, let fields, let data, _) = result {
            #expect(t.hasSuffix("/DRPoint"))
            #expect(fields == ["x", "y"])
            #expect(data[.keyword("x")] == .integer(1))
            #expect(data[.keyword("y")] == .integer(2))
        } else {
            Issue.record("Expected .record, got \(result)")
        }
    }

    @Test("defrecord interns arrow constructor (->TypeName)")
    func defrecordInternsArrowConstructor() throws {
        _ = try swish.eval("(defrecord DRPoint2 [x y])")
        let result = try swish.eval("(->DRPoint2 3 4)")
        if case .record(let t, _, let data, _) = result {
            #expect(t.hasSuffix("/DRPoint2"))
            #expect(data[.keyword("x")] == .integer(3))
            #expect(data[.keyword("y")] == .integer(4))
        } else {
            Issue.record("Expected .record, got \(result)")
        }
    }

    @Test("->TypeName and TypeName. produce equal records")
    func arrowAndDotConstructorsAreEqual() throws {
        _ = try swish.eval("(defrecord DRPoint3 [x y])")
        let a = try swish.eval("(DRPoint3. 5 6)")
        let b = try swish.eval("(->DRPoint3 5 6)")
        #expect(a == b)
    }

    @Test("defrecord interns map->TypeName constructor")
    func defrecordInternsMapConstructor() throws {
        _ = try swish.eval("(defrecord DRPoint4 [x y])")
        let result = try swish.eval("(map->DRPoint4 {:x 7 :y 8})")
        if case .record(_, _, let data, _) = result {
            #expect(data[.keyword("x")] == .integer(7))
            #expect(data[.keyword("y")] == .integer(8))
        } else {
            Issue.record("Expected .record, got \(result)")
        }
    }

    @Test("map->TypeName fills missing fields with nil")
    func mapConstructorFillsMissingFieldsWithNil() throws {
        _ = try swish.eval("(defrecord DRPoint5 [x y])")
        let result = try swish.eval("(map->DRPoint5 {:x 9})")
        if case .record(_, _, let data, _) = result {
            #expect(data[.keyword("x")] == .integer(9))
            #expect(data[.keyword("y")] == .nil)
        } else {
            Issue.record("Expected .record, got \(result)")
        }
    }

    // MARK: - Equality and identity

    @Test("Two records with same type and data are equal")
    func recordsWithSameTypeAndDataAreEqual() throws {
        _ = try swish.eval("(defrecord DREq [a b])")
        let a = try swish.eval("(DREq. 1 2)")
        let b = try swish.eval("(DREq. 1 2)")
        #expect(a == b)
    }

    @Test("Records with different data are not equal")
    func recordsWithDifferentDataAreNotEqual() throws {
        _ = try swish.eval("(defrecord DRNeq [a b])")
        let a = try swish.eval("(DRNeq. 1 2)")
        let b = try swish.eval("(DRNeq. 1 3)")
        #expect(a != b)
    }

    @Test("Record is not equal to equivalent plain map")
    func recordNotEqualToPlainMap() throws {
        _ = try swish.eval("(defrecord DRVsMap [x y])")
        let record = try swish.eval("(DRVsMap. 1 2)")
        let map = try swish.eval("{:x 1 :y 2}")
        #expect(record != map)
    }

    // MARK: - Field access

    @Test("Keyword lookup on record")
    func keywordLookupOnRecord() throws {
        _ = try swish.eval("(defrecord DRLookup [x y])")
        let result = try swish.eval("(let [p (DRLookup. 10 20)] (:x p))")
        #expect(result == .integer(10))
    }

    @Test("Record-as-function with keyword arg")
    func recordAsFunctionWithKeyword() throws {
        _ = try swish.eval("(defrecord DRFn [x y])")
        let result = try swish.eval("(let [p (DRFn. 30 40)] (p :y))")
        #expect(result == .integer(40))
    }

    @Test("get works on record")
    func getOnRecord() throws {
        _ = try swish.eval("(defrecord DRGet [x y])")
        let result = try swish.eval("(let [p (DRGet. 5 6)] (get p :x))")
        #expect(result == .integer(5))
    }

    @Test("get returns not-found for missing key")
    func getReturnsNotFoundForMissingKey() throws {
        _ = try swish.eval("(defrecord DRGetNF [x y])")
        let result = try swish.eval("(let [p (DRGetNF. 5 6)] (get p :z :missing))")
        #expect(result == .keyword("missing"))
    }

    // MARK: - map? predicate

    @Test("map? returns true for a record")
    func mapPredicateTrueForRecord() throws {
        _ = try swish.eval("(defrecord DRMapQ [a])")
        let result = try swish.eval("(map? (DRMapQ. 1))")
        #expect(result == .boolean(true))
    }

    // MARK: - assoc

    @Test("assoc on record with declared field returns record")
    func assocOnRecordReturnRecord() throws {
        _ = try swish.eval("(defrecord DRAssoc [x y])")
        let result = try swish.eval("(let [p (DRAssoc. 1 2)] (assoc p :x 99))")
        if case .record(_, _, let data, _) = result {
            #expect(data[.keyword("x")] == .integer(99))
            #expect(data[.keyword("y")] == .integer(2))
        } else {
            Issue.record("Expected .record from assoc, got \(result)")
        }
    }

    @Test("assoc on record with new key returns record with extra key")
    func assocOnRecordAddsExtraKey() throws {
        _ = try swish.eval("(defrecord DRAssoc2 [x y])")
        let result = try swish.eval("(let [p (DRAssoc2. 1 2)] (assoc p :z 3))")
        if case .record(_, _, let data, _) = result {
            #expect(data[.keyword("z")] == .integer(3))
        } else {
            Issue.record("Expected .record from assoc, got \(result)")
        }
    }

    // MARK: - dissoc

    @Test("dissoc of declared field returns plain map")
    func dissocDeclaredFieldReturnsMap() throws {
        _ = try swish.eval("(defrecord DRDissoc [a b c])")
        let result = try swish.eval("(let [r (DRDissoc. 1 2 3)] (dissoc r :a))")
        if case .map(let sm) = result {
            #expect(sm.dict[.keyword("a")] == nil)
            #expect(sm.dict[.keyword("b")] == .integer(2))
        } else {
            Issue.record("Expected plain .map after dissoc of base field, got \(result)")
        }
    }

    @Test("dissoc of non-field key keeps record type")
    func dissocNonFieldKeyKeepsRecord() throws {
        _ = try swish.eval("(defrecord DRDissoc2 [a b])")
        let result = try swish.eval("(let [r (assoc (DRDissoc2. 1 2) :extra 99)] (dissoc r :extra))")
        if case .record = result {
        } else {
            Issue.record("Expected .record after dissoc of non-field key, got \(result)")
        }
    }

    // MARK: - keys / vals / find

    @Test("keys on a record returns declared-field keys")
    func keysOnRecord() throws {
        _ = try swish.eval("(defrecord DRKeys [a b])")
        let result = try swish.eval("(set (keys (DRKeys. 1 2)))")
        if case .set(let ss) = result {
            #expect(ss.elements.contains(.keyword("a")))
            #expect(ss.elements.contains(.keyword("b")))
        } else {
            Issue.record("Expected .set from (set (keys ...)), got \(result)")
        }
    }

    @Test("vals on a record returns field values")
    func valsOnRecord() throws {
        _ = try swish.eval("(defrecord DRVals [a b])")
        let result = try swish.eval("(set (vals (DRVals. 10 20)))")
        if case .set(let ss) = result {
            #expect(ss.elements.contains(.integer(10)))
            #expect(ss.elements.contains(.integer(20)))
        } else {
            Issue.record("Expected .set from (set (vals ...)), got \(result)")
        }
    }

    @Test("find on a record returns the map entry vector")
    func findOnRecord() throws {
        _ = try swish.eval("(defrecord DRFind [x y])")
        let result = try swish.eval("(find (DRFind. 42 99) :x)")
        #expect(result == .vector([.keyword("x"), .integer(42)], metadata: nil))
    }

    // MARK: - Printer

    @Test("Record prints as #TypeName{:k v}")
    func recordPrintsCorrectly() throws {
        _ = try swish.eval("(defrecord DRPrint [x])")
        let result = try swish.eval("(pr-str (DRPrint. 7))")
        if case .string(let s) = result {
            #expect(s == "#DRPrint{:x 7}")
        } else {
            Issue.record("Expected string from pr-str, got \(result)")
        }
    }
}
