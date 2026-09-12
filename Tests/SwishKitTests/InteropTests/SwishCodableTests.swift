import Foundation
import Testing
@testable import SwishKit

struct Point: Codable, Equatable, SwishCodable {
    var x: Int
    var y: Int
}

struct Segment: Codable, Equatable, SwishCodable {
    var start: Point
    var end: Point
    var label: String?
}

struct Event: Codable, Equatable, SwishCodable {
    var name: String
    var at: Date
    var id: UUID
    var tags: [String]
}

struct Person: Codable, Equatable, SwishCodable {
    var firstName: String
    var lastName: String
}

enum Status: String, Codable, Equatable {
    case active
    case idle
}

struct Job: Codable, Equatable, SwishCodable {
    var status: Status
    var retries: Int
}

@Suite("Interop: SwishCodable")
struct SwishCodableTests {
    @Test("A struct decodes from a Swish map")
    func decodesFromMap() throws {
        let swish = Swish()
        let point: Point = try swish.eval("{:x 1 :y 2}")

        #expect(point == Point(x: 1, y: 2))
    }

    @Test("A struct decodes from a defrecord")
    func decodesFromRecord() throws {
        let swish = Swish()
        _ = try swish.eval("(defrecord Point [x y])")
        let point: Point = try swish.eval("(->Point 3 4)")

        #expect(point == Point(x: 3, y: 4))
    }

    @Test("A struct encodes to a keyword-keyed map")
    func encodesToKeywordKeyedMap() throws {
        let swish = Swish()
        let encoded = Point(x: 1, y: 2).swishValue

        #expect(encoded == .map([.keyword("x"): .integer(1), .keyword("y"): .integer(2)], metadata: nil))
        // The keys are real keywords, so Clojure's (:x m) finds them.
        #expect(try swish.call("get", encoded, Keyword("x")) == Expr.integer(1))
    }

    @Test("A struct round-trips through Swish")
    func roundTrips() throws {
        let swish = Swish()
        _ = try swish.eval("(defn shift [p n] (assoc p :x (+ (:x p) n)))")

        let moved: Point = try swish.call("shift", Point(x: 1, y: 2), 10)
        #expect(moved == Point(x: 11, y: 2))
    }

    @Test("Nesting works, and optional fields may be absent or nil")
    func nestingAndOptionals() throws {
        let swish = Swish()

        let withLabel: Segment = try swish.eval("{:start {:x 0 :y 0} :end {:x 1 :y 1} :label \"a\"}")
        #expect(withLabel == Segment(start: Point(x: 0, y: 0), end: Point(x: 1, y: 1), label: "a"))

        let nilLabel: Segment = try swish.eval("{:start {:x 0 :y 0} :end {:x 1 :y 1} :label nil}")
        #expect(nilLabel.label == nil)

        let absentLabel: Segment = try swish.eval("{:start {:x 0 :y 0} :end {:x 1 :y 1}}")
        #expect(absentLabel.label == nil)

        #expect(try swish.eval("(:label (identity {:start {:x 0 :y 0} :end {:x 1 :y 1}}))") == .nil)
    }

    @Test("Date and UUID keep their Swish shapes instead of degrading")
    func foundationTypesUseSwishShapes() throws {
        let swish = Swish()
        let event = Event(name: "launch",
                          at: Date(timeIntervalSince1970: 1_000_000),
                          id: UUID(uuidString: "6ba7b810-9dad-11d1-80b4-00c04fd430c8")!,
                          tags: ["a", "b"])

        let encoded = event.swishValue
        // Codable would make these a Double and a String; the leaf allowlist is
        // what keeps them #inst and #uuid.
        let at: Expr = try swish.call("get", encoded, Keyword("at"))
        let id: Expr = try swish.call("get", encoded, Keyword("id"))
        #expect(at.typeName == "inst")
        #expect(id.typeName == "uuid")

        let back: Event = try swish.call("identity", event)
        #expect(back == event)
    }

    @Test("A RawRepresentable enum decodes from a keyword")
    func enumFromKeyword() throws {
        let swish = Swish()
        let job: Job = try swish.eval("{:status :active :retries 2}")

        #expect(job == Job(status: .active, retries: 2))
        // A Swish string works too, since String decoding accepts both.
        let fromString: Job = try swish.eval(#"{:status "idle" :retries 0}"#)
        #expect(fromString.status == .idle)
    }

    @Test("The kebab-case key strategy matches idiomatic Clojure keys")
    func kebabCaseStrategy() throws {
        let expr = Expr.map([.keyword("first-name"): .string("Rod"),
                             .keyword("last-name"): .string("Schmidt")], metadata: nil)
        let decoder = ExprDecoder(keyStrategy: .kebabCaseKeyword)
        let person = try decoder.decode(Person.self, from: expr)

        #expect(person == Person(firstName: "Rod", lastName: "Schmidt"))
        #expect(try ExprEncoder(keyStrategy: .kebabCaseKeyword).encode(person) == expr)

        // The default strategy is verbatim, so it reads :firstName instead.
        let verbatim = Expr.map([.keyword("firstName"): .string("Rod"),
                                 .keyword("lastName"): .string("Schmidt")], metadata: nil)
        #expect(try ExprDecoder().decode(Person.self, from: verbatim) == person)
    }

    @Test("A missing or wrongly-typed field reports its key path")
    func errorsNameTheField() throws {
        let swish = Swish()

        do {
            let _: Point = try swish.eval("{:x 1}")
            Issue.record("Expected a throw")
        }
        catch let error as DecodingError {
            guard case .keyNotFound(let key, _) = error else {
                Issue.record("Expected keyNotFound, got \(error)")
                return
            }
            #expect(key.stringValue == "y")
        }

        do {
            let _: Point = try swish.eval(#"{:x 1 :y "two"}"#)
            Issue.record("Expected a throw")
        }
        catch let error as DecodingError {
            guard case .typeMismatch(_, let context) = error else {
                Issue.record("Expected typeMismatch, got \(error)")
                return
            }
            #expect(context.codingPath.last?.stringValue == "y")
        }
    }

    @Test("A nil in a non-optional field is valueNotFound, never a silent zero")
    func nilInNonOptionalField() throws {
        let swish = Swish()

        do {
            let _: Point = try swish.eval("{:x 1 :y nil}")
            Issue.record("Expected a throw")
        }
        catch let error as DecodingError {
            guard case .valueNotFound = error else {
                Issue.record("Expected valueNotFound, got \(error)")
                return
            }
        }
    }

    @Test("Arrays of structs work in both directions")
    func arraysOfStructs() throws {
        let swish = Swish()
        let points: [Point] = try swish.eval("[{:x 1 :y 2} {:x 3 :y 4}]")

        #expect(points == [Point(x: 1, y: 2), Point(x: 3, y: 4)])
        #expect(try swish.call("count", points) == Expr.integer(2))
    }

    @Test("A registered Swift function can take and return a SwishCodable struct")
    func registeredFunctionWithStructs() throws {
        let swish = Swish()
        swish.register({ (p: Point) in Point(x: p.y, y: p.x) }, as: "flip")

        #expect(try swish.eval("(:x (flip {:x 1 :y 2}))") == .integer(2))
        let flipped: Point = try swish.call("flip", Point(x: 5, y: 6))
        #expect(flipped == Point(x: 6, y: 5))
    }
}

/// An opaque handle that is also a field of a Codable struct — only possible via
/// `SwishOpaqueCodable`, since Codable synthesis rejects a non-Codable field.
final class Session: SwishOpaqueCodable {
    var hits = 0

    func hit() {
        hits += 1
    }
}

struct Request: Codable, SwishCodable {
    var path: String
    var session: Session
}

/// Three levels of SwishCodable-inside-SwishCodable, to prove the encode and
/// decode dispatch chains terminate. (A struct can't contain itself by value, so
/// distinct types stand in for depth.)
struct Leaf: Codable, Equatable, SwishCodable {
    var value: Int
}

struct Middle: Codable, Equatable, SwishCodable {
    var leaf: Leaf
    var leaves: [Leaf]
}

struct Root: Codable, Equatable, SwishCodable {
    var middle: Middle
    var optionalLeaf: Leaf?
}

@Suite("Interop: SwishCodable recursion and opaque fields")
struct SwishCodableRecursionTests {
    @Test("Nested SwishCodable values terminate in both directions")
    func nestedCodableTerminates() throws {
        let swish = Swish()
        let deep = Root(middle: Middle(leaf: Leaf(value: 1),
                                       leaves: [Leaf(value: 2), Leaf(value: 3)]),
                        optionalLeaf: Leaf(value: 4))

        // Encoding a SwishCodable whose fields are themselves SwishCodable is
        // where reversing the dispatch order would bounce between `swishValue`
        // and `ExprEncoder` until the stack ran out.
        let encoded = try ExprEncoder().encode(deep)
        #expect(try swish.call("get-in", encoded, [Keyword("middle"), Keyword("leaf"), Keyword("value")])
            == Expr.integer(1))
        #expect(try swish.call("count", try swish.call("get-in", encoded, [Keyword("middle"), Keyword("leaves")]))
            == Expr.integer(2))

        let back: Root = try swish.call("identity", deep)
        #expect(back == deep)

        // And with the optional absent.
        let shallow = Root(middle: Middle(leaf: Leaf(value: 9), leaves: []), optionalLeaf: nil)
        #expect(try swish.call("identity", shallow) as Root == shallow)
    }

    @Test("A top-level SwishCodable decodes without bouncing through init?(swishValue:)")
    func topLevelCodableTerminates() throws {
        let swish = Swish()
        let point: Point = try swish.eval("{:x 1 :y 2}")
        #expect(point == Point(x: 1, y: 2))

        // The same value through the failable init, which is the other entry point.
        #expect(Point(swishValue: .map([.keyword("x"): .integer(1),
                                        .keyword("y"): .integer(2)], metadata: nil))
            == Point(x: 1, y: 2))
    }

    @Test("An opaque handle can be a field of a Codable struct")
    func opaqueFieldInCodableStruct() throws {
        let swish = Swish()
        let session = Session()
        let request = Request(path: "/home", session: session)

        swish.register({ (r: Request) in r.session.hit(); return r.path }, as: "handle")

        let path: String = try swish.call("handle", request)
        #expect(path == "/home")
        // Reference identity survived the round trip through Swish.
        #expect(session.hits == 1)
    }

    @Test("Encoding an opaque handle outside ExprEncoder is a clear error")
    func opaqueOutsideExprEncoder() throws {
        #expect(throws: EncodingError.self) {
            try JSONEncoder().encode(Request(path: "/x", session: Session()))
        }
    }
}
