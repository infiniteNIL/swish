import Testing
@testable import SwishKit

@Suite("Core Doc Tests")
struct CoreDocTests {
    let swish = Swish()

    @Test("native map has :doc in metadata")
    func mapHasDoc() throws {
        let result = try swish.eval("(meta #'clojure.core/map)")
        guard case .map(let m, _) = result,
              case .string = m[.keyword("doc")]
        else { Issue.record("Expected :doc string in map metadata"); return }
    }

    @Test("native map has :arglists in metadata")
    func mapHasArglists() throws {
        let result = try swish.eval("(:arglists (meta #'clojure.core/map))")
        guard case .list(let entries, _) = result, !entries.isEmpty
        else { Issue.record("Expected non-empty :arglists list"); return }
        guard case .vector = entries[0]
        else { Issue.record("Expected vector in arglists"); return }
    }

    @Test("native + has :doc in metadata")
    func addHasDoc() throws {
        let result = try swish.eval("(meta #'clojure.core/+)")
        guard case .map(let m, _) = result,
              case .string = m[.keyword("doc")]
        else { Issue.record("Expected :doc string in + metadata"); return }
    }

    @Test("native assoc has :arglists in metadata")
    func assocHasArglists() throws {
        let result = try swish.eval("(:arglists (meta #'clojure.core/assoc))")
        guard case .list(let entries, _) = result, !entries.isEmpty
        else { Issue.record("Expected non-empty :arglists list"); return }
    }

    @Test("(doc map) does not throw")
    func docMapDoesNotThrow() throws {
        #expect(throws: Never.self) { try swish.eval("(doc map)") }
    }
}
