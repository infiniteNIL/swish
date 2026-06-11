# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Swish is a Clojure-like Lisp implementation designed to integrate seamlessly with Swift and the Apple developer ecosystem. The goal is to bring Clojure's powerful features (persistent data structures, functional programming idioms, homoiconicity, macros) to iOS, macOS, and other Apple platforms.

## Clojure Documentation

- General Clojure documentation: https://clojure.org
- Clojure API and function reference: https://clojure.github.io/clojure

## Code Style

See [swift.md](swift.md) for Swift and SwiftUI coding guidelines, including modern API usage, concurrency patterns, and SwiftData requirements.

## Build Commands

*To be added once the project structure is created.*

## Architecture

### Environment Hierarchy

The evaluator uses a two-tier environment chain:

- **Core environment** (`Evaluator.coreEnvironment`): holds built-in symbols and
  functions (e.g. arithmetic operators, `nil`, `true`). Populated at startup;
  user code should not shadow these at the global level.
- **Global environment** (`Evaluator.environment`): holds user-defined bindings
  created with `def`. Its parent is the core environment, so lookups fall
  through to core when a name isn't found globally.

Child environments (for `let` bindings, function calls, etc.) will be created
with the global environment as their parent, forming a full lexical scope chain.

### Lazy Sequences

Swish supports genuine lazy sequences via `LazySeqBox` (`Sources/SwishKit/LazySeqBox.swift`). A `.lazySeq(LazySeqBox)` case in `Expr` holds an unrealized thunk. Forcing the box produces a head/tail pair (or empty). Thunks run at most once (memoized). `lazy-seq` is a special form (not a macro) that captures the body and lexical environment.

- Infinite producers (`range`, `iterate`, `cycle`, `repeat`, `repeatedly`) are defined in `core.clj`.
- `map`, `filter`, `concat`, `mapcat`, `lazy-cat` are defined lazily in `core.clj` and shadow the bootstrap native registrations after core loads.
- `*print-length*` (default 1000) caps how many elements the printer realizes before emitting `...`. The `Printer` struct exposes `printLengthCap: Int?` to control this.
- `unquote-splicing` handles lazy seqs by fully realizing them (so macros like `lazy-cat` that use `~@(map ...)` work correctly).

### Transducers

Swish supports Clojure-style transducers (Clojure 1.7+).

- `reduced` is a new `Expr` case `case reduced(Expr)` — a sentinel signalling early termination from `reduce`. Native functions `reduced`, `reduced?`, `unreduced`, `ensure-reduced` are registered in `CoreHOF.swift`. `deref` on a `reduced` value returns the wrapped value.
- `reduce` (`CoreHOF.swift`) iterates lazily (handles `.lazySeq` without materializing) and checks for `.reduced` after each step to break early.
- `volatile!`/`vswap!`/`vreset!` are atom aliases in `core.clj`. Stateful transducers (`take`, `drop`, `partition-all`, etc.) store per-invocation state in atoms created inside their 1-arity closure.
- `comp`, `completing`, `transduce`, `into` (3-arity), and all 1-arity HOF transducer forms are defined in `core.clj`.
- `sequence` is lazy: each input element steps through the transducer with a fresh `[]` accumulator; outputs are collected and drained lazily. The 1-arity completion `(rf [])` flushes buffered state after input exhaustion. Infinite seqs + `(take n)` terminate correctly via `reduced`.
- `eduction` delegates to `sequence`; calling `eduction` creates fresh transducer state, but the returned lazy seq cannot be re-reduced independently.

## Known Limitations (to address later)

### Multimethods

`defmulti` / `defmethod` are not implemented. This affects:
- `clojure.test/report` — currently a `cond`-based function instead of a multimethod (cannot be extended by users)
- `clojure.test/use-fixtures` — same workaround
- `clojure.test/assert-expr` — not implemented; `is` inlines try/catch rather than dispatching through it

### STM (Software Transactional Memory)

`ref`, `dosync`, `commute`, `alter`, `ensure` are not implemented. `clojure.test` uses an `atom` instead of a `ref` for `*report-counters*`, and `swap!` instead of `dosync`/`commute`.

### Nested syntax-quote depth tracking

Syntax-quotes inside syntax-quotes (`\`\`~x`) do not increment depth — `~` always evaluates immediately regardless of nesting level. This only affects macro-writing macros. See `syntaxQuoteExpand` in `Evaluator+Destructuring.swift`.

### Syntax-quote namespace resolution uses call-site namespace for `~` unquoted values

`preExpandSyntaxQuote` (called at `defmacro` evaluation time) pre-qualifies all quoted symbols using the defining namespace. However, gensyms (`x#`) are still generated fresh at each call rather than being fixed at definition time, because pre-generated gensyms get re-qualified by the runtime expander. Functionally correct, but differs from Clojure where gensyms are stable across calls.

### `clojure.test` — no `assert-expr` / `try-expr`

The `is` macro inlines its try/catch directly. The `assert-expr` multimethod (which provides richer failure messages showing both sides of `=` comparisons) is not implemented. Failure output shows `(not false)` rather than `(not (= 5 4))`.

### `clojure.template/do-template`

Not implemented. `clojure.test/are` uses a `partition`+`interleave` expansion instead.

### `run-tests` uses `doall` + `reduce` instead of `apply merge-with +`

Due to a lazy-seq realization issue where `asSequence` silently swallows errors from lazy seq thunks, the standard `(apply merge-with + (map test-ns namespaces))` pattern fails. Current workaround forces evaluation with `doall`.

## REPL Commands

REPL commands are preceded by `/` (e.g., `/quit`, `/q`). This distinguishes them from Swish expressions.
