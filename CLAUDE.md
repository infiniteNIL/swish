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
- `*print-length*` (default 100) caps how many elements the printer realizes before emitting `...`. The `Printer` struct exposes `printLengthCap: Int?` to control this.
- `unquote-splicing` handles lazy seqs by fully realizing them (so macros like `lazy-cat` that use `~@(map ...)` work correctly).

## REPL Commands

REPL commands are preceded by `/` (e.g., `/quit`, `/q`). This distinguishes them from Swish expressions.
