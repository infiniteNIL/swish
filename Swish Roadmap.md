# Gap Analysis: Swish Foundation Roadmap

## Vision
Swish is a Clojure dialect embedded in Swift apps. Long-term goals:
1. **Embedded runtime** — Swish evaluates code inside a Swift app, with Swift↔Swish interop
2. **Bytecode interpreter** — replace the tree-walking evaluator with a compile+VM architecture for performance
3. **Compile to Swift** — generate Swift source from Swish code, for library linking and peak performance

---

## Tier 1 — Missing Clojure fundamentals (blocking practical use)

These are used in virtually all real Clojure code. Without them, you can't write idiomatic Clojure.

### Destructuring
The single biggest gap. Used constantly in `let`, `fn` params, and `for`.
```clojure
(let [{:keys [name age]} person] ...)   ; map destructuring
(let [[x y & rest] coll] ...)           ; sequential destructuring
(defn f [{:keys [a b]}] ...)            ; fn param destructuring
```
Requires changes to `evalLet`, `bindParams`, and the parser.

### try / catch / finally / throw
Essential for any runtime embedded in an app — errors from Swish need to be catchable.
```clojure
(try
  (/ 1 0)
  (catch Exception e (str "caught: " e))
  (finally (cleanup)))
```
Needs new special forms and a Swish exception type.

### cond
Too common to define in user code every time. Simple macro, but should ship in core.
```clojure
(cond
  (< n 0) :neg
  (= n 0) :zero
  :else   :pos)
```

### Threading macros: `->`, `->>`
Pervasive in idiomatic Clojure. Can be macros in core.clj.
```clojure
(-> data (assoc :x 1) (update :y inc) str)
(->> coll (filter odd?) (map inc) (reduce +))
```

### `when-let` / `if-let`
Used constantly for nil-guarding.
```clojure
(when-let [v (find-user id)]
  (greet v))
```

### Missing map operations
- `dissoc` — remove a key
- `assoc-in` / `get-in` — nested access/update
- `update` / `update-in` — transform a value at a key
- `keys` / `vals` — extract map keys or values
- `select-keys` — project a subset of a map
- `merge-with` — merge maps with a combining function

### Atoms
The simplest concurrency primitive and the one real Clojure apps use most.
```clojure
(def state (atom {:count 0}))
(swap! state update :count inc)
@state  ;=> {:count 1}
```
Needs `atom`, `deref` (`@`), `swap!`, `reset!`.

**Note — CAS semantics (future):** The current `swap!` implementation uses simple
assignment, which is correct for single-threaded use. True Clojure-style `swap!`
uses Compare-and-Set with retry: read current value, compute new value, atomically
swap only if the value hasn't changed (retry if it has). This matters for concurrent
mutation from multiple threads. Implementing it properly requires making the
Evaluator itself concurrency-safe first — locking atoms in isolation provides false
safety. Address when multi-threaded Swish evaluation becomes a concrete requirement.

---

## Tier 2 — Standard library (needed for practical code)

### Sequence utilities
We deferred these when adding sequence foundation. Now needed:
`nth`, `take`, `drop`, `take-while`, `drop-while`, `last`, `butlast`,
`reverse`, `flatten`, `partition`, `partition-all`, `group-by`,
`frequencies`, `sort`, `sort-by`, `distinct`, `interleave`, `interpose`,
`zipmap`, `keep`, `keep-indexed`, `map-indexed`, `doall`, `doseq`, `for`

### Lazy sequences
Currently `lazy-seq` is an eager no-op macro, sufficient for finite collections.
True lazy sequences are needed for: infinite sequences (`range`, `iterate`, `repeat`,
`cycle`), memory-efficient processing of large collections, and full Clojure
compatibility. Implementing this properly requires a new `LazySeq` reference type
(similar to `SwishAtom`) that wraps a thunk and caches its realized value.

### Transducers
Clojure 1.7 added transducers: composable reducing-function transformers. The 1-arity
forms of `map`, `filter`, `take`, `take-while`, `drop`, `drop-while`, etc. each
return a transducer rather than a sequence. Useful with `transduce`, `sequence`, and
`into`. Requires implementing the full protocol as a cohesive unit — adding 1-arity
forms to individual functions without `transduce`/`sequence` would be useless.

### clojure.string
At minimum: `join`, `split`, `trim`, `trim-left/right`, `upper-case`, `lower-case`,
`starts-with?`, `ends-with?`, `includes?`, `replace`, `blank?`

### clojure.set
`union`, `intersection`, `difference`, `subset?`, `superset?`

### Better I/O
`slurp`, `spit`, `read-string`, `with-open` — needed for any file-touching code.

### `source` function
Prints the source of a Swish-defined function, similar to `clojure.repl/source`.
Approach: store a reconstructed `(defn ...)` form in `:src` var metadata at
definition time; expose `sourceForm` (already in the Printer) as a callable Swish
function; `source` macro looks up `:src` via `resolve`/`meta`. Limitation: comments
lost (not in AST), and native Swift functions show "Source not available".

---

## Tier 3 — Embedding API (the "for Swift" part, short-term)

Before deep ObjC/Swift interop, Swish needs a clean embedding API so Swift code can use it.

### What's needed:
- `Evaluator.eval(string:)` — evaluate Swish source from Swift (already exists, exposed?)
- `Evaluator.call(name:args:)` — call a Swish function by name from Swift
- Swift→Swish value conversion — `Int`, `String`, `Bool`, `[Any]`, `[String: Any]` ↔ `Expr`
- Error type — a public `SwishError` that Swift catch blocks can use
- Callback registration — the existing `evaluator.register(name:arity:body:)` is the right foundation; needs to be a public API with better ergonomics

### ObjC runtime bridge (medium-term)
The Objective-C runtime is available on all Apple platforms. Most UIKit/Foundation/AppKit types are `NSObject` subclasses with ObjC-compatible methods.

```clojure
; would call [label setText:@"Hello"]
(.setText label "Hello")

; would access label.title via KVC
(.-title label)
```

Implementation approach:
- Add `.` special form to the evaluator
- Use `NSObject.perform(_:with:)` or `NSInvocation` for method dispatch
- Use KVC (`value(forKey:)`) for property access
- Swift→ObjC bridging already handles `String`/`Int`/`Bool`/`Array`/`Dictionary`

This won't cover pure-Swift APIs (no `@objc` exposure), but covers the vast majority of Apple framework APIs.

---

## Tier 4 — Bytecode interpreter (architectural, medium-term)

The current tree-walking evaluator is clean and correct. A bytecode VM would bring:
- ~5-10x eval performance
- Smaller memory footprint (bytecodes, not full ASTs)
- Easier compile-to-Swift path (compiler is already half the work)

### Architecture
```
Source → Reader → AST (Expr) → Compiler → Bytecode → VM
```

The Reader and AST remain unchanged. The Evaluator splits into:

**Compiler** — walks the AST, emits instructions:
```
LOAD_CONST 42
LOAD_VAR "x"
STORE_VAR "y"
CALL 2          ; call with 2 args
JUMP_IF_FALSE L1
MAKE_FN params body
RETURN
```

**VM** — stack-based executor with:
- Value stack
- Call stack (activation records / frames)
- Constant pool
- Instruction pointer

The namespace/var/environment system remains mostly as-is; only the execution engine changes.

### Key design points
- Closures: captured environments become activation record chains (already modeled by the current Environment class)
- Tail calls: `recur` compiles to a `LOOP_BACK` instruction rather than a new frame
- Macros: expanded at compile time (not at runtime), which is a major correctness improvement
- Native functions: still Swift closures, called via `CALL_NATIVE` instruction

This is a 2-4 week effort and is architecturally straightforward for a Lisp with this clean an AST.

---

## Tier 5 — Compile to Swift (long-term)

Swish → Swift source generation. Two modes:

**Mode 1: Dynamic Swift** (easier)
Generate Swift code that uses `Any` and runtime dispatch — similar to how ClojureScript targets JavaScript without static types. Output is valid Swift but not idiomatic.

**Mode 2: Typed Swift** (hard, needs type inference)
Infer types from Swish code and generate idiomatic Swift with proper types. Requires a type inference pass, which is a significant compiler project.

Mode 1 is feasible; Mode 2 is a research project. Start with Mode 1.

---

## Recommended sequence

1. **Destructuring** — biggest impact on code quality
2. **try/catch/throw** — essential for embedding
3. **cond + threading macros + when-let/if-let** — complete the core idioms
4. **Missing map operations (dissoc, assoc-in, get-in, update, update-in, keys, vals)**
5. **Atoms** — mutable state
6. **Sequence utilities** (nth, take, drop, sort, etc.)
7. **Embedding API cleanup** (public Swift interface to Swish)
8. **clojure.string + clojure.set**
9. **Bytecode interpreter** (architectural rework)
10. **ObjC/Swift interop** (. special form)
11. **Compile to Swift**
