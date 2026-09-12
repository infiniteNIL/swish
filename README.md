![Swish logo](logo.png)

Swish is a Clojure inspired Lisp designed to be embedded in a Swift app or to be compiled to Swift to build with your app. It started out being written with Claude Caude as an experiment for the author to practice agentic coding, and has turned
into a full-blown Clojure implementation.

## Embedding Swish in a Swift app

Everything goes through `Swish` — create one, load some Swish source, and call back
and forth.

```swift
import SwishKit

let swish = Swish()
try swish.load(filename: "app.swish")
```

### Calling Swish from Swift

Results convert to the Swift type you ask for, from `eval` as well as `call`:

```swift
let greeting: String = try swish.call("hello", "Swish")
let numbers: [Int] = try swish.eval("(range 1 5)")
let tally = try swish.eval("{:a 1 :b 2}", as: [String: Int].self)
```

A function value works too — one from `eval`, or one Swish handed back:

```swift
let addTen = try swish.call("adder", 10)
let result: Int = try swish.call(addTen, 32)      // 42
```

Use `function(named:)` to resolve once and call repeatedly, and `Expr.decode(_:)`
when you're holding a raw value.

### Calling Swift from Swish

Register the function you already have. No wrapper, no `Expr` handling — arguments and
the return value are converted for you.

```swift
func getVowels(_ name: String) -> [Character] {
    name.filter { "aeiou".contains($0) }
}

swish.register(getVowels, as: "get-vowels")
```
```clojure
(get-vowels "hello")   ;=> [\e \o]
```

Methods work the same way, including on a view model:

```swift
swish.register(viewModel.formatPrice, as: "format-price")
try swish.define(appVersion, as: "app-version")
```

Order doesn't matter — registering after loading your Swish source works too.

`Int`, `Double`, `Bool`, `String`, `Character`, `Date`, `UUID`, `BigInt`, `Optional`,
`Array`, `Set`, `Dictionary` and `Expr` itself all convert automatically. A trailing
`Optional` parameter may be omitted at the Swish call site. Take an `Expr` parameter
when you want the raw Swish value.

### Structs, from maps and records

Conform a `Codable` type to `SwishCodable` and it converts to and from a Swish map —
or a `defrecord`, whose fields are keyword-keyed either way.

```swift
struct Point: Codable, SwishCodable { var x: Int; var y: Int }

let p: Point = try swish.eval("{:x 1 :y 2}")
let moved: Point = try swish.call("shift", p, 10)
```

A bad field reports which one, as a `DecodingError` with a coding path.

### Infinite sequences

Converting a lazy seq to an array realizes it in full, so `(range)` would never
return. Read a bounded slice instead:

```swift
let first10 = try swish.eval("(range)").prefix(10, of: Int.self)

try swish.eval("(naturals)").forEach(of: Int.self) { n in
    if n > 100 { throw Done() }
}
```

### Passing your own types through

Conform to `SwishOpaque` and your type crosses the boundary as an opaque handle —
Swish can hold it and hand it back, without knowing what it is.

```swift
extension User: SwishOpaque {}

swish.register(loadUser, as: "load-user")     // (String) -> User
swish.register(\User.name, as: "user-name")   // (User) -> String
```

### Errors

Everything Swish throws conforms to `SwishError`:

```swift
do {
    try swish.load(filename: "app.swish")
}
catch let error as any SwishError {
    print("Swish: \(error)")
}
```

An error thrown out of a registered Swift function becomes a catchable
`ExceptionInfo` on the Swish side:

```clojure
(try (risky-swift-thing)
     (catch ExceptionInfo e
       (println (ex-message e) (:swift-error-type (ex-data e)))))
```

### Keywords

A Swish keyword decodes as a Swift `String` (its name), which is what makes
`[String: Int]` read `{:a 1 :b 2}`. When you need to *produce* a keyword, or to hand a
map back without its keys turning into strings, use `Keyword`:

```swift
let tally: [Keyword: Int] = try swish.eval("{:a 1}")
try swish.call("assoc", m, Keyword("status"), "ok")
```

### Rendering values

Interpolating an `Expr` prints the value. `swish.printString(_:)` (`pr-str`) and
`swish.toString(_:)` (`str`) give you the two Clojure renderings explicitly, and
`Expr.typeName` gives the type.
