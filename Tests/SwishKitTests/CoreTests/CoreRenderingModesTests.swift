import Testing
@testable import SwishKit

/// The three printer renderings, and the special doubles that spell differently in each.
///
/// Swish previously had only two: `pr` and a single "human" rendering shared by `str` and
/// the `print` family. Clojure has three, and the difference is *how far down* the
/// unquoting reaches:
///
/// - `pr` — readable everywhere; must round-trip through the reader.
/// - `str` — the value's `toString`. A top-level string is itself, but a *collection*'s
///   `toString` is pr-based, so its elements stay readable.
/// - `print` — `(binding [*print-readably* nil] (pr …))`: string/char quoting is
///   suppressed at every depth, but nothing else changes.
@Suite("Core Rendering Modes Tests", .serialized)
struct CoreRenderingModesTests {
    static let _shared: Swish = {
        let swish = Swish()
        _ = try? swish.eval("(require '[clojure.string])")
        return swish
    }()
    var swish: Swish { Self._shared }

    // MARK: - str reaches only one level down

    @Test("str keeps a nested string, char and nil readable even though a top-level string is raw")
    func strElementsAreReadable() throws {
        #expect(try swish.eval(#"(str ["a"])"#) == .string(#"["a"]"#))
        #expect(try swish.eval(#"(str [\a])"#) == .string(#"[\a]"#))
        #expect(try swish.eval(#"(str [nil])"#) == .string("[nil]"))
        #expect(try swish.eval(#"(str {:a "x"})"#) == .string(#"{:a "x"}"#))
        #expect(try swish.eval(#"(str '("a"))"#) == .string(#"("a")"#))
        #expect(try swish.eval(#"(str #{"a"})"#) == .string(#"#{"a"}"#))
    }

    @Test("str keeps numeric-literal suffixes and tags on nested values")
    func strElementsKeepTags() throws {
        #expect(try swish.eval("(str [1N])") == .string("[1N]"))
        #expect(try swish.eval("(str [1.5M])") == .string("[1.5M]"))
        #expect(try swish.eval(#"(str [#uuid "00000000-0000-0000-0000-000000000001"])"#)
                == .string(#"[#uuid "00000000-0000-0000-0000-000000000001"]"#))
    }

    @Test("Nesting two deep stays readable all the way in")
    func strNestedTwoDeep() throws {
        #expect(try swish.eval(#"(str {:a ["x" {:b "y"}]})"#) == .string(#"{:a ["x" {:b "y"}]}"#))
    }

    @Test("A top-level scalar keeps str's own plain rendering — unchanged")
    func strScalarsUnchanged() throws {
        #expect(try swish.eval(#"(str "x")"#) == .string("x"))
        #expect(try swish.eval(#"(str \a)"#) == .string("a"))
        #expect(try swish.eval("(str nil)") == .string(""))
        #expect(try swish.eval("(str 1N)") == .string("1"))
        #expect(try swish.eval("(str 1.5M)") == .string("1.5"))
        #expect(try swish.eval("(str :k)") == .string(":k"))
        #expect(try swish.eval("(str 'sym)") == .string("sym"))
        #expect(try swish.eval(#"(str "a" nil "b")"#) == .string("ab"))
    }

    @Test("str's downstream consumers inherit the readable elements")
    func strDownstream() throws {
        #expect(try swish.eval(#"(clojure.string/join "," [["a"] ["b"]])"#) == .string(#"["a"],["b"]"#))
        #expect(try swish.eval(#"(format "%s" {:a "x"})"#) == .string(#"{:a "x"}"#))
    }

    // MARK: - print reaches all the way down

    @Test("print unquotes strings and chars at every depth")
    func printUnquotesDeeply() throws {
        #expect(try swish.eval(#"(print-str ["a"])"#) == .string("[a]"))
        #expect(try swish.eval(#"(print-str [\a])"#) == .string("[a]"))
        #expect(try swish.eval(#"(print-str {:a "x"})"#) == .string("{:a x}"))
    }

    @Test("print leaves everything that is not a string or char readable")
    func printKeepsEverythingElseReadable() throws {
        #expect(try swish.eval("(print-str [nil])") == .string("[nil]"))
        #expect(try swish.eval("(print-str nil)") == .string("nil"))
        #expect(try swish.eval("(print-str 1N)") == .string("1N"))
        #expect(try swish.eval("(print-str 1.5M)") == .string("1.5M"))
        #expect(try swish.eval(#"(print-str #uuid "00000000-0000-0000-0000-000000000001")"#)
                == .string(#"#uuid "00000000-0000-0000-0000-000000000001""#))
    }

    @Test("println-str appends a newline; the *-str family separates args with spaces")
    func printlnStrAndSeparators() throws {
        #expect(try swish.eval(#"(println-str "a" "b")"#) == .string("a b\n"))
        #expect(try swish.eval(#"(print-str "a" "b")"#) == .string("a b"))
        #expect(try swish.eval(#"(prn-str "a")"#) == .string("\"a\"\n"))
        #expect(try swish.eval(#"(pr-str "a")"#) == .string(#""a""#))
    }

    @Test("print writes the same rendering to *out* that print-str returns")
    func printMatchesPrintStr() throws {
        #expect(try swish.eval(#"(with-out-str (print {:a "x"}))"#) == .string("{:a x}"))
        #expect(try swish.eval(#"(with-out-str (println [nil]))"#) == .string("[nil]\n"))
        #expect(try swish.eval(#"(with-out-str (pr {:a "x"}))"#) == .string(#"{:a "x"}"#))
    }

    // MARK: - Special doubles

    @Test("pr emits the reader literals ##Inf / ##-Inf / ##NaN")
    func prSpecialDoubles() throws {
        #expect(try swish.eval("(pr-str ##Inf)") == .string("##Inf"))
        #expect(try swish.eval("(pr-str ##-Inf)") == .string("##-Inf"))
        #expect(try swish.eval("(pr-str ##NaN)") == .string("##NaN"))
        #expect(try swish.eval("(pr-str [##Inf ##NaN])") == .string("[##Inf ##NaN]"))
    }

    @Test("str emits Java's toString names Infinity / -Infinity / NaN")
    func strSpecialDoubles() throws {
        #expect(try swish.eval("(str ##Inf)") == .string("Infinity"))
        #expect(try swish.eval("(str ##-Inf)") == .string("-Infinity"))
        #expect(try swish.eval("(str ##NaN)") == .string("NaN"))
    }

    /// Inside a collection `str` is pr-based, so the elements take the *reader* spelling
    /// even though a top-level `(str ##Inf)` is "Infinity".
    @Test("A special double nested in a collection takes the reader spelling under str")
    func strNestedSpecialDoubles() throws {
        #expect(try swish.eval("(str [##Inf])") == .string("[##Inf]"))
    }

    @Test("print keeps the reader literals — *print-readably* nil does not affect numbers")
    func printSpecialDoubles() throws {
        #expect(try swish.eval("(print-str ##Inf)") == .string("##Inf"))
        #expect(try swish.eval("(print-str ##NaN)") == .string("##NaN"))
    }

    /// The point of the reader literals: `+∞`, which `NumberFormatter` used to produce,
    /// does not read back.
    @Test("pr-str output for the special doubles reads back to the same value")
    func specialDoublesRoundTrip() throws {
        #expect(try swish.eval("(= ##Inf (read-string (pr-str ##Inf)))") == .boolean(true))
        #expect(try swish.eval("(= ##-Inf (read-string (pr-str ##-Inf)))") == .boolean(true))
        #expect(try swish.eval("(NaN? (read-string (pr-str ##NaN)))") == .boolean(true))
    }

    @Test("Ordinary doubles and floats are untouched by the special-value check")
    func ordinaryDoublesUnchanged() throws {
        #expect(try swish.eval("(pr-str 17.0)") == .string("17.0"))
        #expect(try swish.eval("(str 17.0)") == .string("17.0"))
        #expect(try swish.eval("(print-str 17.0)") == .string("17.0"))
        #expect(try swish.eval("(str (float 1.0))") == .string("1.0"))
        #expect(try swish.eval("(pr-str (float 1.0))") == .string("1.0"))
    }

    /// Exercised at the `Printer` level rather than through `eval`: `(float ##Inf)` throws
    /// by design ("Value out of range for float"), so a `.float` infinity is unreachable
    /// from Swish code and the printer's `.float` arm has no other way to be covered.
    @Test("A float infinity gets the same treatment as a double infinity in each mode")
    func floatSpecialDoubles() throws {
        let printer = Printer()
        #expect(printer.printString(.float(.infinity)) == "##Inf")
        #expect(printer.printString(.float(-.infinity)) == "##-Inf")
        #expect(printer.printString(.float(.nan)) == "##NaN")
        #expect(printer.strString(.float(.infinity)) == "Infinity")
        #expect(printer.strString(.float(-.infinity)) == "-Infinity")
        #expect(printer.strString(.float(.nan)) == "NaN")
        #expect(printer.sourceForm(.float(.infinity)) == "##Inf")
        #expect(printer.sourceForm(.double(.infinity)) == "##Inf")
    }
}
