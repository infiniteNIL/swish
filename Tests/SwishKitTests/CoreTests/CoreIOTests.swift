import Testing
@testable import SwishKit
import Foundation

@Suite("slurp and spit Tests")
struct CoreIOTests {
    let swish = Swish()

    private func tempPath() -> String {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .path
    }

    // MARK: - slurp

    @Test("slurp reads file content as string")
    func slurpReadsFile() throws {
        let path = tempPath()
        try "hello world".write(toFile: path, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: path) }
        #expect(try swish.eval("(slurp \"\(path)\")") == .string("hello world"))
    }

    @Test("slurp throws for missing file")
    func slurpMissing() throws {
        #expect(throws: (any Error).self) {
            try swish.eval("(slurp \"/no/such/swish/file/xyz\")")
        }
    }

    @Test("slurp with :encoding UTF-8 reads correctly")
    func slurpWithEncoding() throws {
        let path = tempPath()
        try "café".write(toFile: path, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: path) }
        #expect(try swish.eval("(slurp \"\(path)\" :encoding \"UTF-8\")") == .string("café"))
    }

    // MARK: - spit

    @Test("spit writes string content")
    func spitWritesString() throws {
        let path = tempPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        _ = try swish.eval("(spit \"\(path)\" \"hello\")")
        #expect(try String(contentsOfFile: path, encoding: .utf8) == "hello")
    }

    @Test("spit converts integer to string")
    func spitInteger() throws {
        let path = tempPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        _ = try swish.eval("(spit \"\(path)\" 42)")
        #expect(try String(contentsOfFile: path, encoding: .utf8) == "42")
    }

    @Test("spit creates file if it does not exist")
    func spitCreatesFile() throws {
        let path = tempPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        #expect(!FileManager.default.fileExists(atPath: path))
        _ = try swish.eval("(spit \"\(path)\" \"created\")")
        #expect(FileManager.default.fileExists(atPath: path))
    }

    @Test("spit with :append true appends to existing content")
    func spitAppend() throws {
        let path = tempPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        _ = try swish.eval("(spit \"\(path)\" \"hello\")")
        _ = try swish.eval("(spit \"\(path)\" \" world\" :append true)")
        #expect(try String(contentsOfFile: path, encoding: .utf8) == "hello world")
    }

    @Test("spit with :append true creates file if missing")
    func spitAppendCreates() throws {
        let path = tempPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        _ = try swish.eval("(spit \"\(path)\" \"new\" :append true)")
        #expect(try String(contentsOfFile: path, encoding: .utf8) == "new")
    }

    @Test("spit and slurp round-trip")
    func spitSlurpRoundTrip() throws {
        let path = tempPath()
        defer { try? FileManager.default.removeItem(atPath: path) }
        _ = try swish.eval("(spit \"\(path)\" \"round-trip\")")
        #expect(try swish.eval("(slurp \"\(path)\")") == .string("round-trip"))
    }
}
