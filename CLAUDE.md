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

`defmulti`/`defmethod` are implemented (`core.clj`, "Hierarchies" and "Multimethods" sections near the end of the file), including full hierarchy-based dispatch (`derive`/`underive`/`isa?`/`parents`/`ancestors`/`descendants`/`make-hierarchy`) and ambiguity resolution (`prefer-method`/`prefers`). `clojure.test/report` and `clojure.test/use-fixtures` (`test.clj`) have been converted from their earlier `cond`-based workarounds to real multimethods.

The whole feature is pure Swish/Clojure code — no new `Expr` case or native Swift function. A multimethod's method table and prefer table are plain atoms; the callable multimethod itself is an ordinary variadic closure with those atoms attached via function metadata (`with-meta`/`meta` on a function mutate/read the same underlying reference, confirmed in `CoreMeta.swift`); `isa?`/`parents` are called directly since dispatch resolution is just Swish code calling other Swish code, with no Swift/Clojure boundary to cross the way real Clojure's Java `MultiFn` calls back into Clojure vars.

Two deliberate divergences from real Clojure, both direct consequences of Swish having no JVM class hierarchy (same root cause as the Protocols section below):
- **No method-resolution cache.** Real `clojure.lang.MultiFn` caches resolved dispatch-value → method lookups and invalidates on hierarchy change; Swish's `mm-find-method` just re-runs the linear best-match scan across the whole method table on every dispatch. Semantically identical, just O(n) in method count instead of O(1) after the first call — consistent with `case`'s existing O(n) dispatch (this file has no O(1) dispatch machinery anywhere else either).
- **`ancestors`/`parents`/`descendants` only reflect relationships established explicitly via `derive`, not automatic Java-class/protocol inheritance.** Real Clojure's hierarchy functions also walk a class's actual superclass/interface chain (and pick up a `deftype`/`defrecord`'s implemented protocols for free via the JVM reflection over its generated interface) when `tag` is a class. Swish has no class objects or reflection to walk (same "no ancestor-chain fallback" limitation already documented for protocol dispatch below) — `derive`-based relationships work fully, including using a `deftype`/`defrecord`'s type identity as a plain derive tag (they're already keywords), but nothing is populated automatically.

Still not implemented: `clojure.test/assert-expr` — a separate, unrelated gap in `is`'s architecture (it inlines try/catch rather than dispatching through a multimethod), not something this pass touched.

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

### `tap>` never drops — its queue is effectively unbounded, unlike real Clojure's

Real Clojure's `tap>` sends values through a bounded (1024-slot) `java.util.concurrent.ArrayBlockingQueue`, drained by a single background `Thread`; `tap>` uses non-blocking `.offer`, returning `false` immediately if the queue is full instead of blocking — that's what its `true`/`false` return value actually reports (room in the queue vs. dropped). Swish's `tap>` (`CoreConcurrency.swift`) instead dispatches onto a dedicated serial `DispatchQueue` (`tapQueue`), reusing the same "dedicated serial queue + captured dynamic bindings + per-call error swallowing" pattern `SwishAgent` already established for `send`/`send-off`. GCD's own queue has no fixed capacity, so there is no equivalent backpressure: `tap>` always returns `true` and never drops a value, regardless of how slow or backed-up the registered taps are. Building a faithful bounded-queue-with-try-offer primitive was judged not worth it for this pass — the real one exists to bound memory under sustained backpressure on a long-running JVM process, a concern that doesn't come up in Swish's actual usage, and the jank suite's own `taps.cljc` fixture never exercises the drop-on-full path either.

### Future cancellation is cooperative-only (a platform limitation, not a simplification)

`future-cancel` only takes effect at explicit polling checkpoints (currently `sleep!`'s ~20ms poll loop) rather than truly preempting a running computation, unlike Java's `Thread.interrupt()`, which can unblock a thread stuck in a blocking call. This isn't a corner Swish chose to cut — it's a hard ceiling on Apple platforms, confirmed against Swift Evolution and Apple's own documentation: Swift's structured-concurrency cancellation is explicitly cooperative-only by design (SE-0304: "cancellation has no effect at all unless something checks for cancellation"), Foundation's `Thread.isCancelled` is likewise just a pollable flag, `pthread_cancel` is unimplemented on Darwin, and signal-based interruption (`pthread_kill`) is unsafe to use from Swift/GCD (handlers aren't async-signal-safe with ARC or the Swift runtime, and GCD doesn't expose the underlying `pthread_t` to signal in the first place). Swish's cooperative-polling approach is the Apple-recommended pattern here, not a workaround for a missing feature.

### Nested syntax-quote depth tracking

Syntax-quotes inside syntax-quotes (`\`\`~x`) do not increment depth — `~` always evaluates immediately regardless of nesting level. This only affects macro-writing macros. See `syntaxQuoteExpand` in `Evaluator+Destructuring.swift`.

### Syntax-quote namespace resolution uses call-site namespace for `~` unquoted values

`preExpandSyntaxQuote` (called at `defmacro` evaluation time) pre-qualifies all quoted symbols using the defining namespace. However, gensyms (`x#`) are still generated fresh at each call rather than being fixed at definition time, because pre-generated gensyms get re-qualified by the runtime expander. Functionally correct, but differs from Clojure where gensyms are stable across calls.

### `case` dispatches via a linear equality chain, not a JVM jump table

Real Clojure's `case` macro expands to a `case*` special form that the JVM bytecode compiler turns into an actual `tableswitch`/`lookupswitch` jump table (O(1) dispatch) — the exact strategy depends on hashing the test constants (`prep-ints`/`prep-hashes`/`merge-hash-collisions` in `clojure/core.clj`). Swish has no bytecode compiler, so `case` (`core.clj`, ported directly from the real source) keeps every portable part of the real macro verbatim (clause parsing, list-of-constants expansion, duplicate-test-constant detection, default-clause handling) but replaces only the dispatch-code-generation step with a `cond`-chain of `(= ge 'test)` checks. This is semantically identical — verified against every case in the jank suite's `case.cljc`, including the numeric-tower discrimination rules (`1`/`1N` match each other but not `1.0`/`1.0M`; `Double` and `BigDecimal` are mutually exclusive categories) — just O(n) instead of O(1). This doesn't cost anything relative to the rest of Swish, which has no O(1) dispatch anywhere else either (it's a tree-walking interpreter, not a compiler).

Implementing `case` also surfaced and fixed a real, pre-existing bug: `expandAliases` (`Evaluator+AliasExpansion.swift`, run on every `fn`/`defn` body to pre-qualify bare symbols to their fully-qualified var names, so closures resolve correctly even after a later namespace switch) walked into every list argument uniformly, with no awareness that a macro's arguments might be unevaluated literal data rather than code. This silently corrupted `case`'s test-constants (e.g. `list` inside a `(list of syms)` test-constant got rewritten to `clojure.core/list`) whenever `case` appeared inside a `fn` body, since `case` wasn't in `expandAliasesInExpr`'s existing `quote`/`syntax-quote`/`fn`/`let`/`loop` special-case list. Fixed by adding `case` to that same list (skip it entirely, exactly like `quote` — its own separate macro-expansion path, run later through the normal evaluation flow, correctly resolves everything when it actually executes). A broader fix (treat *any* macro call as opaque) was tried first and reverted: it broke `cond` and everything like it, since most macros' arguments genuinely are code that should be qualified — only macros with `quote`-like literal-data arguments (currently just `case`) need this treatment, and that can't be determined generically from "is this a macro," only from each macro's own semantics.

### `subvec` copies its slice instead of sharing structure with the original vector

Real Clojure's `subvec` is documented as O(1), returning a `clojure.lang.APersistentVector.SubVector` that wraps the original vector plus a `start`/`end` range — no copying. Swish's `subvec` (`CoreSequence.swift`) instead copies the sliced range into a new `.vector`, making it O(n) in the slice size rather than O(1). Same category of divergence as `case`'s O(n) dispatch above — not something worth a dedicated wrapper type for, since Swish is a tree-walking interpreter with no O(1)-dispatch machinery elsewhere either, and no other code currently depends on `subvec`'s result aliasing the original vector's storage.

### `with-precision` / `*math-context*` are not implemented

Real Clojure's `with-precision` binds a dynamic var (`*math-context*`) around a body; every BigDecimal arithmetic op (`+`, `-`, `*`, `/`, `quot`, `rem`, `inc`, `dec`, `abs` — confirmed by reading `Numbers.java`, each checks `MATH_CONTEXT.deref()`) uses it when bound to round results to a given precision under a given rounding mode, and falls back to unlimited-precision exact arithmetic when unbound — which is the only mode Swish's BigDecimal arithmetic currently has.

The blocker isn't the `with-precision` macro itself (that part is a small, portable wrapper) — it's that real precision-rounding needs to support 8 distinct, independently-selectable rounding modes (`UP`, `DOWN`, `CEILING`, `FLOOR`, `HALF_UP`, `HALF_DOWN`, `HALF_EVEN`, `UNNECESSARY`, all exercised by the jank suite's own `with_precision.cljc`), and nothing in Swish or the `BigDecimal` Swift package implements that. The package's own `withPrecision(_:)` rounds to N significant digits using exactly one fixed, hardcoded strategy (`getRoundingTerm`, a HALF_UP-style check) with no way to choose a different mode. Implementing `with-precision` correctly means writing a mode-selectable significant-digit rounding algorithm from scratch first — a real, novel numerical subsystem, not a wiring job — so it's deferred rather than shipped as a partial/misleading implementation (e.g. one that silently ignores `:rounding` or only supports one mode).

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

Swish's tree-walking interpreter costs roughly 300–475µs per element for chains like `filter`/`range`/`vec`+`seq`+`next`-walks — confirmed **linear** (not quadratic) by direct measurement with the built binary (excludes `swift run`'s own overhead): `(count (filter (fn [_] false) (range n)))` at n = 2000/4000/8000/16000/32000 scales almost exactly proportionally to n (8000→3.88s, 16000→7.73s, 32000→15.16s). A separate check — `(dorun (seq (vec (range n))))`, the pattern most likely to hit an `Array(dropFirst())`-copy-per-`next`-call cost — going from 16000→64000 (4x) took only ~3.2x longer, again linear. There is no O(n²) bug in these paths (an earlier, unverified claim to this effect was wrong and has been corrected here).

**Since profiled** (a structural code audit plus release-build measurements — n=20000, `count`/`dorun` over `range`): a pure `loop`/`recur` baseline with zero lazy-seq involvement costs only ~4.9µs/element (100k iterations in 0.489s), ~20-100x cheaper than the lazy-driven figure above — ruling out generic environment-lookup/evaluator-dispatch overhead as the dominant cause, since that baseline exercises both too. The real driver: `range`, `filter`, `map`, `iterate`, `take-while` etc. are all ordinary interpreted `defn`s, not special-cased lazy machinery — `lazy-seq` itself is the only actual special form involved, and does no per-element work of its own. Realizing one lazy element means running a full recursive interpreted call graph, and cost compounds multiplicatively with how many separate lazy layers that graph composes through. Measured directly: `range`'s 1-arg form (`core.clj`: `(take-while #(< % end) (iterate inc 0))`, composing **two** independently-recursing interpreted functions, each wrapping its own `LazySeqBox`) costs ~94µs/element, while the 3-arg form (a single self-recursive `(lazy-seq (let [pred ...] (when (pred start) (cons start (range ...)))))`, one layer) costs ~21µs/element for the identical logical sequence — a measured **4.5x** difference attributable purely to composition depth. This generalizes: any core.clj sequence function built by composing multiple lazy layers (rather than one self-recursive `lazy-seq`) pays a per-layer interpreter tax on every element, and `range`'s 1-arg/2-arg forms are a concrete, ready-to-fix instance of this (rewriting them to a single self-recursive form like the 3-arg case, mirroring `repeat`/`cycle`'s existing style, is a core.clj-only change — no architecture work needed — not yet done).

Smaller, additive contributors also confirmed: `LazySeqBox` (`LazySeqBox.swift`) still uses `NSLock`, not `Synchronization.Mutex` like the rest of the codebase — ~5 lock/unlock pairs plus ≥2 fresh `NSLock` heap allocations (the lock object itself, not just its acquisition) per realized element. Git history confirms this is an oversight, not a deliberate choice: the commit that introduced `Mutex` everywhere else (`c511047`, "Thread-safety retrofit," 2026-07-14) never touched `LazySeqBox.swift`, which has used `NSLock` since its creation (`11d357f`) and has never contained `Mutex` at any point in its history — a simple, low-risk swap-and-measure candidate, not yet done. `next`-based walks (`dorun`) cost modestly more than `asSequence`-based walks (`count`) — ~104µs vs ~97.5µs/element — because `coreNext` (`CoreSequenceCore.swift`) forces one element further ahead than logically needed (to check for emptiness) and allocates an extra wrapper `LazySeqBox` on top; a real but minor (~7%) factor, not the main story. Global-symbol resolution (any reference to a builtin like `seq`/`first`/`cons`/`rest` from within a lazy body) costs ~9 uncached `Mutex` lock/unlock pairs per reference with no caching at any layer — see the "global-symbol-resolution cache" deferred item below for the full trace and a worked-out (but not implemented) fix design.

None of the above have been fixed in this pass — this section now reflects real profiling data (structural audit + measured release-build benchmarks) rather than a guess about which factor dominates, but the fixes themselves remain future work.

### `LazySeqBox` needed a custom `deinit` to avoid stack overflow on releasing long realized chains

`next`/`seq` (`CoreSequence.swift`) memoize each realized step as `.cons(head, tail: .lazySeq(nextBox))`, forming a genuine singly-linked chain of `LazySeqBox` objects once fully walked (e.g. by `dorun`). Since `Expr` is an `indirect enum` (heap-boxed), Swift's compiler-generated `deinit` for a long reference chain like this is not tail-call-optimized — releasing the head recursively released the next link, which recursively released the next, etc., one native stack frame per link, crashing at ~20000 elements (confirmed via `(dorun (range n))`, independent of any lazy-seq *forcing* logic — a bare, already-realized chain crashed purely on release). Fixed with a custom `deinit` on `LazySeqBox` (`LazySeqBox.swift`) that iteratively unlinks the tail chain (using `isKnownUniquelyReferenced` to only detach links nothing else is aliasing) before default ARC teardown runs — the standard fix for this well-known Swift pattern.

### `into-array`'s `type` argument is accepted but not enforced

Real Clojure's `into-array` (`([type aseq])` 2-arity form) uses `type` to pick the JVM array's component type, and validates every element in `aseq` is compatible with it (class objects for primitives obtained via e.g. `Integer/TYPE`). Swish's `SwishArray` (`Expr.swift`) is untyped — a plain `[Expr]` wrapper with no component-type field at all — so `into-array` (`CoreSequence.swift`) accepts the optional `type` argument purely for call-site source compatibility with ported Clojure code, but never inspects or validates it. Same category of simplification `int-array`/`object-array` already made silently (neither validates its elements are actually ints/objects either); `into-array` doesn't introduce a new kind of divergence, just extends the existing one to the 2-arity form.

One consequence worth naming: real class-reference symbols like `Integer/TYPE` or `String` won't resolve if actually passed as `type`, since Swish has no vars for JVM classes at all — this fails at ordinary symbol-resolution time before `into-array` ever runs, same as any other Java-interop reference in Swish today (see the Protocols section above for the same underlying "no JVM class hierarchy" limitation). Passing a keyword or `nil` as a stand-in `type` marker works fine, since it's never inspected.

## Deferred Performance/Architecture Items

A refactoring audit (2026) covered `Sources/` (excluding `Tests/`, which served as the regression gate) for oversized functions/files, duplication, and performance opportunities. Most findings were fixed directly; the remaining items here were deliberately deferred because each needs a real design change rather than a contained, mechanical fix. Re-verify against current source before acting on any of these — this list is a map of where to look, not a guarantee the code hasn't shifted since.

`cons`/`conj` onto a list being O(n) instead of O(1) was on this list and has since been fixed: `Expr.list` is now backed by `SwishPersistentList` (`SwishPersistentList.swift`), a real cons-cell persistent list with O(1) `cons`/`first`/`rest`/`count`, matching `clojure.lang.PersistentList`'s design.

### `Environment` pays a `Mutex` acquire/release at every level of the lexical scope chain

`Environment.get` (`Evaluator/Environment.swift`) walks its `parent` chain on a miss, and each level's `bindingsState.withLock { ... }` is a full `Mutex` lock/unlock — even though the overwhelming majority of `Environment` instances (a `let`/`fn` call's locals) are only ever touched by the single thread that created them and never shared. A lookup that walks N scope levels to find (or fail to find) a binding pays N lock operations. A faster design would need to distinguish "this environment can only ever be touched by its creating thread" from the cases that genuinely need synchronization (if any — Swish's evaluator doesn't currently share a running call's environment chain across threads at all), which is a real design question, not a mechanical swap.

### `currentNs()` does two locked dictionary lookups on every unqualified symbol resolution that falls through to it

`currentNs()` (`Evaluator+Namespaces.swift`) does `findNs("clojure.core")!.findVar(name: "*ns*")!` — a locked lookup into `Evaluator.namespacesState`'s dictionary, then a locked lookup into that namespace's own var table — every time it's called, which includes every `eval` of a bare symbol not found in the local `Environment` chain (`Evaluator.swift`'s `.symbol` case) and not resolved as a qualified var. The code already carries its own comment on `setCurrentNs` explaining why this isn't trivially fixed: `*ns*` is a normal (non-dynamic) `Var`, so `in-ns` mutates one shared root value rather than a real thread-local binding, and making it genuinely dynamic/thread-local is explicitly deferred "to whichever later step first introduces real background execution." This item is that same deferred work, viewed from the performance angle rather than the correctness angle.

### `evalList`'s special-form dispatch is a 20-way sequential string comparison that every ordinary function call pays in full

`evalList` (`Evaluator.swift`) matches `head` against 20 literal special-form symbols (`"quote"`, `"syntax-quote"`, `"def"`, `"if"`, `"do"`, `"let"`, `"letfn"`, `"loop"`, `"recur"`, `"fn"`, `"defmacro"`, `"var"`, `"ns"`, `"lazy-seq"`, `"delay"`, `"binding"`, `"throw"`, `"try"`, `"defrecord"`, `"deftype"`, `"extend-type"`, `"extend-protocol"`) one `case .symbol("x", _):` at a time before falling to `default:`. Since these are runtime string-equality checks on an enum's associated value (not something Swift compiles to a jump table), every ordinary function call — `(+ 1 2)`, `(my-fn x y)`, `(map f coll)`, the overwhelmingly common case — fails all 20 comparisons before reaching the actual call path. `Evaluator.specialFormNames` (a `Set<String>`, right above `evalList`) already exists nearby for a different purpose (so `resolve`/introspection can recognize these names), and could plausibly double as a fast up-front rejection (`guard specialFormNames.contains(name) else { /* go straight to call path */ }`) — but reordering dispatch on a path this hot needs care and real before/after measurement (see CLAUDE.md's own "Actual speed, measured, not assumed" lesson from the Tier 4 performance pass), not a blind reshuffle.

### `fn` literals redo static analysis on every evaluation, not just once per definition

`evalFn`/`buildFnArity` (`Evaluator+FnDef.swift`) run destructuring expansion (`expandDestructuredParams`), tail-position `recur` validation (`validateRecurTailPosition`), local-name collection (`collectAllParamLocals`), and full alias-expansion (`expandAliases`) over the `fn` form's parameter vector and body — every single time that `fn` *literal* is evaluated, not once per logical definition. This matters whenever a `fn` literal sits inside a body that runs repeatedly — e.g. `(fn [y] (+ x y))` inside `(defn make-adder [x] (fn [y] (+ x y)))`, re-analyzed on every call to `make-adder` even though the inner literal's params/body syntax never changes across calls. All of this analysis depends only on the literal `fn` form itself (its AST), never on the runtime `env`/captured values, so it's a legitimate caching target — but caching needs a stable per-AST-node cache key, and `Expr` currently has no node identity to hang a cache on (equal-by-value `Expr`s from two different source locations would collide), so this is a real design question about how (or whether) to give specific `Expr` nodes identity, not a one-line memoization.

### Global-symbol resolution (e.g. `seq`, `first`, `cons` referenced by name) costs ~9 uncached `Mutex` locks per reference

Every reference to a builtin by name that isn't a local binding — the overwhelmingly common case inside lazy-seq bodies and anywhere else interpreted code calls a core function — re-resolves "what Var does this name refer to" from scratch on every single evaluation, with no caching at any layer. Traced precisely for the dominant case (a symbol already qualified by alias-expansion, e.g. `clojure.core/first`, evaluated via `eval`'s `.symbol` case, `Evaluator.swift`): `env.get(name)` miss (2 locks, walking a 2-level env chain) → `resolveQualifiedVar` (`Evaluator+Namespaces.swift`): `currentNs()` [2 locks] → `currentNs().findAlias(nsAlias)` [1 lock, **always misses** for a real namespace name like `"clojure.core"`] → falls back to `findNs(nsAlias)` [1 lock] → `ns.findVar(shortName)` [1 lock] = 5 locks → `deref(v)`'s `dynamicValue(of:)`: `v.isDynamic` [1 lock] + `v.value` [1 lock] = 2 locks. **≈9 lock/unlock pairs per reference.**

A caching fix was designed but not implemented (deferred by choice, not blocked): a `Mutex<[String: Var]>` cache on `Evaluator`, checked first in `resolveQualifiedVar`, needs **no invalidation logic at all** given two provable invariants — `Namespace.intern` (`Namespace.swift`) always reuses the existing Var object when a mapping is already homed in that namespace (only `.value` changes, never object identity), and `Namespace.refer` explicitly throws rather than silently replacing an existing mapping with a different Var. So a *home*-var resolution, once cached, can never go stale. Two correctness traps a real implementation must respect: (1) only cache when resolution went through the literal-namespace-name branch (`findNs(nsAlias)`), never the alias branch (`currentNs().findAlias(nsAlias)`) — alias resolution is caller-namespace-dependent (`str/join` can mean different things from different namespaces with different `:as str` requires), so caching that branch by bare text would be a real bug; (2) only cache when the resolved Var's home namespace is the namespace being searched (`v.namespace === ns`) — a *referred* (non-home) var can later be shadowed by a local `def` in that namespace, which `Namespace.intern` implements by creating a genuinely new Var, so referred-var resolutions must never be cached. `expandAliases`'s output (`"\(v.namespace.name)/\(v.name)"`, always the var's true home namespace) means the hot path this targets is exactly the case that's always safe to cache. Complementary small fix identified alongside this: `Var.dynamicValue`'s `isDynamic`+`value` reads are two separate lock acquisitions that could be combined into one (`state.withLock { ($0.isDynamic, $0.value) }`). Net effect on the traced case: ~9 locks → ~4. This is a real, broad win (taxes all interpreted code referencing globals, not just lazy seqs) but was explicitly not pursued this round — the design above is complete enough to implement directly from this description.

### Pasting a large multi-line form into the REPL costs O(n²) in the pasted text's length

`Repl.swift`'s `readMultilineInput` calls `continuationNeeded(input)` (and, each time another line is added, `computeIndent(input, ...)`) — both in `ReplInputScanner.swift` — once per line of input added to the in-progress multi-line form. Both functions unconditionally scan `input` from `input.startIndex`; neither is incremental or resumes from where the previous call left off. So pasting (or typing) an N-line form triggers N full rescans of the accumulated text — total scanned-character count grows like 1+2+...+N, i.e. O(n²) in the pasted text's total length, even though the total real work (recognizing when brackets balance) is O(n). Not yet reproduced at a pasted size large enough to be perceptible (small/medium forms are cheap enough that this is invisible), so the actual user-facing impact is unconfirmed — but the mechanism is real and would need either incremental re-scanning (track depth/position across calls instead of recomputing from scratch) or scanning only the newly-added suffix plus carried-over state.

## REPL Commands

REPL commands are preceded by `/` (e.g., `/quit`, `/q`). This distinguishes them from Swish expressions.
