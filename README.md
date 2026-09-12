![Swish logo](logo.png)

Swish is a Clojure-inspired Lisp designed to be embedded in a Swift app, or compiled to
Swift and built alongside it. It started as an experiment in agentic coding — written with
Claude Code as practice for the author — and has turned into a full Clojure implementation.

```clojure
(ns demo
  (:require [clojure.string :as str]))

(defrecord Point [x y])

(defn greet [name]
  (str/join " " ["Hello," name]))

(defn describe [n]
  (cond
    (zero? n) "zero"
    (even? n) "even"
    :else     "odd"))

(println (greet "Swish"))                            ; Hello, Swish
(println (map #(* % %) (range 1 6)))                 ; (1 4 9 16 25)
(println (map describe [0 3 4]))                     ; (zero odd even)
(println (->Point 3 4) (:x (->Point 3 4)))           ; #Point{:x 3 :y 4} 3
(println (reduce + (take 10 (filter odd? (range))))) ; 100
```

## Requirements

Swift 6.4, macOS 15+ or iOS 18+.

## Building and running

```sh
swift build
swift run swish                   # start the REPL
swift run swish app.swish         # run a file
swift run swish -sp lib:vendor    # colon-separated namespace search path
```

In the REPL, `/help` lists the commands, `/quit` exits, and `/1`, `/2`, … refer back to
earlier results. Commands match on any unique prefix, so `/q` works.

Ctrl-C interrupts a running evaluation; at an idle prompt it exits. Part-way through a
multi-line form it abandons the form and returns to the main prompt.

```
user(1)> [1 2 3]
=> [1 2 3]
user(2)> (map inc /1)
=> (2 3 4)
```

## What's implemented

Swish aims at real Clojure semantics rather than a subset:

- **Persistent data structures** — bit-partitioned vectors, HAMT maps and sets, cons
  lists, sorted maps and sets with custom comparators
- **Lazy sequences**, including infinite ones, and the full sequence library
- **Transducers** — `comp`, `transduce`, `into`, `sequence`, `eduction`, `reduced`
- **Macros** with syntax-quote, unquote-splicing and gensyms
- **Multimethods** with `derive`/`isa?` hierarchies and `prefer-method`
- **Protocols** — `defprotocol`, `deftype`, `defrecord`, `reify`, `extend-type`
- **Concurrency** — atoms, refs with STM (`dosync`, `alter`, `commute`), agents, futures,
  promises, delays, watches
- **Namespaces**, vars, dynamic binding, metadata, destructuring, regex, and the numeric
  tower (bigints, ratios, bigdecimals)

Shipped namespaces: `clojure.core`, `clojure.string`, `clojure.set`, `clojure.walk`,
`clojure.edn`, `clojure.test`, `clojure.template`.

Deliberate divergences from Clojure — mostly where the JVM's class hierarchy or bytecode
compiler has no counterpart — are documented in [CLAUDE.md](CLAUDE.md), with the reasoning
behind each in [NOTES.md](NOTES.md).

## Embedding in a Swift app

Evaluate Swish from Swift, and expose Swift functions for Swish to call. Both directions
convert values for you:

```swift
import SwishKit

let swish = Swish()
try swish.load(filename: "app.swish")

// Swish -> Swift
let numbers: [Int] = try swish.call("one-to-10")
let greeting: String = try swish.eval(#"(hello "Swish")"#)

// Swift -> Swish: register the function you already have
func getVowels(_ name: String) -> [Character] {
    let vowels: Set<Character> = ["a", "e", "i", "o", "u"]
    return Array(name.lowercased().filter { vowels.contains($0) })
}
swish.register(getVowels, as: "get-vowels")
```

```clojure
(get-vowels "hello world")   ;=> [\e \o \o]
```

**[Embedding.md](Embedding.md)** is the full guide: typed results, registering functions,
`Codable` structs from maps and records, passing your own types through opaquely, infinite
sequences, errors, and namespaces.

[SwishEmbed](https://github.com/infiniteNIL/SwishEmbed) is a small iOS app demonstrating
all of it.
