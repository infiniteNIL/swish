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

```swift
let greeting: String = try swish.call("hello", "Swish")
let total: Int = try swish.call("sum", [1, 2, 3])
```

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
swish.define(appVersion, as: "app-version")
```

Order doesn't matter — registering after loading your Swish source works too.

`Int`, `Double`, `Bool`, `String`, `Character`, `Date`, `UUID`, `BigInt`, `Optional`,
`Array`, `Set`, `Dictionary` and `Expr` itself all convert automatically. A trailing
`Optional` parameter may be omitted at the Swish call site. Take an `Expr` parameter
when you want the raw Swish value.

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

### Rendering values

`Expr.description` is the value's *type name*, not its contents. To render a value,
use `swish.printString(_:)` (like `pr-str`) or `swish.toString(_:)` (like `str`).
