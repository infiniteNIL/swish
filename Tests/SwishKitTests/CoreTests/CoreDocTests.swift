import Testing
@testable import SwishKit

@Suite("Core Doc Tests", .serialized)
struct CoreDocTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    @Test("native map has :doc in metadata")
    func mapHasDoc() throws {
        let result = try swish.eval("(meta #'clojure.core/map)")
        guard case .map(let sm) = result,
              case .string = sm.dict[.keyword("doc")]
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
        guard case .map(let sm) = result,
              case .string = sm.dict[.keyword("doc")]
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

    // MARK: - namespace doc

    @Test("(doc clojure.core) does not throw")
    func docClojureCoreDoesNotThrow() throws {
        #expect(throws: Never.self) { try swish.eval("(doc clojure.core)") }
    }

    @Test("(doc clojure.core) returns nil")
    func docClojureCoreReturnsNil() throws {
        #expect(try swish.eval("(doc clojure.core)") == .nil)
    }

    @Test("(doc user-ns) works for namespace with docstring")
    func docNamespaceWithDocstring() throws {
        let swish2 = Swish()
        _ = try swish2.eval("(ns my-lib \"A documented library\")")
        _ = try swish2.eval("(ns user)")
        #expect(throws: Never.self) { try swish2.eval("(doc my-lib)") }
    }

    @Test("(doc user-ns) works for namespace without docstring")
    func docNamespaceWithoutDocstring() throws {
        let swish2 = Swish()
        _ = try swish2.eval("(ns bare-ns)")
        _ = try swish2.eval("(ns user)")
        #expect(throws: Never.self) { try swish2.eval("(doc bare-ns)") }
    }
}
