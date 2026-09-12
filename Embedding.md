# Embedding Swish in a Swift app

Swish is designed to be driven from Swift: you evaluate Swish source, call Swish
functions with Swift values, and expose your own Swift functions for Swish code to call.

Everything goes through one type, `Swish`. The interpreter itself is not public — when
the host needs a capability, it's a method on `Swish`.

- [Getting started](#getting-started)
- [Calling Swish from Swift](#calling-swish-from-swift)
- [Calling Swift from Swish](#calling-swift-from-swish)
- [Value conversion](#value-conversion)
- [Structs](#structs)
- [Your own types, passed through](#your-own-types-passed-through)
- [Sequences](#sequences)
- [Errors](#errors)
- [Namespaces](#namespaces)
- [Working with raw values](#working-with-raw-values)
- [API reference](#api-reference)
- [Not supported yet](#not-supported-yet)

---

## Getting started

```swift
import SwishKit

let swish = Swish()
try swish.load(filename: "app.swish")
```

`load(filename:)` searches the paths given to the initializer, plus the main bundle, the
SwishKit bundle, `$SWISH_SOURCEPATH`, and the current directory:

```swift
let swish = Swish(sourcePaths: ["/opt/scripts"])
```

`eval(_:)` evaluates source and returns the value of its last form:

```swift
let result = try swish.eval("(+ 1 2)")      // Expr
```

It isn't `@discardableResult`, so use `_ =` when you only want the side effect:

```swift
_ = try swish.eval("(defn hello [s] (str \"Hello, \" s \"!\"))")
```

## Calling Swish from Swift

### Typed results

Ask for the Swift type you want and the conversion happens for you:

```swift
let sum: Int = try swish.eval("(+ 1 2)")                      // 3
let numbers: [Int] = try swish.eval("(range 1 5)")            // [1, 2, 3, 4]
let tally = try swish.eval("(tally)", as: [String: Int].self) // ["apples": 3, "pears": 5]
```

The `as:` argument is inferred from context; pass it explicitly where there's nothing to
infer from, such as inside a string interpolation.

### Calling a function by name

`call` avoids building a source string, so there's no quoting or escaping, and you can
pass values that have no literal form (a `Date`, or one of your own types):

```swift
let greeting: String = try swish.call("hello", "Swish")   // "Hello, Swish!"
```

The name may be namespace-qualified (`"clojure.string/upper-case"`) or resolved in the
current namespace. Note that a qualified name in a lib that hasn't been `require`d yet is
an error, the same as in Clojure.

### Function values

A Swish function is a value. You can hold one and call it:

```swift
let addTen = try swish.call("adder", 10)          // (fn [x] (+ x 10))
let answer: Int = try swish.call(addTen, 32)      // 42
```

`function(named:)` resolves once, which is worth doing when you call the same function
repeatedly — `call(_ name:…)` re-resolves the var every time:

```swift
let hello = try swish.function(named: "hello")
let a: String = try swish.call(hello, "again")    // "Hello, again!"
```

When the arguments are assembled at runtime, use the `arguments:` form — the variadic one
can't take an array:

```swift
let args: [any SwishRepresentable] = [1, 2, 3, 4]
let total: Int = try swish.call("total", arguments: args)     // 10
```

Swish's other callables work too, matching Clojure — a keyword, map, vector or set:

```swift
let name: String = try swish.call(Expr.keyword("name"), person)
```

### Converting a value you already have

```swift
let raw = try swish.eval("[1 2 3]")

let xs = try raw.decode([Int].self)     // throws SwishConversionError
let ys = [Int](swishValue: raw)         // Optional([1, 2, 3])
```

Use `decode` when you want to know what failed, and `T(swishValue:)` when an optional is
enough.

## Calling Swift from Swish

### Registering a function

Pass the function you already have. No wrapper, no `Expr` handling:

```swift
func getVowels(_ name: String) -> [Character] {
    let vowels: Set<Character> = ["a", "e", "i", "o", "u"]
    return Array(name.lowercased().filter { vowels.contains($0) })
}

swish.register(getVowels, as: "get-vowels")
```

```clojure
(get-vowels "hello world")   ;=> [\e \o \o]
```

Methods work the same way, including on a view model — `swish.register(viewModel.format,
as: "format")`.

> **Threading.** A registered function runs **synchronously on whatever thread evaluates
> the calling form**. Swish runs agents, futures and STM commits on background queues, so
> a function isolated to an actor — a `@MainActor` view-model method, say — is only safe
> if you confine evaluation to that actor's thread. This is the price of accepting
> non-`Sendable` closures, which is what lets an ordinary method be registered at all.

### Arities and optional arguments

A trailing run of `Optional` parameters may be omitted at the Swish call site:

```swift
swish.register({ (base: Int, exponent: Int?) in
    Int(pow(Double(base), Double(exponent ?? 2)))
}, as: "power")
```

```clojure
[(power 3) (power 2 10)]     ;=> [9 1024]
```

Everything before the first optional is required, and passing too many or too few
arguments is an arity error naming the range.

### Functions that return nothing

A `Void`-returning function evaluates to `nil` in Swish:

```swift
swish.register({ (line: String) in log.append(line) }, as: "log!")
```

### Documentation

`doc:` and `parameters:` feed `(doc f)` — Swift can't reflect parameter names, so they
default to `arg1`, `arg2`, …:

```swift
swish.register(getVowels, as: "get-vowels",
               doc: "Returns the vowels in s.", parameters: ["s"])
```

```clojure
(:doc (meta #'get-vowels))        ;=> "Returns the vowels in s."
(:arglists (meta #'get-vowels))   ;=> ([s])
```

### Namespaces and constants

By default a registration lands in `clojure.core`, so the name is available unqualified.
Pass `in:` to target another namespace instead, creating it if needed:

```swift
swish.register({ 7 }, as: "lucky", in: "app")    // (app/lucky) => 7
try swish.define("1.2.3", as: "app-version")     // app-version => "1.2.3"
```

Order doesn't matter: a function registered *after* its Swish source has loaded is
back-filled into namespaces that already referred `clojure.core`.

### Genuinely variadic functions

When the typed form can't express the shape — a `& rest` function, or one that inspects
its arguments before deciding what they mean — take the raw values:

```swift
swish.register(as: "sum-all", arity: .variadic) { args in
    .integer(args.compactMap { Int(swishValue: $0) }.reduce(0, +))
}
```

`Arity` is `.fixed(n)`, `.atLeastOne`, `.variadic`, or `.range(min...max)`.

## Value conversion

A type crosses the boundary if it conforms to `SwishRepresentable` (Swift → Swish),
`SwishDecodable` (Swish → Swift), or `SwishConvertible` (both). These ship conforming:

| Swift | Swish |
|---|---|
| `Int`, `Int8`…`Int64`, `UInt`…`UInt64` | integer (exact; a bigint converts when it fits) |
| `Double`, `Float` | double / float — also accepts integers and ratios |
| `BigInt`, `BigDecimal`, `Ratio` | bigint, bigdec, ratio |
| `Bool` | boolean |
| `String` | string — **also accepts a keyword's or symbol's name** |
| `Character` | character |
| `Date` | `#inst` |
| `UUID` | `#uuid` |
| `Keyword`, `Symbol` | keyword, symbol |
| `Array<T>` | vector — decodes from any seqable |
| `Set<T>` | set |
| `Dictionary<K, V>` | map — decodes from a map, sorted map or record |
| `Optional<T>` | the value, or `nil` |
| `Expr` | itself — the escape hatch for anything else |

Integer conversion is deliberately strict: handing `(/ 1 2)` to a Swift `Int` is an
argument error, not a silent `0`. Floating-point conversion widens, so `(area 5)` can call
a `(Double) -> Double`.

### Keywords and symbols

A keyword decodes as a Swift `String` — its name — which is what lets `[String: Int]` read
the keyword-keyed maps that are the Clojure norm:

```swift
let tally: [String: Int] = try swish.eval("{:a 1 :b 2}")   // ["a": 1, "b": 2]
```

Two consequences, both deliberate:

- A registered `(String) -> …` accepts `(f :oops)`. Take an `Expr` parameter when a
  function needs to reject that.
- **The round trip is lossy.** A `String` always encodes back to a Swish *string*:

  ```swift
  let m: [String: Int] = try swish.eval("{:a 1 :b 2}")
  try swish.call("identity", m)        // {"a" 1 "b" 2}  — (:a m) now misses
  ```

Use `Keyword` when the distinction matters — to produce a keyword, or to round-trip one:

```swift
let tally: [Keyword: Int] = try swish.eval("{:a 1 :b 2}")
try swish.call("identity", tally)     // {:a 1 :b 2}
try swish.call("assoc", m, Keyword("status"), "ok")
```

`Keyword` and `Symbol` split a qualified name, and print the way Clojure's `str` does:

```swift
let kw = Keyword("user/name")
kw.namespace      // "user"
kw.name           // "name"
"\(kw)"           // ":user/name"   (a Symbol prints bare: "clojure.core/map")
```

`Symbol` carries no metadata, so `^:private` is dropped in both directions; use a raw
`Expr` if you need it.

> **Conforming your own scalar type.** `SwishConvertible` alone is enough for arguments,
> returns and collections. To also have it work as a *field of a `SwishCodable` struct*,
> conform it to `SwishLeafConvertible` (or make it `Codable`) — the Codable bridge only
> routes a closed set of leaf types directly, so that arrays and dictionaries keep their
> per-element error reporting.

## Structs

Conform a `Codable` type to `SwishCodable` and it converts to and from a Swish map. That
one line is the whole opt-in:

```swift
struct Point: Codable, SwishCodable {
    var x: Int
    var y: Int
}

let p: Point = try swish.eval("{:x 1 :y 2}")
let moved: Point = try swish.call("shift", p, 10)
swish.register({ (p: Point) in Point(x: p.y, y: p.x) }, as: "flip")
```

It reads a `defrecord` too — record fields are keyword-keyed either way:

```clojure
(defrecord Point [x y])
(defn origin-offset [] (->Point 3 4))
```
```swift
let point: Point = try swish.call("origin-offset")    // Point(x: 3, y: 4)
```

Encoding produces a map with **keyword** keys, which is what `(:x m)` expects:

```swift
try ExprEncoder().encode(Point(x: 3, y: 4))     // {:x 3 :y 4}
```

Swift properties are camelCase and idiomatic Clojure keys are kebab-case, so there's a key
strategy for that:

```swift
try ExprEncoder(keyStrategy: .kebabCaseKeyword).encode(person)
// {:first-name "Rod" :last-name "Schmidt"}
```

Both coders can be used directly when you want the error rather than an optional. A bad
field reports which one:

```swift
do {
    let _: Point = try swish.eval(#"{:x 1 :y "two"}"#)
}
catch let error as DecodingError {
    // typeMismatch, codingPath == ["y"]
}
```

Decoding reads maps, sorted maps and records. It does **not** read a `deftype` — matching
Clojure, where `defrecord` instances are associative and `deftype` instances are not.
Encoding produces a map, never a record; call `map->TypeName` with the encoded map when
you need an actual record instance.

## Your own types, passed through

When a type has no Swish representation and doesn't need one, conform it to `SwishOpaque`.
Swish can hold it, store it in collections and hand it back, without knowing what it is:

```swift
extension User: SwishOpaque {}

swish.register({ (n: String) in User(name: n) }, as: "make-user")
swish.register({ (u: User) in u.name.uppercased() }, as: "shout")
```
```clojure
(shout (make-user "rod"))    ;=> "ROD"
(pr-str (make-user "rod"))   ;=> "#object[User 0xc431ec6c0]"
```

Opaque values compare and hash by **identity** — the wrapped value is `Any`, so there's no
general way to compare it. Reference types keep their identity across the round trip.

A field of a `Codable` struct must itself be `Codable`, which an opaque handle isn't —
Swift rejects that at compile time. `SwishOpaqueCodable` supplies the conformance:

```swift
final class Session: SwishOpaqueCodable { var hits = 0 }

struct Request: Codable, SwishCodable {
    var path: String
    var session: Session
}
```

Encoding such a value through anything but `ExprEncoder` — a `JSONEncoder`, say — throws a
clear error rather than failing to build.

## Sequences

Swish sequences can be infinite. **Converting one to an array realizes it in full**, so
`[Int](swishValue:)` and `asArray()` never return on `(range)`. Read a bounded slice
instead:

```swift
let first5 = try swish.eval("(naturals)").prefix(5, of: Int.self)   // [0, 1, 2, 3, 4]
```

`forEach(of:_:)` streams, and can't hide an error — a realization failure or an element
that isn't a `T` throws, and the body can stop early by throwing:

```swift
struct Enough: Error {}
do {
    try swish.eval("(naturals)").forEach(of: Int.self) { n in
        seen.append(n)
        if n == 3 { throw Enough() }
    }
}
catch is Enough {}
```

`lazySequence(of:)` gives a `Sequence` for `for`-in. Because `next()` can't throw, it ends
iteration on a failure and records it — check `failure` when the loop finishes:

```swift
var iterator = try swish.eval("(naturals)").lazySequence(of: Int.self).makeIterator()
while taken.count < 3, let n = iterator.next() { taken.append(n) }
if let error = iterator.failure { throw error }
```

All three accept eager collections (vector, list, seq) as well as lazy ones.

> A lazy sequence runs Swish code as it's consumed, on whatever thread consumes it — the
> same contract as a registered function.

## Errors

Everything Swish throws conforms to `SwishError`, so one `catch` covers it:

```swift
do {
    try swish.load(filename: "app.swish")
}
catch let error as any SwishError {
    print("Swish: \(error)")       // Undefined symbol 'no-such-fn'.
}
```

The conformers are `LexerError` and `ParserError` (reading), `EvaluatorError` and
`NamespaceError` (evaluating), `SwishException` (a value thrown by Swish code, usually an
`ExceptionInfo`), `SwishConversionError` (a value that wasn't the Swift type asked for),
and `SwishLoadError` (a source file that couldn't be found). They're separate types rather
than cases of one enum, so matching a specific one still works:

```swift
catch let error as SwishConversionError {
    print(error.expected, error.value)    // Cannot convert "nope" to Int.
}
```

In the other direction, an error thrown out of a registered Swift function arrives in
Swish as a catchable `ExceptionInfo`:

```swift
struct HostFailure: Error, CustomStringConvertible { let description: String }
swish.register({ (n: Int) throws -> Int in throw HostFailure(description: "boom \(n)") },
               as: "explode")
```
```clojure
(try (explode 7)
     (catch ExceptionInfo e
       [(ex-message e) (ex-data e)]))
;=> ["boom 7" {:function "explode" :swift-error "boom 7" :swift-error-type "HostFailure"}]
```

`describeError(_:)` renders any caught error the way the REPL would.

## Namespaces

Namespaces are addressed by name; no namespace object escapes the façade.

```swift
swish.namespaceNames            // ["clojure.core", "clojure.swift.io", "demo", "user", …]
swish.namespaceExists("demo")   // true
try swish.inNamespace("demo")   // switches the current namespace
swish.currentNamespaceName      // "demo"
swish.names(in: "demo")         // the names bound there, sorted
```

Loading a file with an `(ns …)` form already switches to it, so `inNamespace` is for
moving back and forth afterwards.

## Working with raw values

`Expr` is the Swish value type. Interpolating one prints the value; `typeName` gives its
Swish type, which is what `type`, `instance?` and `catch` matching compare against:

```swift
let value = try swish.eval(#"["a" 1]"#)
"\(value)"                  // ["a" 1]
value.typeName              // "vector"
swish.printString(value)    // ["a" 1]        — like pr-str
swish.toString(value)       // ["a" 1]        — like str
```

`Expr` also has an `as*` family — `asInt()`, `asString()`, `asArray()`, `asDictionary()`,
`asSet()`, `asSequence()`, `asForeign()` and friends — as a raw convenience layer. The
typed bridge above is usually better: it reports what it expected when it fails, and
converts nested collections for you. Two `as*` accessors are deliberately looser than the
bridge: `asInt()` truncates a ratio (so `(/ 5 2)` reads as `2`), and `asString()` matches
`String`'s keyword-accepting behavior.

For long-running evaluation, `interruptionCheck` is polled during calls:

```swift
swish.interruptionCheck = { userPressedCancel }
```

## API reference

```swift
struct Swish {
    init(sourcePaths: [String] = [])
    func load(filename: String) throws
    func eval(_ source: String) throws -> Expr
    func eval<T: SwishDecodable>(_ source: String, as type: T.Type = T.self) throws -> T

    func call<R: SwishDecodable>(_ name: String, _ args: (any SwishRepresentable)...) throws -> R
    func call(_ name: String, _ args: (any SwishRepresentable)...) throws -> Expr
    func call<R: SwishDecodable>(_ name: String, arguments: [any SwishRepresentable]) throws -> R
    func call(_ name: String, arguments: [any SwishRepresentable]) throws -> Expr
    func call<R: SwishDecodable>(_ function: Expr, _ args: (any SwishRepresentable)...) throws -> R
    func call(_ function: Expr, _ args: (any SwishRepresentable)...) throws -> Expr
    func call<R: SwishDecodable>(_ function: Expr, arguments: [any SwishRepresentable]) throws -> R
    func call(_ function: Expr, arguments: [any SwishRepresentable]) throws -> Expr
    func function(named name: String) throws -> Expr

    func register<each A, R>(_ fn:, as:, in:, doc:, parameters:) -> Self
    func register<each A>(_ fn:, as:, in:, doc:, parameters:) -> Self        // Void return
    func register(as:, arity:, in:, doc:, body:) -> Self                     // raw ([Expr]) -> Expr
    func define(_ value: some SwishRepresentable, as:, in:) throws -> Self

    var namespaceNames: [String]
    func namespaceExists(_ name: String) -> Bool
    func inNamespace(_ name: String) throws
    func names(in namespace: String) -> [String]
    var currentNamespaceName: String

    func printString(_ expr: Expr) -> String
    func toString(_ expr: Expr) -> String
    func describeError(_ error: Error) -> String
    var interruptionCheck: (() -> Bool)?
}

extension Expr {
    func decode<T: SwishDecodable>(_ type: T.Type = T.self) throws -> T
    func prefix<T: SwishDecodable>(_ maxLength: Int, of type: T.Type = T.self) throws -> [T]
    func forEach<T: SwishDecodable>(of type: T.Type = T.self, _ body: (T) throws -> Void) throws
    func lazySequence<T: SwishDecodable>(of type: T.Type = T.self) -> SwishLazySequence<T>
    var typeName: String
}

protocol SwishRepresentable { var swishValue: Expr { get } }
protocol SwishDecodable     { init?(swishValue: Expr) }
typealias SwishConvertible = SwishRepresentable & SwishDecodable

protocol SwishLeafConvertible: SwishConvertible {}   // converts without a container
protocol SwishCodable: Codable, SwishConvertible {}  // struct ↔ map
protocol SwishOpaque: SwishConvertible {}            // passed through untouched
protocol SwishOpaqueCodable: SwishOpaque, Codable {} // …and usable as a Codable field

struct ExprEncoder { func encode(_ value: some Encodable) throws -> Expr }
struct ExprDecoder { func decode<T: Decodable>(_: T.Type, from: Expr) throws -> T }

protocol SwishError: Error, CustomStringConvertible {}
struct Keyword / struct Symbol
```

## Not supported yet

- **`async` Swift functions.** Natives are synchronous; bridging would need a
  future/promise hand-off.
- **ObjC/Swift runtime dispatch** — the `.` special form for calling arbitrary methods on
  host objects. `SwishOpaque` plus a registered function covers most of the need today.
- **An `@SwishExport` macro** to derive the Swish name and registration from a plain
  `func`. It would need a swift-syntax plugin target.

Two sharp edges worth knowing:

- A **macro** value passed to `call` is expanded but not evaluated, so you get the
  expansion form rather than a result.
- `call`'s arguments are existential varargs rather than a parameter pack, so unlike
  `register`'s they aren't type-checked per position — every argument only needs to be
  `SwishRepresentable`.
