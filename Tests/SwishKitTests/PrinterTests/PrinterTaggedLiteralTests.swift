import Testing
import Foundation
@testable import SwishKit

@Suite("Printer Tagged Literal Tests")
struct PrinterTaggedLiteralTests {
    let printer = Printer()

    @Test("inst prints as #inst with ISO 8601 string")
    func instPrintsAsTaggedLiteral() throws {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let date = formatter.date(from: "2024-01-01T00:00:00Z")!
        let output = printer.printString(.inst(date))
        #expect(output.hasPrefix("#inst \""))
        #expect(output.hasSuffix("\""))
    }

    @Test("inst round-trips through reader")
    func instRoundTrips() throws {
        let original = try Reader.readString(#"#inst "2024-06-15T10:30:00.000Z""#)[0]
        guard case .inst(let date) = original else {
            Issue.record("Expected .inst"); return
        }
        let printed = printer.printString(.inst(date))
        let reparsed = try Reader.readString(printed)[0]
        #expect(original == reparsed)
    }

    @Test("uuid prints lowercase with hyphens")
    func uuidPrintsLowercase() throws {
        let uuid = UUID(uuidString: "F81D4FAE-7DEC-11D0-A765-00A0C91E6BF6")!
        let output = printer.printString(.uuid(uuid))
        #expect(output == "#uuid \"f81d4fae-7dec-11d0-a765-00a0c91e6bf6\"")
    }

    @Test("uuid round-trips through reader")
    func uuidRoundTrips() throws {
        let original = try Reader.readString(#"#uuid "f81d4fae-7dec-11d0-a765-00a0c91e6bf6""#)[0]
        guard case .uuid(let uuid) = original else {
            Issue.record("Expected .uuid"); return
        }
        let printed = printer.printString(.uuid(uuid))
        let reparsed = try Reader.readString(printed)[0]
        #expect(original == reparsed)
    }
}
