import Testing
@testable import SwishKit

@Suite("Swish.describeError Tests", .serialized)
struct SwishDescribeErrorTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    @Test("describeError on a plain thrown string returns the bare string, unquoted")
    func describeErrorOnPlainString() throws {
        do {
            _ = try swish.eval(#"(throw "boom")"#)
            Issue.record("expected eval to throw")
        }
        catch {
            #expect(swish.describeError(error) == "boom")
        }
    }

    @Test("describeError on a thrown ex-info shows its message, not a Swift type tag")
    func describeErrorOnExInfo() throws {
        do {
            _ = try swish.eval(#"(throw (ex-info "bad thing" {:code 42}))"#)
            Issue.record("expected eval to throw")
        }
        catch {
            let description = swish.describeError(error)
            #expect(description.contains("bad thing"))
            #expect(!description.contains("SwishException"))
        }
    }

    @Test("describeError on a native runtime error is non-empty and not a Swift struct dump")
    func describeErrorOnNativeError() throws {
        do {
            _ = try swish.eval("(/ 1 0)")
            Issue.record("expected eval to throw")
        }
        catch {
            let description = swish.describeError(error)
            #expect(!description.isEmpty)
            #expect(!description.contains("SwishException"))
        }
    }
}
