import Testing
@testable import SwishKit

@Suite("Core print-str/println-str/prn-str Tests", .serialized)
struct CorePrintStrTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - print-str

    @Test("print-str joins arguments with spaces, str-style")
    func printStrBasic() throws {
        #expect(try swish.eval(#"(print-str "a" "string")"#) == .string("a string"))
    }

    @Test("print-str with the fixture's full multi-type argument list")
    func printStrMultiType() throws {
        #expect(try swish.eval(#"(print-str nil "a" "string" \A \space 1 17.0 [:a :b] {:c :d} #{:e})"#) == .string("nil a string A   1 17.0 [:a :b] {:c :d} #{:e}"))
    }

    @Test("(print-str) with no args returns an empty string")
    func printStrNoArgs() throws {
        #expect(try swish.eval("(print-str)") == .string(""))
    }

    // MARK: - println-str

    @Test("println-str joins arguments with spaces, str-style, with a trailing newline")
    func printlnStrBasic() throws {
        #expect(try swish.eval(#"(println-str "a" "string")"#) == .string("a string\n"))
    }

    @Test("println-str with the fixture's full multi-type argument list")
    func printlnStrMultiType() throws {
        #expect(try swish.eval(#"(println-str nil "a" "string" \A \space 1 17.0 [:a :b] {:c :d} #{:e})"#) == .string("nil a string A   1 17.0 [:a :b] {:c :d} #{:e}\n"))
    }

    @Test("(println-str) with no args returns just a newline")
    func printlnStrNoArgs() throws {
        #expect(try swish.eval("(println-str)") == .string("\n"))
    }

    // MARK: - prn-str

    @Test("prn-str joins arguments with spaces, pr-style (readable), with a trailing newline")
    func prnStrBasic() throws {
        #expect(try swish.eval(#"(prn-str "a" "string")"#) == .string("\"a\" \"string\"\n"))
    }

    @Test("prn-str with the fixture's full multi-type argument list")
    func prnStrMultiType() throws {
        #expect(try swish.eval(#"(prn-str nil "a" "string" \A \space 1 17.0 [:a :b] {:c :d} #{:e})"#) == .string("nil \"a\" \"string\" \\A \\space 1 17.0 [:a :b] {:c :d} #{:e}\n"))
    }

    @Test("(prn-str) with no args returns just a newline")
    func prnStrNoArgs() throws {
        #expect(try swish.eval("(prn-str)") == .string("\n"))
    }
}
