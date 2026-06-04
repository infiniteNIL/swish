import Testing
@testable import SwishKit
import Foundation

@Suite("clojure.swift.io streaming I/O Tests")
struct CoreStreamingIOTests {
    let swish = Swish()

    private func tempPath() -> String {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .path
    }

    // MARK: - reader?

    @Test("reader? returns true for a reader")
    func readerPredicateTrue() throws {
        let path = tempPath()
        FileManager.default.createFile(atPath: path, contents: nil)
        defer { try? FileManager.default.removeItem(atPath: path) }
        _ = try swish.eval("(require '[clojure.swift.io :as io])")
        let result = try swish.eval("(reader? (io/reader \"\(path)\"))")
        #expect(result == .boolean(true))
    }

    @Test("reader? returns false for a non-reader")
    func readerPredicateFalse() throws {
        #expect(try swish.eval("(reader? :foo)") == .boolean(false))
    }

    // MARK: - writer?

    @Test("writer? returns true for a writer")
    func writerPredicateTrue() throws {
        let path = tempPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        _ = try swish.eval("(require '[clojure.swift.io :as io])")
        let result = try swish.eval("(writer? (io/writer \"\(path)\"))")
        #expect(result == .boolean(true))
    }

    @Test("writer? returns false for a non-writer")
    func writerPredicateFalse() throws {
        #expect(try swish.eval("(writer? 42)") == .boolean(false))
    }

    // MARK: - line-seq

    @Test("line-seq returns lines of a file as a lazy seq")
    func lineSeqBasic() throws {
        let path = tempPath()
        try "alpha\nbeta\ngamma".write(toFile: path, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: path) }
        _ = try swish.eval("(require '[clojure.swift.io :as io])")
        let result = try swish.eval("""
            (with-open [rdr (io/reader \"\(path)\")]
              (doall (line-seq rdr)))
            """)
        #expect(result == .list([.string("alpha"), .string("beta"), .string("gamma")], metadata: nil))
    }

    @Test("line-seq returns nil for empty file")
    func lineSeqEmpty() throws {
        let path = tempPath()
        FileManager.default.createFile(atPath: path, contents: nil)
        defer { try? FileManager.default.removeItem(atPath: path) }
        _ = try swish.eval("(require '[clojure.swift.io :as io])")
        let result = try swish.eval("""
            (with-open [rdr (io/reader \"\(path)\")]
              (doall (line-seq rdr)))
            """)
        #expect(result == .nil)
    }

    @Test("line-seq handles single line with no trailing newline")
    func lineSeqSingleLine() throws {
        let path = tempPath()
        try "only line".write(toFile: path, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: path) }
        _ = try swish.eval("(require '[clojure.swift.io :as io])")
        let result = try swish.eval("""
            (with-open [rdr (io/reader \"\(path)\")]
              (doall (line-seq rdr)))
            """)
        #expect(result == .list([.string("only line")], metadata: nil))
    }

    // MARK: - writer via *out* binding

    @Test("writer writes content via *out* binding")
    func writerBasic() throws {
        let path = tempPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        _ = try swish.eval("(require '[clojure.swift.io :as io])")
        _ = try swish.eval("""
            (with-open [wtr (io/writer \"\(path)\")]
              (binding [*out* wtr]
                (print "hello")
                (println "")
                (println "world")))
            """)
        #expect(try String(contentsOfFile: path, encoding: .utf8) == "hello\nworld\n")
    }

    @Test("writer with :append appends to existing content")
    func writerAppend() throws {
        let path = tempPath()
        try "line1\n".write(toFile: path, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: path) }
        _ = try swish.eval("(require '[clojure.swift.io :as io])")
        _ = try swish.eval("""
            (with-open [wtr (io/writer \"\(path)\" :append true)]
              (binding [*out* wtr]
                (println "line2")))
            """)
        #expect(try String(contentsOfFile: path, encoding: .utf8) == "line1\nline2\n")
    }

    @Test("writer without :append truncates existing content")
    func writerTruncates() throws {
        let path = tempPath()
        try "old content".write(toFile: path, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: path) }
        _ = try swish.eval("(require '[clojure.swift.io :as io])")
        _ = try swish.eval("""
            (with-open [wtr (io/writer \"\(path)\")]
              (binding [*out* wtr]
                (print "new")))
            """)
        #expect(try String(contentsOfFile: path, encoding: .utf8) == "new")
    }

    // MARK: - close on exception

    @Test("with-open closes reader even when body throws")
    func readerClosedOnThrow() throws {
        let path = tempPath()
        try "line".write(toFile: path, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: path) }
        let local = Swish()
        _ = try? local.eval("""
            (require '[clojure.swift.io :as io])
            (def rdr (io/reader \"\(path)\"))
            (with-open [r rdr]
              (throw "boom"))
            """)
        // Reader was closed by with-open's finally, so reads now return nil
        #expect(try local.eval("(swish-read-line! rdr)") == .nil)
    }
}
