import Testing
import Foundation
@testable import SwishKit

@Suite("Evaluator Tagged Literal Tests", .serialized)
struct EvaluatorTaggedLiteralTests {
    nonisolated(unsafe) static let _shared = Swish()
    var swish: Swish { Self._shared }

    @Test(".inst self-evaluates")
    func instSelfEvaluates() throws {
        let date = Date()
        let evaluator = Evaluator()
        let result = try evaluator.eval(.inst(date))
        #expect(result == .inst(date))
    }

    @Test(".uuid self-evaluates")
    func uuidSelfEvaluates() throws {
        let uuid = UUID()
        let evaluator = Evaluator()
        let result = try evaluator.eval(.uuid(uuid))
        #expect(result == .uuid(uuid))
    }

    @Test("Two equal #inst compare as equal in Swish")
    func instEqualityInSwish() throws {
        let result = try swish.eval(#"(= #inst "2024-01-01T00:00:00Z" #inst "2024-01-01T00:00:00Z")"#)
        #expect(result == .boolean(true))
    }

    @Test("Two different #inst compare as not equal in Swish")
    func instInequalityInSwish() throws {
        let result = try swish.eval(#"(= #inst "2024-01-01T00:00:00Z" #inst "2025-01-01T00:00:00Z")"#)
        #expect(result == .boolean(false))
    }

    @Test("Two equal #uuid compare as equal in Swish")
    func uuidEqualityInSwish() throws {
        let result = try swish.eval(
            #"(= #uuid "f81d4fae-7dec-11d0-a765-00a0c91e6bf6" #uuid "f81d4fae-7dec-11d0-a765-00a0c91e6bf6")"#)
        #expect(result == .boolean(true))
    }

    @Test("Two different #uuid compare as not equal in Swish")
    func uuidInequalityInSwish() throws {
        let result = try swish.eval(
            #"(= #uuid "f81d4fae-7dec-11d0-a765-00a0c91e6bf6" #uuid "00000000-0000-0000-0000-000000000000")"#)
        #expect(result == .boolean(false))
    }

    @Test("#inst can be stored and retrieved from a map")
    func instInMap() throws {
        let result = try swish.eval(
            #"(let [m {:date #inst "2024-01-01T00:00:00Z"}] (:date m))"#)
        if case .inst = result { } else {
            Issue.record("Expected .inst, got \(result)")
        }
    }

    @Test("#uuid can be stored and retrieved from a map")
    func uuidInMap() throws {
        let result = try swish.eval(
            #"(let [m {:id #uuid "f81d4fae-7dec-11d0-a765-00a0c91e6bf6"}] (:id m))"#)
        if case .uuid = result { } else {
            Issue.record("Expected .uuid, got \(result)")
        }
    }
}
