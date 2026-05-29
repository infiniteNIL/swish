import Testing
@testable import SwishKit

@Suite("Parser Anonymous Fn Tests")
struct ParserAnonymousFnTests {
    private func parse(_ source: String) throws -> Expr {
        let exprs = try Reader.readString(source)
        guard let expr = exprs.first else {
            Issue.record("No expression parsed")
            return .nil
        }
        return expr
    }

    private func fnParts(_ source: String) throws -> (params: [Expr], body: [Expr]) {
        let expr = try parse(source)
        guard case .list(let elems, _) = expr,
              elems.count >= 2,
              case .symbol("fn", _) = elems[0],
              case .vector(let params, _) = elems[1]
        else {
            Issue.record("Expected (fn [params] body...), got \(expr)")
            return ([], [])
        }
        return (params, Array(elems.dropFirst(2)))
    }

    @Test("% normalizes to %1 in params and body")
    func barePercent() throws {
        let (params, body) = try fnParts("#(+ % 1)")
        #expect(params == [.symbol("%1", metadata: nil)])
        #expect(body == [.list([.symbol("+", metadata: nil), .symbol("%1", metadata: nil), .integer(1)], metadata: nil)])
    }

    @Test("Explicit %1 produces single param")
    func explicitPercent1() throws {
        let (params, body) = try fnParts("#(+ %1 1)")
        #expect(params == [.symbol("%1", metadata: nil)])
        #expect(body == [.list([.symbol("+", metadata: nil), .symbol("%1", metadata: nil), .integer(1)], metadata: nil)])
    }

    @Test("Two positional args")
    func twoPositionalArgs() throws {
        let (params, _) = try fnParts("#(+ %1 %2)")
        #expect(params == [.symbol("%1", metadata: nil), .symbol("%2", metadata: nil)])
    }

    @Test("Rest arg only")
    func restArgOnly() throws {
        let (params, _) = try fnParts("#(apply str %&)")
        #expect(params == [.symbol("&", metadata: nil), .symbol("%&", metadata: nil)])
    }

    @Test("Mixed positional and rest")
    func mixedPositionalAndRest() throws {
        let (params, _) = try fnParts("#(str %1 %&)")
        #expect(params == [
            .symbol("%1", metadata: nil),
            .symbol("&", metadata: nil),
            .symbol("%&", metadata: nil),
        ])
    }

    @Test("No arg refs produces zero-arity fn")
    func noArgRefs() throws {
        let (params, body) = try fnParts("#(+ 1 2)")
        #expect(params == [])
        #expect(body == [.list([.symbol("+", metadata: nil), .integer(1), .integer(2)], metadata: nil)])
    }

    @Test("Empty body produces (fn [] nil)")
    func emptyBody() throws {
        let (params, body) = try fnParts("#()")
        #expect(params == [])
        #expect(body == [.nil])
    }

    @Test("Gap-filling up to highest index")
    func gapFilling() throws {
        let (params, _) = try fnParts("#(%2)")
        #expect(params == [.symbol("%1", metadata: nil), .symbol("%2", metadata: nil)])
    }

    @Test("Nested anonymous function throws")
    func nestedThrows() throws {
        #expect(throws: ParserError.self) {
            try Reader.readString("#(#(+ % 1))")
        }
    }

    @Test("Unterminated anonymous fn throws")
    func unterminatedThrows() throws {
        #expect(throws: ParserError.self) {
            try Reader.readString("#(+ 1 2")
        }
    }

    @Test("#_ discard works inside anonymous fn body")
    func discardInsideBody() throws {
        let (params, body) = try fnParts("#(+ #_99 %)")
        #expect(params == [.symbol("%1", metadata: nil)])
        #expect(body == [.list([.symbol("+", metadata: nil), .symbol("%1", metadata: nil)], metadata: nil)])
    }
}
