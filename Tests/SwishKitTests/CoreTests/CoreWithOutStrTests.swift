import Testing
@testable import SwishKit
import Foundation

@Suite("Core with-out-str Tests", .serialized)
struct CoreWithOutStrTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    private func tempPath() -> String {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .path
    }

    @Test("with-out-str captures println and prn output")
    func capturesPrintlnAndPrn() throws {
        #expect(try swish.eval(#"""
            (with-out-str
              (println "some" "sample" :text 'here)
              (prn [:a :b] {:c :d} #{:e} '(:f)))
            """#) == .string("some sample :text here\n[:a :b] {:c :d} #{:e} (:f)\n"))
    }

    @Test("with-out-str with an empty body returns an empty string")
    func emptyBodyReturnsEmptyString() throws {
        #expect(try swish.eval("(with-out-str)") == .string(""))
    }

    @Test("multiple print calls concatenate with no extra separator")
    func multiplePrintsConcatenate() throws {
        #expect(try swish.eval(#"""
            (with-out-str (print "a") (print "b") (print "c"))
            """#) == .string("abc"))
    }

    @Test("nested with-out-str captures only its own output")
    func nestedWithOutStr() throws {
        #expect(try swish.eval(#"""
            (with-out-str
              (println "outer")
              (let [inner (with-out-str (println "inner"))]
                (print inner)))
            """#) == .string("outer\ninner\n"))
    }

    @Test("*out* is restored after with-out-str exits")
    func outIsRestoredAfterward() throws {
        #expect(try swish.eval(#"""
            (with-out-str (println "captured"))
            (nil? *out*)
            """#) == .boolean(true))
    }

    @Test("the writer bound during with-out-str satisfies writer?")
    func writerPredicateHoldsDuringCapture() throws {
        #expect(try swish.eval("""
            (with-out-str (println (writer? *out*)))
            """) == .string("true\n"))
    }

    @Test("swish-writer-string throws for a file-backed writer")
    func writerStringThrowsForFileWriter() throws {
        let path = tempPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        _ = try swish.eval("(require '[clojure.swift.io :as io])")
        #expect(try swish.eval(#"""
            (with-open [w (io/writer "\#(path)")]
              (try
                (swish-writer-string w)
                false
                (catch Exception e true)))
            """#) == .boolean(true))
    }
}
