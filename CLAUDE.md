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

### Protocols

`defprotocol`, `deftype`, `extend`, `extend-type`, `extend-protocol`, `satisfies?`, `extends?`, `extenders`, `instance?` are implemented (`Evaluator+Defprotocol.swift`, `Evaluator+Deftype.swift`, `CoreProtocol.swift`), and `defrecord` (`Evaluator+Defrecord.swift`) now parses and registers trailing protocol-implementation clauses it previously discarded. Two deliberate simplifications vs. real Clojure, both direct consequences of Swish having no JVM class hierarchy:

- **Dispatch is exact type-name match only, no ancestor-chain fallback.** Real Clojure's `find-protocol-impl` walks the JVM superclass/interface chain when there's no exact-class implementation; Swish has no subclassing for its types to walk, so dispatch just checks `Expr.description` (the same type-identity string `type` already exposes) against the protocol's `:impls` map. One consequence, not a bug: Swish's `:impls` is a single unified registry for both inline (`deftype`/`defrecord`-declared) and `extend`-added implementations, unlike Clojure's separate generated-interface fast path plus `:impls` map — this makes `satisfies?`/`extends?`/`extenders` simpler to implement than their real-Clojure counterparts, not just different.
- **Extending protocols onto built-in Swish types (`Integer`, `String`, `Vector`, etc.) isn't supported.** Real Clojure's `extend`/`extend-type` take a literal Java `Class` as the type to extend; Swish's built-in types have no class-like value to hang an extension off. `extend`/`extend-type`/`extend-protocol`/`extends?`/`instance?` work fully for `deftype`/`defrecord`-created types (which get a real referenceable identity — a bare var bound to a type-identity keyword) and for `nil` (dispatches as `"nil"`, so `(extend nil Proto {...})` — a common real-Clojure default-impl idiom — works today).

Also deferred: **mutable `deftype` fields** (`^:unsynchronized-mutable`/`^:volatile-mutable`). These need a `set!` special form, which Swish doesn't have at all today (confirmed — not even for local bindings). The annotations parse without erroring, so well-formed Clojure code doesn't break, but fields are immutable this pass.

`deftype`/`defrecord` method bodies get real Clojure's unqualified field access (a field like `radius` is directly in scope inside a type's own methods, without needing `(.radius this)`) via a synthetic `let` injected ahead of each method body, binding each declared field from the method's first parameter — this only applies to *inline* (the type's own trailing clauses) methods, matching real Clojure, where retroactive `extend-type`/`extend-protocol` methods do *not* get direct field access either.

### STM (Software Transactional Memory)

`ref`, `dosync`, `ref-set`, `alter`, `commute`, `ensure` are implemented (`SwishRef.swift`, `Evaluator+STM.swift`, `CoreRef.swift`), using optimistic concurrency control with three deliberate simplifications vs. real Clojure:

- **Conflict detection covers every touched ref, not just written ones.** Commit verifies the version of every ref read *or* written by the transaction, not just Clojure's narrower write-focused read-set. This is strictly conservative (never wrong, only possibly more retries under contention) and has two consequences: `ensure` reduces to a transactional read that requires an active transaction, and `commute` reduces to `alter`'s full conflict-checked behavior (giving up Clojure's relaxed/deferred-to-commit throughput optimization for commutative ops, since it's untested anywhere). Note: real Clojure's plain `deref` inside a transaction is *not* conflict-checked at all — only `ensure`/`alter`/`ref-set` are — meaning Clojure itself permits write-skew that `ensure` exists specifically to prevent. Swish's blanket check-everything-touched approach is actually the *stricter* of the two on this specific point, not the laxer one.
- **A single global commit lock**, not per-ref lock ordering. Transaction *bodies* run fully unlocked/concurrently; the lock is held only for the brief two-phase verify-then-write commit (verify all touched refs' versions first, then write only if every check passed — never interleaved, to avoid partially committing a transaction that's actually aborting).
- **No per-ref locking or age-based "barging."** Real Clojure locks each `Ref` individually and uses barging — an older transaction can force-abort a younger competitor holding a lock it needs — to avoid livelock. Swish's single global commit lock plus plain retry-from-scratch has no such mechanism. Retries are still bounded (10000 attempts, matching Clojure's `RETRY_LIMIT`), so a stuck transaction eventually throws rather than hanging, but nothing prevents two transactions from repeatedly colliding under adversarial timing the way barging is designed to avoid.
- **Exceptions abort immediately; only version conflicts retry.** A transaction body that throws propagates the exception right away rather than retrying (bounded at 10000 attempts, mirroring Clojure's `RETRY_LIMIT`).
- **Validators run at each `alter`/`ref-set` call, not deferred to commit.** Real Clojure validates a ref's prospective new value once at commit time, after all commutes have been re-applied against the latest committed value. Swish validates immediately when `alter`/`ref-set` is called within the transaction body — functionally equivalent for the common case, but a validator could in principle be asked to reject a value again on retry that wouldn't have been the true final value Clojure would have validated at commit.
- **No ref history retention.** `ref-min-history`/`ref-max-history` are real get/set pairs and `ref-history-count` always returns 0, but none of them affect transactional behavior. Real Clojure's history exists so an `ensure`-protected reader can be served a slightly-stale value instead of blocking on an in-progress writer's commit; Swish's optimistic-retry design (above) already never blocks readers on writers, so history has no role left to play.

### Agent lifecycle no-ops

`shutdown-agents` and `restart-agent`'s `:clear-actions` option are accepted (for source compatibility with ported Clojure code) but have no observable effect. Real Clojure's `send`/`send-off` share process-wide thread pools that `shutdown-agents` tears down, and a failed agent holds a real backlog of not-yet-run actions that `:clear-actions` can discard; Swish instead gives every agent its own dedicated GCD queue and dispatches each `send` onto it eagerly, so a "failed" action has already run (as a no-op) by the time it would matter — there is no shared executor to shut down and no held-back backlog to clear.

Real Clojure funnels every agent's actions through two shared, process-wide pools (bounded for `send`, unbounded for `send-off`) specifically because JVM threads are expensive enough to justify pooling across every agent in the process; GCD queues don't carry that same per-thread cost, so giving every agent its own dedicated serial queue was a deliberate, still-reasonable architecture choice for Swish rather than an oversight. Two consequences worth naming explicitly:
- **`set-agent-send-executor!`/`set-agent-send-off-executor!` aren't implemented at all** — there's no shared executor for them to reassign, so there's no Swish equivalent to provide.
- **Sends issued from inside a currently-running action or an active `dosync` are not batched/held.** Real Clojure holds those sends and only actually enqueues them once the enclosing action completes, or (for a `dosync`) discards them entirely on transaction retry, enqueuing them only on a successful commit. Swish dispatches every `send` immediately regardless of calling context — a real correctness gap, not just a stylistic difference: code that sends from within a transaction that later retries will have already fired that action once per retry, not just once on the eventual successful commit.

### Future cancellation is cooperative-only (a platform limitation, not a simplification)

`future-cancel` only takes effect at explicit polling checkpoints (currently `sleep!`'s ~20ms poll loop) rather than truly preempting a running computation, unlike Java's `Thread.interrupt()`, which can unblock a thread stuck in a blocking call. This isn't a corner Swish chose to cut — it's a hard ceiling on Apple platforms, confirmed against Swift Evolution and Apple's own documentation: Swift's structured-concurrency cancellation is explicitly cooperative-only by design (SE-0304: "cancellation has no effect at all unless something checks for cancellation"), Foundation's `Thread.isCancelled` is likewise just a pollable flag, `pthread_cancel` is unimplemented on Darwin, and signal-based interruption (`pthread_kill`) is unsafe to use from Swift/GCD (handlers aren't async-signal-safe with ARC or the Swift runtime, and GCD doesn't expose the underlying `pthread_t` to signal in the first place). Swish's cooperative-polling approach is the Apple-recommended pattern here, not a workaround for a missing feature.

### Nested syntax-quote depth tracking

Syntax-quotes inside syntax-quotes (`\`\`~x`) do not increment depth — `~` always evaluates immediately regardless of nesting level. This only affects macro-writing macros. See `syntaxQuoteExpand` in `Evaluator+Destructuring.swift`.

### Syntax-quote namespace resolution uses call-site namespace for `~` unquoted values

`preExpandSyntaxQuote` (called at `defmacro` evaluation time) pre-qualifies all quoted symbols using the defining namespace. However, gensyms (`x#`) are still generated fresh at each call rather than being fixed at definition time, because pre-generated gensyms get re-qualified by the runtime expander. Functionally correct, but differs from Clojure where gensyms are stable across calls.

### `case` dispatches via a linear equality chain, not a JVM jump table

Real Clojure's `case` macro expands to a `case*` special form that the JVM bytecode compiler turns into an actual `tableswitch`/`lookupswitch` jump table (O(1) dispatch) — the exact strategy depends on hashing the test constants (`prep-ints`/`prep-hashes`/`merge-hash-collisions` in `clojure/core.clj`). Swish has no bytecode compiler, so `case` (`core.clj`, ported directly from the real source) keeps every portable part of the real macro verbatim (clause parsing, list-of-constants expansion, duplicate-test-constant detection, default-clause handling) but replaces only the dispatch-code-generation step with a `cond`-chain of `(= ge 'test)` checks. This is semantically identical — verified against every case in the jank suite's `case.cljc`, including the numeric-tower discrimination rules (`1`/`1N` match each other but not `1.0`/`1.0M`; `Double` and `BigDecimal` are mutually exclusive categories) — just O(n) instead of O(1). This doesn't cost anything relative to the rest of Swish, which has no O(1) dispatch anywhere else either (it's a tree-walking interpreter, not a compiler).

Implementing `case` also surfaced and fixed a real, pre-existing bug: `expandAliases` (`Evaluator+AliasExpansion.swift`, run on every `fn`/`defn` body to pre-qualify bare symbols to their fully-qualified var names, so closures resolve correctly even after a later namespace switch) walked into every list argument uniformly, with no awareness that a macro's arguments might be unevaluated literal data rather than code. This silently corrupted `case`'s test-constants (e.g. `list` inside a `(list of syms)` test-constant got rewritten to `clojure.core/list`) whenever `case` appeared inside a `fn` body, since `case` wasn't in `expandAliasesInExpr`'s existing `quote`/`syntax-quote`/`fn`/`let`/`loop` special-case list. Fixed by adding `case` to that same list (skip it entirely, exactly like `quote` — its own separate macro-expansion path, run later through the normal evaluation flow, correctly resolves everything when it actually executes). A broader fix (treat *any* macro call as opaque) was tried first and reverted: it broke `cond` and everything like it, since most macros' arguments genuinely are code that should be qualified — only macros with `quote`-like literal-data arguments (currently just `case`) need this treatment, and that can't be determined generically from "is this a macro," only from each macro's own semantics.

### `format` follows Foundation's printf dialect, not Java's `java.util.Formatter`

Real Clojure's `format` is `(String/format fmt (to-array args))` — Java interop over `java.util.Formatter`. Swish has no JVM to delegate to, so `format` (`CoreString.swift`) is a native implementation built on Foundation's `String(format:arguments:)`, which follows a printf/CFString dialect that genuinely diverges from Java's in several ways: `%s` in the C/Darwin dialect expects a C string pointer rather than accepting any object via `.toString()`; `%n` means something different from Java's "platform newline" in classic printf (where it can mean "write the character count into a pointer argument"); there is no comma-grouping flag (`%,d`) and no positional argument references (`%1$s`) implemented. This is a permanent platform divergence, not a partial port — Swish doesn't attempt to replicate `java.util.Formatter` semantics, and the jank suite's own `format.cljc` fixture is deliberately conservative for exactly this reason (per its own comment: format compatibility varies across Clojure implementations).

Two real crashes (SIGSEGV) were found and fixed during implementation, both stemming from C varargs having no type safety — the format string alone dictates what shape of value each argument position must be, independent of the argument's own Swift type:
- `(format "%s" "hello")` crashed because a Swift `String` bridges to `CVarArg` as an object reference, but `%s` expects a raw C string pointer. Fixed by marshaling any string-shaped-directive argument through `NSString`/`.utf8String`, keeping the `NSString` alive for the call's duration.
- `(format "%s" 42)` crashed because the original marshaling was based on the *argument's* Swift type (`.integer` → native `Int`), not what the *directive* actually expects. Fixed by scanning the format string (`formatDirectiveShapes`) to classify each consuming directive as string-shaped, numeric-shaped, or no-arg, then marshaling each argument to match its directive's shape rather than its own type. A non-numeric value passed to a numeric-shaped directive (e.g. `(format "%d" "not-a-number")`) now throws a clean `EvaluatorError.invalidArgument` instead of risking undefined behavior in the other direction.

This scanner is minimal — no positional-argument support, no comma-grouping — and exists purely to make the two most natural usage patterns (`%s` on anything, numeric directives on numbers) safe, not to achieve Java-`Formatter` parity.

### `clojure.test` — no `assert-expr` / `try-expr`

The `is` macro inlines its try/catch directly. The `assert-expr` multimethod (which provides richer failure messages showing both sides of `=` comparisons) is not implemented. Failure output shows `(not false)` rather than `(not (= 5 4))`.

### `clojure.template/do-template`

Not implemented. `clojure.test/are` uses a `partition`+`interleave` expansion instead.

### `run-tests` uses `doall` + `reduce` instead of `apply merge-with +`

Due to a lazy-seq realization issue where `asSequence` silently swallows errors from lazy seq thunks, the standard `(apply merge-with + (map test-ns namespaces))` pattern fails. Current workaround forces evaluation with `doall`.

### Interpreter has a high per-element constant cost for lazy-seq-driven code (not an O(n²) bug)

Swish's tree-walking interpreter costs roughly 300–475µs per element for chains like `filter`/`range`/`vec`+`seq`+`next`-walks — confirmed **linear** (not quadratic) by direct measurement with the built binary (excludes `swift run`'s own overhead): `(count (filter (fn [_] false) (range n)))` at n = 2000/4000/8000/16000/32000 scales almost exactly proportionally to n (8000→3.88s, 16000→7.73s, 32000→15.16s). A separate check — `(dorun (seq (vec (range n))))`, the pattern most likely to hit an `Array(dropFirst())`-copy-per-`next`-call cost — going from 16000→64000 (4x) took only ~3.2x longer, again linear. There is no O(n²) bug in these paths (an earlier, unverified claim to this effect was wrong and has been corrected here). This is an architectural characteristic — likely some combination of environment lookup, `NSLock` overhead in `LazySeqBox`, and per-call evaluator dispatch overhead, not yet profiled to find which factor dominates — not a specific bug, and not something fixed in this pass. A real fix would be a separate, profiling-driven performance effort.

### `LazySeqBox` needed a custom `deinit` to avoid stack overflow on releasing long realized chains

`next`/`seq` (`CoreSequence.swift`) memoize each realized step as `.cons(head, tail: .lazySeq(nextBox))`, forming a genuine singly-linked chain of `LazySeqBox` objects once fully walked (e.g. by `dorun`). Since `Expr` is an `indirect enum` (heap-boxed), Swift's compiler-generated `deinit` for a long reference chain like this is not tail-call-optimized — releasing the head recursively released the next link, which recursively released the next, etc., one native stack frame per link, crashing at ~20000 elements (confirmed via `(dorun (range n))`, independent of any lazy-seq *forcing* logic — a bare, already-realized chain crashed purely on release). Fixed with a custom `deinit` on `LazySeqBox` (`LazySeqBox.swift`) that iteratively unlinks the tail chain (using `isKnownUniquelyReferenced` to only detach links nothing else is aliasing) before default ARC teardown runs — the standard fix for this well-known Swift pattern.

## REPL Commands

REPL commands are preceded by `/` (e.g., `/quit`, `/q`). This distinguishes them from Swish expressions.
