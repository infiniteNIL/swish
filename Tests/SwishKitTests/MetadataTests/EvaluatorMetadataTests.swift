import Testing
@testable import SwishKit

@Suite("Evaluator Metadata Tests")
struct EvaluatorMetadataTests {
    let swish = Swish()

    // MARK: - meta / with-meta round-trip

    @Test("meta on value with no metadata returns nil")
    func metaOnNoMetadata() throws {
        #expect(try swish.eval("(meta [1 2 3])") == .nil)
    }

    @Test("meta on set with metadata returns the metadata map")
    func metaOnSetWithMetadata() throws {
        let result = try swish.eval("(meta (with-meta #{1 2} {:x 1}))")
        #expect(result == .map([.keyword("x"): .integer(1)], metadata: nil))
    }

    @Test("meta on set with no metadata returns nil")
    func metaOnSetNoMetadata() throws {
        #expect(try swish.eval("(meta #{1 2})") == .nil)
    }

    @Test("with-meta attaches metadata, meta retrieves it")
    func withMetaRoundTrip() throws {
        let result = try swish.eval("(meta (with-meta [1 2] {:a 1}))")
        #expect(result == .map([.keyword("a"): .integer(1)], metadata: nil))
    }

    @Test("with-meta nil clears metadata")
    func withMetaNilClearsMeta() throws {
        let result = try swish.eval("(meta (with-meta (with-meta [] {:a 1}) nil))")
        #expect(result == .nil)
    }

    @Test("with-meta on original does not mutate it")
    func withMetaDoesNotMutate() throws {
        let result = try swish.eval("(let [v [1 2]] (with-meta v {:x 1}) (meta v))")
        #expect(result == .nil)
    }

    @Test("meta on keyword returns nil")
    func metaOnKeyword() throws {
        #expect(try swish.eval("(meta :foo)") == .nil)
    }

    @Test("meta on integer returns nil")
    func metaOnInteger() throws {
        #expect(try swish.eval("(meta 42)") == .nil)
    }

    // MARK: - vary-meta

    @Test("vary-meta applies function to current metadata")
    func varyMeta() throws {
        let result = try swish.eval("(meta (vary-meta (with-meta [] {:a 1}) (fn [m] {:b 2})))")
        #expect(result == .map([.keyword("b"): .integer(2)], metadata: nil))
    }

    @Test("vary-meta on nil metadata passes nil as first arg to function")
    func varyMetaOnNilMeta() throws {
        let result = try swish.eval("(meta (vary-meta [] (fn [m] {:x 99})))")
        #expect(result == .map([.keyword("x"): .integer(99)], metadata: nil))
    }

    // MARK: - Metadata preserved through eval

    @Test("Metadata on vector is preserved through eval")
    func metaPreservedThroughVectorEval() throws {
        let result = try swish.eval("(meta (with-meta [(+ 1 1)] {:tag \"Vec\"}))")
        #expect(result == .map([.keyword("tag"): .string("Vec")], metadata: nil))
    }

    // MARK: - def transfers symbol metadata to var

    @Test("^:private on def symbol sets var metadata")
    func defTransfersSymbolMetadata() throws {
        let swish2 = Swish()
        _ = try swish2.eval("(def ^:private ^{:doc \"hello\"} myvar 42)")
        let result = try swish2.eval("(meta #'user/myvar)")
        #expect(result == .map([
            .keyword("private"): .boolean(true),
            .keyword("doc"): .string("hello")
        ], metadata: nil))
    }

    // MARK: - defmacro doc string

    @Test("defmacro doc string is stored under :doc in var metadata")
    func defmacroDocStringInMetadata() throws {
        let swish2 = Swish()
        _ = try swish2.eval("(defmacro my-mac \"Does a thing\" [x] x)")
        let result = try swish2.eval("(meta #'user/my-mac)")
        #expect(result == .map([
            .keyword("doc"): .string("Does a thing"),
            .keyword("arglists"): .list([.vector([.symbol("x", metadata: nil)], metadata: nil)], metadata: nil)
        ], metadata: nil))
    }

    @Test("defmacro ^-metadata and doc string are merged")
    func defmacroMetadataAndDocStringMerged() throws {
        let swish2 = Swish()
        _ = try swish2.eval("(defmacro ^:private my-mac \"Docs\" [x] x)")
        let result = try swish2.eval("(meta #'user/my-mac)")
        #expect(result == .map([
            .keyword("private"): .boolean(true),
            .keyword("doc"): .string("Docs"),
            .keyword("arglists"): .list([.vector([.symbol("x", metadata: nil)], metadata: nil)], metadata: nil)
        ], metadata: nil))
    }

    // MARK: - reset-meta!

    @Test("reset-meta! replaces var metadata")
    func resetMeta() throws {
        let swish2 = Swish()
        _ = try swish2.eval("(def myvar 1)")
        _ = try swish2.eval("(reset-meta! #'user/myvar {:x 99})")
        let result = try swish2.eval("(meta #'user/myvar)")
        #expect(result == .map([.keyword("x"): .integer(99)], metadata: nil))
    }

    // MARK: - defn doc string and attr map

    @Test("defn with doc string stores :doc and :arglists in var metadata")
    func defnDocString() throws {
        let swish2 = Swish()
        _ = try swish2.eval("(defn greet \"Says hi\" [name] (str \"hi \" name))")
        let result = try swish2.eval("(meta #'user/greet)")
        let expected: Expr = .map([
            .keyword("doc"): .string("Says hi"),
            .keyword("arglists"): .list([.vector([.symbol("name", metadata: nil)], metadata: nil)], metadata: nil)
        ], metadata: nil)
        #expect(result == expected)
    }

    @Test("defn without doc string stores :arglists in var metadata")
    func defnNoDocString() throws {
        let swish2 = Swish()
        _ = try swish2.eval("(defn greet [name] name)")
        let result = try swish2.eval("(meta #'user/greet)")
        let expected: Expr = .map([
            .keyword("arglists"): .list([.vector([.symbol("name", metadata: nil)], metadata: nil)], metadata: nil)
        ], metadata: nil)
        #expect(result == expected)
    }

    @Test("defn with doc string evaluates correctly")
    func defnWithDocStringEvaluates() throws {
        let swish2 = Swish()
        _ = try swish2.eval("(defn double \"Doubles x\" [x] (* x 2))")
        #expect(try swish2.eval("(double 21)") == .integer(42))
    }

    @Test("defn with attr map stores attributes and arglists in var metadata")
    func defnAttrMap() throws {
        let swish2 = Swish()
        _ = try swish2.eval("(defn foo {:added \"1.0\"} [x] x)")
        let result = try swish2.eval("(meta #'user/foo)")
        #expect(result == .map([
            .keyword("added"): .string("1.0"),
            .keyword("arglists"): .list([.vector([.symbol("x", metadata: nil)], metadata: nil)], metadata: nil)
        ], metadata: nil))
    }

    @Test("defn with doc string and attr map merges both")
    func defnDocAndAttr() throws {
        let swish2 = Swish()
        _ = try swish2.eval("(defn foo \"Docs\" {:static true} [x] x)")
        let result = try swish2.eval("(meta #'user/foo)")
        #expect(result == .map([
            .keyword("doc"): .string("Docs"),
            .keyword("static"): .boolean(true),
            .keyword("arglists"): .list([.vector([.symbol("x", metadata: nil)], metadata: nil)], metadata: nil)
        ], metadata: nil))
    }

    @Test("defmacro with attr map stores attributes in var metadata")
    func defmacroAttrMap() throws {
        let swish2 = Swish()
        _ = try swish2.eval("(defmacro my-mac {:added \"1.0\"} [x] x)")
        let result = try swish2.eval("(meta #'user/my-mac)")
        #expect(result == .map([
            .keyword("added"): .string("1.0"),
            .keyword("arglists"): .list([.vector([.symbol("x", metadata: nil)], metadata: nil)], metadata: nil)
        ], metadata: nil))
    }

    @Test("defmacro with doc string and attr map merges both")
    func defmacroDocAndAttr() throws {
        let swish2 = Swish()
        _ = try swish2.eval("(defmacro my-mac \"Docs\" {:static true} [x] x)")
        let result = try swish2.eval("(meta #'user/my-mac)")
        #expect(result == .map([
            .keyword("doc"): .string("Docs"),
            .keyword("static"): .boolean(true),
            .keyword("arglists"): .list([.vector([.symbol("x", metadata: nil)], metadata: nil)], metadata: nil)
        ], metadata: nil))
    }

    // MARK: - *print-meta*

    @Test("*print-meta* starts as false")
    func printMetaDefaultsFalse() throws {
        let result = try swish.eval("*print-meta*")
        #expect(result == .boolean(false))
    }

    // MARK: - namespace with-meta

    @Test("with-meta on a namespace updates its metadata")
    func withMetaOnNamespace() throws {
        _ = try swish.eval("(with-meta (find-ns 'user) {:x 1})")
        let result = try swish.eval("(meta (find-ns 'user))")
        #expect(result == .map([.keyword("x"): .integer(1)], metadata: nil))
        _ = try swish.eval("(with-meta (find-ns 'user) nil)")
    }

    @Test("with-meta nil clears namespace metadata")
    func withMetaNilClearsNamespaceMeta() throws {
        _ = try swish.eval("(with-meta (find-ns 'user) {:k 1})")
        _ = try swish.eval("(with-meta (find-ns 'user) nil)")
        let result = try swish.eval("(meta (find-ns 'user))")
        #expect(result == .nil)
    }

    @Test("vary-meta on a namespace works")
    func varyMetaOnNamespace() throws {
        let swish = Swish()
        _ = try swish.eval("(ns vmeta-test \"original\")")
        _ = try swish.eval("(vary-meta *ns* assoc :extra \"value\")")
        let result = try swish.eval("(meta *ns*)")
        #expect(result == .map([
            .keyword("doc"): .string("original"),
            .keyword("extra"): .string("value")
        ], metadata: nil))
    }

    // MARK: - resolve

    @Test("resolve returns varRef for known symbol")
    func resolveKnownSymbol() throws {
        let swish2 = Swish()
        _ = try swish2.eval("(defn foo [x] x)")
        let result = try swish2.eval("(resolve 'foo)")
        guard case .varRef(let v) = result else {
            Issue.record("Expected varRef"); return
        }
        #expect(v.name == "foo")
    }

    @Test("resolve returns nil for unknown symbol")
    func resolveUnknownSymbol() throws {
        let swish2 = Swish()
        #expect(try swish2.eval("(resolve 'no-such-var)") == .nil)
    }

    // MARK: - doc (smoke tests — doc prints to stdout)

    @Test("doc does not throw for known var")
    func docKnownVar() throws {
        let swish2 = Swish()
        _ = try swish2.eval("(defn add \"Adds two numbers\" [a b] (+ a b))")
        #expect(throws: Never.self) { try swish2.eval("(doc add)") }
    }

    @Test("doc returns nil for unknown var without throwing")
    func docUnknownVar() throws {
        let swish2 = Swish()
        #expect(try swish2.eval("(doc no-such-var)") == .nil)
    }

    // MARK: - def docstring

    @Test("def with docstring stores :doc in var metadata")
    func defDocstring() throws {
        let swish2 = Swish()
        _ = try swish2.eval("(def pi \"The ratio of a circle's circumference.\" 3.14159)")
        let result = try swish2.eval("(-> #'pi meta :doc)")
        #expect(result == .string("The ratio of a circle's circumference."))
    }

    @Test("def with docstring and no value creates unbound var with doc")
    func defDocstringNoValue() throws {
        let swish2 = Swish()
        _ = try swish2.eval("(def placeholder \"Not yet defined.\")")
        let result = try swish2.eval("(-> #'placeholder meta :doc)")
        #expect(result == .string("Not yet defined."))
    }

    @Test("def with docstring and symbol metadata merges both")
    func defDocstringWithSymMeta() throws {
        let swish2 = Swish()
        _ = try swish2.eval("(def ^:private pi \"Ratio of circumference to diameter.\" 3.14159)")
        let result = try swish2.eval("[(-> #'pi meta :doc) (-> #'pi meta :private)]")
        #expect(result == .vector([.string("Ratio of circumference to diameter."), .boolean(true)], metadata: nil))
    }

    @Test("plain def re-bind preserves existing metadata")
    func defPreservesMetadata() throws {
        let swish2 = Swish()
        _ = try swish2.eval("(def ^{:doc \"original\"} x 1)")
        _ = try swish2.eval("(def x 2)")
        let result = try swish2.eval("(-> #'x meta :doc)")
        #expect(result == .string("original"))
    }
}
