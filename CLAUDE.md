# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> Implementation history, benchmark numbers, and fix war-stories behind the entries
> below live in [NOTES.md](NOTES.md) — **not auto-loaded**; read it when you need the
> *why/how* behind a specific entry. When you implement a new Clojure divergence,
> document it here (current behavior + invariants); put the narrative in NOTES.md.

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

### Namespace & environment hierarchy

Global symbol resolution is **namespace-based** (not a core/global environment pair):

- **`clojure.core`** holds all built-ins (natives + `core.clj`), created at startup.
- **User namespaces** (`user`, and any `(ns …)`) resolve an unqualified name in their
  *own* mappings only — **there is no implicit clojure.core fallback** (`resolveVar`,
  `Evaluator+Namespaces.swift`). Core is available because it's **referred**: the `ns`
  form (and init, for `user`) refers clojure.core into the namespace via
  `referClojureCore`, filterable by `:refer-clojure` — matching Clojure. So
  `in-ns`/`create-ns` produce **bare** namespaces where unqualified core names don't
  resolve until referred. See the Namespaces limitation entry for the full model.

Child environments (for `let` bindings, function calls, etc.) form a full lexical
scope chain rooted at that namespace resolution. Every `Environment` is
write-once-then-read-only (no lock) — including `loop`/`recur`, which **builds a fresh
env per iteration** (a closure capturing a loop variable must see its iteration's
value, not the loop's final value).

### Lazy Sequences

Swish supports genuine lazy sequences via `LazySeqBox` (`Sources/SwishKit/LazySeqBox.swift`). A `.lazySeq(LazySeqBox)` case in `Expr` holds an unrealized thunk. Forcing the box produces a head/tail pair (or empty). Thunks run at most once (memoized). `lazy-seq` is a special form (not a macro) that captures the body and lexical environment.

- Infinite producers (`range`, `iterate`, `cycle`, `repeat`, `repeatedly`) are defined in `core.clj`.
- `map`, `filter`, `concat`, `mapcat`, `lazy-cat` are defined lazily in `core.clj` and shadow the bootstrap native registrations after core loads.
- `*print-length*` (default 1000) caps how many elements the printer realizes before emitting `...`. The `Printer` struct exposes `printLengthCap: Int?` to control this.
- `unquote-splicing` handles lazy seqs by fully realizing them (so macros like `lazy-cat` that use `~@(map ...)` work correctly).
- `LazySeqBox` has a **custom `deinit`** that iteratively unlinks long realized chains — required because `Expr` is an `indirect enum` and the compiler-generated recursive `deinit` overflows the stack at ~20k elements. Don't remove it. It also stays on `NSLock` (not `Mutex`) deliberately — converting its `deinit` to `Mutex.withLock` reintroduces the overflow (see NOTES.md).

### Transducers

Swish supports Clojure-style transducers (Clojure 1.7+).

- `reduced` is a new `Expr` case `case reduced(Expr)` — a sentinel signalling early termination from `reduce`. Native functions `reduced`, `reduced?`, `unreduced`, `ensure-reduced` are registered in `CoreHOF.swift`. `deref` on a `reduced` value returns the wrapped value.
- `reduce` (`CoreHOF.swift`) iterates lazily (handles `.lazySeq` without materializing) and checks for `.reduced` after each step to break early.
- `volatile!`/`vswap!`/`vreset!` are atom aliases in `core.clj`. Stateful transducers (`take`, `drop`, `partition-all`, etc.) store per-invocation state in atoms created inside their 1-arity closure.
- `comp`, `completing`, `transduce`, `into` (3-arity), and all 1-arity HOF transducer forms are defined in `core.clj`.
- `sequence` is lazy: each input element steps through the transducer with a fresh `[]` accumulator; outputs are collected and drained lazily. The 1-arity completion `(rf [])` flushes buffered state after input exhaustion. Infinite seqs + `(take n)` terminate correctly via `reduced`.
- `eduction` delegates to `sequence`; calling `eduction` creates fresh transducer state, but the returned lazy seq cannot be re-reduced independently.

## Data Structures

- **`Expr.list`** is backed by `SwishPersistentList` (`SwishPersistentList.swift`), a cons-cell persistent list with O(1) `cons`/`first`/`rest`/`count`.
- **`Expr.vector`** is backed by `SwishPersistentVector` (`SwishPersistentVector.swift`), a Clojure-style 32-way bit-partitioned persistent vector trie with a tail buffer: O(1)-amortized `conj`/`pop`, O(log₃₂ n) `nth`/`assoc`, structural sharing. `conjOne`/`conj!`/`pop`/`peek`/`pop!`/`assoc` route through it. `SwishPersistentVector.hash` combines its backing array directly so a `.vector` stays cross-`==`/hash-consistent with an equal `.sharedVector` / 2-element `.mapEntry`. (`.sharedVector` — the `SwishArray`-backed `vec`-of-a-Java-array — stays a flat `[Expr]`.)
- **`Expr.map`/`Expr.set`** (`SwishMap`/`SwishSet`) are backed by swift-collections' `TreeDictionary`/`TreeSet` (HAMT persistent map/set): `assoc`/`dissoc`/`conj`/`disj` share structure (O(log n)), so map/set *building* is O(n log n), not O(n²). Hot paths (`coreAssoc`/`coreDissoc`/`conjOne`/transient `assoc!`/`conj!`/`disj!`) operate on the tree directly; cold paths use a `TreeDictionary.swiftDictionary` materializer. Two invariants: **(1)** `.map`/`.sortedMap` and `.set`/`.sortedSet` must hash equal (they're cross-`==`), and `TreeDictionary`/`TreeSet` don't hash like Swift `Dictionary`/`Set`, so both route through backing-independent `hashMapContents`/`hashSetContents` (`Expr+Hashable.swift`) — **don't** delegate `.map`/`.set` hashing to the collection's own `hash`. **(2)** `keys`/`vals` must iterate corresponding order, so `mapCollection` (`CoreMap.swift`) projects one `TreeDictionary` value, never a freshly-materialized `[Expr:Expr]` per call (two independently-ordered dictionaries would misalign `case`, which zips `(keys pairs)` with `(vals pairs)`). Map iteration order is otherwise unchanged: `asSequence`/`Printer` sort keys explicitly regardless of backing.
- **`Expr.sortedMap`/`Expr.sortedSet`** (`SwishSortedMap`/`SwishSortedSet`) hold a comparator-sorted array **plus a stored comparator** (`comparator: Expr?`, nil = default `compareExprValue`). This honors `sorted-map-by`/`sorted-set-by` (previously the comparator was silently discarded), keeps `keys`/`vals`/`seq` in sorted order, and — per Clojure — treats two keys/elements that **compare `0`** as the same (dedup by the comparator, not `=`). `subseq`/`rsubseq` (`CoreSet.swift`) do range queries. **A custom comparator is a Swish fn invoked via the evaluator** (`Evaluator.makeComparator` → native `compareExprValue` for nil, else `call` the fn, normalizing boolean→3-way like `CoreSort`), so the mutation/lookup ops (`assoc`/`dissoc`/`conj`/`disj`/`get`/`contains?`/constructors) are **evaluator-aware** — read ops (`seq`/`keys`/`printer`) just read the pre-sorted backing. Equality/hashing ignore the comparator and stay cross-`==`/hash-consistent with `.map`/`.set` via `hashMapContents`/`hashSetContents`. swift-collections' `SortedSet`/`SortedDictionary` don't fit (they're `Comparable`-only — no runtime comparator — and flagged `UnstableSortedCollections`), so this is our own. **Sorted-array backing means O(log n) lookup + O(n log n) batch construction but O(n) insert (O(n²) incremental `into`)** — acceptable for the least-used collection; a persistent balanced tree is a deferred optimization.

## Known Limitations

Most entries are deliberate divergences from real Clojure (usually because Swish has
no JVM class hierarchy or bytecode compiler). Deep detail → [NOTES.md](NOTES.md).

### Missing core forms — now implemented

Several audit batches found many common forms simply never ported (`dotimes`, `while`,
`condp`, `cond->`/`cond->>`/`as->`/`some->`/`some->>`, `declare`, `memoize`,
`trampoline`, `mapv`, `filterv`, `reduce-kv`, `partition-by`, `reductions`,
`distinct?`, `every-pred`, `when-some`/`if-some`, `doto`, `bound?`, `split-at`,
`ns-resolve`, `clojure.set/rename-keys`, `clojure.walk/keywordize-keys`/
`stringify-keys`, `clojure.string/index-of`/`last-index-of`, …). All are faithful
`core.clj`/native ports; see NOTES.md for the full list and placement. Deliberate points:
- **`memoize` must probe its cache with `find`/`val`, not `get`** — `get` can't distinguish "already memoized, result happens to be `nil`" from "never called," which would re-invoke a nil-returning memoized fn on every call.
- **`bound?`** checks root-boundness only (`Var.isBound`), not thread-local bindings — matching Clojure's `.hasRoot`, not its `bound?`.
- **`ns-resolve`**'s 3-arg `(ns env sym)` form accepts but ignores the `env` local-binding map.
- **`definline` is deliberately unimplemented** — it's an inline-expansion form for a bytecode compiler; a tree-walking interpreter has no such pass to hook into.

A later **standard-library-completion pass** filled the rest of `clojure.set` (`select`/`project`/`rename`/`index`/`map-invert`/`join`), `clojure.walk` (`prewalk`/`prewalk-replace`/`macroexpand-all`), and common `clojure.core` fns (`update-vals`/`update-keys`, `with-redefs`/`with-redefs-fn`, `halt-when`, `iteration`, `infinite?`, the typed array ctors `char-array`/`double-array`/`long-array`/…). Deliberate points:
- **`clojure.walk/walk` gained a `seq?` branch** (it only handled `list?` before) — real Clojure's `walk` has both, and `macroexpand-all` needs it since macroexpand results are `.seq`, not `.list`. Seqs are rebuilt as lists (=-equivalent).
- **`with-redefs` sets/restores roots via `alter-var-root`**, which fires watches — real Clojure uses `.bindRoot` (bypasses watches). Minor divergence.
- **`iteration` returns a plain lazy seq**, not a `reify` of `Seqable`+`IReduceInit` (Swish has no such interfaces) — seqable/reducible, just without the `IReduceInit` fast path. It uses the idiomatic `& {:keys …}` option form (see next).
- **`& {:keys […]}` trailing-keyword-arg destructuring (Clojure 1.11 named-args-as-map) is implemented** — `(defn f [& {:keys [a] :or {a 1}}] a)` called as `(f :a 5)` binds `a` to `5`. The fix is a **seq→map coercion in `destructureMapPattern` (`Evaluator+Destructuring.swift`)**, matching real Clojure's `destructure`: every map-destructure value is first evaluated to a `raw` temp, then coerced — `(if (seq? raw) (if (next raw) (apply hash-map raw) (if (seq raw) (first raw) {})) raw)` — before the `(get …)` bindings read from it. This makes `&`-rest kwargs work (the rest is a seq, now coerced to a map), and equally `(let [{:keys [a]} '(:a 9)] a)` → `9` and the same for `loop`, since all destructuring routes through this one function. `seq?` is false for maps/vectors/nil, so real-map and nil destructures are unchanged (verified). Uses `apply hash-map` where real Clojure uses `createAsIfByAssoc` — last-wins on duplicate keys rather than throwing, an acceptable simplification.
- Typed array ctors share `int-array`/`object-array`'s untyped `SwishArray` (no element validation), differing only in default fill.

A **namespace-introspection pass** added the missing `clojure.core` namespace reflection/loading fns on existing machinery (no new `Expr` case): native reads (`CoreNamespace.swift`) `ns-map`/`ns-publics`/`ns-refers`/`ns-aliases` project `Namespace.mappings`/`aliases` (home var ⇔ `v.namespace === ns`; `ns-publics` also drops `:private`); `ns-imports` returns `{}` (no host classes); `ns-unalias` calls a new `Namespace.removeAlias` (no `qualifiedVarCache` concern — aliases are never cached); and pure `core.clj` `requiring-resolve` + `use`. Deliberate points:
- **`loaded-libs`** is backed by a new `Evaluator.loadedLibs` set populated in **`loadNs`** — the one choke point every file-loaded lib passes through, and which `in-ns`/`create-ns` bypass. So it holds `clojure.core` + `require`d/`use`d libs but not ad-hoc namespaces, matching Clojure's "libs, not namespaces." Returns a sorted-set of symbols.
- **`use`** is a faithful `require`+`refer` composition (bare-symbol and `:only`/`:exclude` vector libspecs work; prefix-lists/`:reload`/`:rename` unsupported).

A later **namespace-fidelity pass** made `refer` match Clojure, added `*err*`, moved the auto-refer into the `ns` form, and implemented `ns-unmap`/`remove-ns`/`refer-clojure`:
- **`refer` matches Clojure's `checkReplacement`** (verified against `Namespace.java`) — it no longer throws on a clash: replacing a *referred* var warns to `*err*` and replaces (last wins); replacing a *home*/interned var keeps it and warns `REJECTED … you must ns-unmap first`; the same var is a no-op. `Namespace.refer` *returns* the message (no evaluator/`*err*` access); the evaluator-level callers (`coreRefer`, `processRequireDirective`) write it via `writeErr`. `NamespaceError.referConflict` is retired. `(use 'clojure.string)` now behaves like Clojure (warns + last-referred wins).
- **`*err*`** is a redirectable dynamic var symmetric with `*out*` (`CoreIO.swift`; `Evaluator.currentErr`/`writeErr`; `with-err-str` in `core.clj`); warnings route through it (default target stderr).
- **Auto-refer is Clojure-faithful.** clojure.core is no longer referred at namespace *creation* (`findOrCreateNs` makes namespaces bare); the `ns` form refers it via `referClojureCore` (`:refer-clojure`-filterable), and init refers it into `user`. `in-ns`/`create-ns` produce **bare** namespaces, and `resolveVar` has **no clojure.core fallback** — unqualified core names resolve only via a refer. `refer-clojure` is a trivial `core.clj` macro (`= (refer 'clojure.core …)`; a standalone `:exclude` is a Clojure-faithful no-op — the effective exclusion is the `ns` form's `:refer-clojure`).
- **`ns-unmap`/`remove-ns` implemented** (`CoreNamespace.swift`): `ns-unmap` removes a mapping (`Namespace.unmap`) and invalidates the single `"<ns>/<name>"` `qualifiedVarCache` key; `remove-ns` removes the namespace (`Evaluator.removeNs`), prefix-clears the cache, and refuses `clojure.core`. **`remove-ns` keeps `Var.namespace` `unowned`** — a `.varRef` to a var of a removed namespace that outlives it dangles and *crashes* on access (a deliberate, documented footgun matching Clojure's "your problem", which the JVM tolerates). Both break the old `qualifiedVarCache` "nothing deletes mappings" invariant, now invalidated explicitly.
- **Still deferred**: `import` (no host-class system — `ns-imports` returns `{}`).

### Multimethods

`defmulti`/`defmethod` + full hierarchy dispatch (`derive`/`isa?`/`parents`/`ancestors`/`descendants`/`make-hierarchy`) and ambiguity resolution (`prefer-method`) are implemented in pure `core.clj` (no new `Expr` case) — method/prefer tables are atoms attached via function metadata. Divergences (no JVM class hierarchy):
- **No method-resolution cache** — `mm-find-method` re-runs the linear best-match scan on every dispatch (O(n) in method count, like `case`'s dispatch), vs Clojure's cached O(1)-after-first.
- **`ancestors`/`parents` reflect declared protocols but not Java-class inheritance.** `isa?` deliberately does *not* get protocol-awareness (it's a raw hierarchy-map lookup). `mm-prefers?` reads `(:parents h)` directly, not the public `parents` fn (matches Clojure's `MultiFn.prefers()`, and avoids a runner-thread stack overflow — see NOTES.md).

### Protocols

`defprotocol`, `deftype`, `defrecord`, `extend`/`extend-type`/`extend-protocol`, `satisfies?`, `extends?`, `extenders`, `instance?` are implemented (`Evaluator+Defprotocol.swift`, `Evaluator+Deftype.swift`, `Evaluator+Defrecord.swift`, `CoreProtocol.swift`). Protocols extend onto `deftype`/`defrecord` **and built-in types**. Divergences (no JVM class hierarchy):
- **Built-in types dispatch via type-name vars + a data-modeled `Number`/`Object` table** (`builtinAncestors`, `CoreProtocol.swift`), not the JVM class graph. `core.clj` binds `(def String :string)`, `(def Int :integer)`, `(def Number :Number)`, etc. **Naming is Swift-first** (`String`/`Int`/`Double`/`Bool` — a Swish string *is* a Swift `String`), not Java (`Long`/`Integer`/`Boolean` intentionally absent); Clojure-native collections use Swish names (`Vector`/`List`/`Map`/`Set`/`Seq`/…). `nil` dispatches as `"nil"` and never falls back to `Object`. Real ObjC/Swift class-hierarchy dispatch is a deliberate future concern — an *additive* foreign-object `Expr` case, not a rewrite of the enum. Detail in NOTES.md.
- **Exact-type-match dispatch**: sorted collections and map-entries are distinct keys (`:sorted-map`/`:sorted-set`/`:map-entry`), so extending `Map`/`Set`/`Vector` doesn't catch them.
- **Mutable `deftype` fields** (`^:unsynchronized-mutable`/`^:volatile-mutable`) are unimplemented — the annotations parse without erroring but fields are immutable (needs per-instance mutable storage the type lacks). This is why the mutable-field form of `set!` is also unimplemented.
- `deftype`/`defrecord` **inline** method bodies get unqualified field access (a synthetic `let` binds each field from the method's first param) — matching Clojure, where retroactive `extend-type` methods don't.

### `reify`

`reify` (`evalReify`, `Evaluator+Deftype.swift`) makes one anonymous instance whose methods **close over the surrounding lexical env** (the defining difference from `deftype`). Reuses protocol machinery via a per-instance inline method table (an anonymous `.deftype` with reserved `__swish_reify_*__` keys); needs a `reify`-aware alias-expansion clause (`expandReifyForm`) to avoid qualifying method names — see NOTES.md. Divergences: `type` returns a per-instance gensym keyword (`:reify__N`), so two instances of the same form aren't `=`; only Swish protocols (not `Object`/interface methods); same-named methods across protocols resolve last-wins with no conflict detection.

### `set!` — thread-bound dynamic vars only

`set!` (`evalSet`, `Evaluator+Binding.swift`) implements only `(set! var-symbol value)` — mutating the current thread-local `binding` of a dynamic var (e.g. `(set! *print-length* 50)` inside a `binding` scope). A faithful port of `Var.doSet`: the target must be thread-bound or it throws Clojure's "Can't change/establish root binding" (no separate `isDynamic` check needed — a non-dynamic var is never thread-bound). No validator/watch involvement (Swish's `Var` has no validator). The mutable-`deftype`-field form is unimplemented (see Protocols); Java field/static assignment forms are permanently out of scope.

### STM (Software Transactional Memory)

`ref`, `dosync`, `ref-set`, `alter`, `commute`, `ensure` (`SwishRef.swift`, `Evaluator+STM.swift`, `CoreRef.swift`) use optimistic concurrency with deliberate simplifications vs. Clojure:
- **Conflict detection covers every touched ref (read *or* written), not just Clojure's write-focused read-set** — strictly conservative (more retries, never wrong). So `ensure` reduces to a conflict-checked read and `commute` reduces to `alter` (gives up Clojure's relaxed commutative-op throughput). This is actually *stricter* than Clojure, which doesn't conflict-check plain `deref` and permits write-skew.
- **A single global commit lock**, not per-ref lock ordering; transaction bodies run unlocked, the lock covers only the two-phase verify-then-write commit.
- **No per-ref locking or age-based "barging"** — retries are bounded (10000, matching Clojure's `RETRY_LIMIT`) so a stuck txn throws rather than hangs, but nothing prevents adversarial livelock.
- **Exceptions abort immediately**; only version conflicts retry.
- **Validators run at each `alter`/`ref-set`**, not deferred to commit.
- **No ref history** — `ref-min-history`/`ref-max-history` are get/set pairs, `ref-history-count` always 0; the optimistic design never blocks readers on writers, so history has no role.

### Agent lifecycle no-ops

Every agent gets its own dedicated GCD serial queue (not Clojure's two shared process-wide pools — GCD queues don't carry the JVM per-thread cost). Consequences: `shutdown-agents` and `restart-agent`'s `:clear-actions` are accepted but no-ops (no shared executor / held backlog); `set-agent-send-executor!`/`set-agent-send-off-executor!` aren't implemented. Sends issued inside a `dosync` are held until commit, and sends inside a running agent action are held until the action completes — matching Clojure's dispatch priority (transaction → running action → immediate), send-time dynamic bindings preserved. Implementation detail in NOTES.md.

### `tap>` never drops — unbounded queue

Real Clojure's `tap>` uses a bounded (1024-slot) `ArrayBlockingQueue` and returns `false` when full (dropped). Swish's `tap>` (`CoreConcurrency.swift`) dispatches onto a dedicated serial `DispatchQueue` (no fixed capacity), so it always returns `true` and never drops. The bounded-queue behavior exists to bound memory under sustained backpressure on a long-running JVM process — not a concern in Swish's usage.

### Future cancellation is cooperative-only (a platform limitation)

`future-cancel` only takes effect at explicit polling checkpoints (currently `sleep!`'s ~20ms loop), not truly preempting a running computation like Java's `Thread.interrupt()`. This is a hard ceiling on Apple platforms, not a cut corner: Swift's structured-concurrency cancellation is cooperative-only by design (SE-0304), `Thread.isCancelled` is a pollable flag, `pthread_cancel` is unimplemented on Darwin, and signal-based interruption is unsafe from Swift/GCD. The cooperative-polling approach is the Apple-recommended pattern.

### Nested syntax-quote depth tracking

Syntax-quotes inside syntax-quotes (`` `` ``~x``) do not increment depth — `~` always evaluates immediately regardless of nesting. Only affects macro-writing macros. See `syntaxQuoteExpand` in `Evaluator+Destructuring.swift`.

### Syntax-quote namespace resolution uses call-site namespace for `~` values

`preExpandSyntaxQuote` (at `defmacro` eval time) pre-qualifies quoted symbols using the defining namespace. But gensyms (`x#`) are generated fresh at each call rather than fixed at definition time (pre-generated gensyms get re-qualified by the runtime expander). Functionally correct, but differs from Clojure where gensyms are stable across calls.

### `case` dispatches via a linear equality chain, not a JVM jump table

Clojure's `case` compiles to a `tableswitch`/`lookupswitch` (O(1)); Swish has no bytecode compiler, so `case` (`core.clj`, ported from the real source) keeps every portable part verbatim but replaces the dispatch-code-generation step with a `cond`-chain of `(= ge 'test)` checks — semantically identical (verified against `case.cljc`, including the numeric-tower rules), just O(n). **Anti-pattern (learned here):** `expandAliases` must treat `case`'s test-constants as literal data, not code — but a broader "treat *any* macro call as opaque" fix was tried and reverted because it broke `cond` (most macros' args *are* code). Only `quote`-like macros (currently just `case`) get the skip; see NOTES.md.

### `subvec` copies its slice instead of sharing structure

Clojure's `subvec` is O(1) (a `SubVector` view). Swish's (`CoreSequence.swift`) copies the slice into a new vector, O(n) in slice size — same category as `case`'s O(n) dispatch; trie-slice sharing remains a deferred optimization, and nothing depends on `subvec` aliasing the original's storage.

### `with-precision` rounds only the final result, and supports one rounding mode

Swish implements `with-precision`/`*math-context*` (`core.clj`) with two simplifications:
- **Only the body's overall final result is rounded, not every intermediate BigDecimal op** — the arithmetic ops (`CoreArithmeticBasic.swift`) are plain closures with no evaluator access to read `*math-context*`, so `with-precision` expands to `(binding [*math-context* …] (round-with-math-context (do ~@body)))`. Matches Clojure for a single-expression body; differs for a body chaining multiple ops.
- **Only `:HALF_UP` is supported** (the vendored BigDecimal package rounds with one fixed HALF_UP-style strategy) — any other requested mode (`UP`/`DOWN`/`CEILING`/`FLOOR`/`HALF_DOWN`/`HALF_EVEN`/`UNNECESSARY`) throws rather than silently computing the wrong answer.
- **Note:** `bigdec-round-to-precision` (`CoreArithmeticPrecision.swift`) works around a real negative-rounding bug in the vendored `BigDecimal.withPrecision(_:)` by sign-normalizing. That's a vendored-package bug — don't "fix" it a second time if it's patched upstream; check first (NOTES.md).

### `format` follows Foundation's printf dialect, not Java's `java.util.Formatter`

`format` (`CoreString.swift`) is native, built on Foundation's `String(format:arguments:)` (printf/CFString dialect), which genuinely diverges from Java: `%s` expects a C string pointer, `%n` differs, no comma-grouping (`%,d`) or positional args (`%1$s`). A permanent platform divergence, not a partial port (the jank `format.cljc` fixture is deliberately conservative). **Note:** because C varargs have no type safety, a directive-shape scanner (`formatDirectiveShapes`) marshals each arg to what the *directive* expects (not the arg's own type) — two SIGSEGVs were fixed this way (see NOTES.md).

### `clojure.test` — `assert-expr` / `try-expr`

`is`'s general (non-`thrown?`) case dispatches through a real `assert-expr` multimethod (`test.clj`), giving rich failure output (`(not (= 5 4))` with real runtime values, not `(not false)`). Scope boundaries: `is`'s bare `thrown?`/`p/thrown?` stays a hardcoded `cond` branch; **`thrown?` doesn't check the exception type** — `c` in `(thrown? c body)` is parsed but discarded, because `catch` only ever matches the literal symbol `Exception` (`Evaluator+TryCatch.swift`), so there's no dispatchable type hierarchy. `thrown-with-msg?` has the same class-discarded limitation (only the message regex is checked).

### `ex-info`/`ex-message`/`ex-data`/`ex-cause`, and `thrown-with-msg?`

Implemented as pure `core.clj` (`;;; Exceptions`), via `(defrecord ExceptionInfo [message data cause])` giving a dispatchable type identity through `instance?`. `ex-info` doesn't validate `data` is a map (a deliberate unenforced simplification, like `into-array`'s `type`). **`ex-message`'s fallback is the one Swish-specific semantic call:** it returns `(:message e)` for an `ExceptionInfo`, `e` itself when `e` is a plain string, or `nil` otherwise — the plain-string fallback matters because `exprForError` converts every native `EvaluatorError` to a string before `catch` sees it, so this one rule covers both user-thrown strings and caught native errors. `ex-data`/`ex-cause` return `nil` for non-`ExceptionInfo` values.

### `clojure.template/do-template`

Implemented (`template.clj`), backed by a minimal `clojure.walk` port (`walk.clj`: just `walk`/`postwalk`/`postwalk-replace`). `clojure.test/are` is now `` `(temp/do-template ~argv (is ~expr) ~@args)`` (matching Clojure exactly). Because real substitution reaches inside `quote`, the `special_symbol_qmark.cljc` overlay was deleted. **Anti-pattern (learned here):** `walk`/`postwalk` must rebuild collections with `reduce` (native) and recurse directly, *not* via lazy `map`/`filter` + `partial` — the latter segfaults the runner thread via native call-stack depth (NOTES.md). Same root cause as `run-tests` below.

### Macro-adjacent code needs explicit namespace qualification

A literal symbol in a `defmacro`'s own syntax-quote template gets pre-qualified to the defining namespace (`preExpandSyntaxQuote`). Two shapes *don't* and need the namespace spelled out explicitly (`clojure.test/do-report`, not bare) to avoid `Undefined symbol 'user/…'` when run cross-namespace:
- **A `defmethod` body** (or any ordinary fn returning a syntax-quote template) — not a `defmacro`, so `preExpandSyntaxQuote` never runs on it.
- **An unquoted (`~`/`~@`) sub-expression inside an otherwise-quoted `defmacro` template** — `preExpandSyntaxQuote` doesn't reach into unquote.

A recurring pattern (hit by `assert-expr`/`do-report`, `try-expr`, `do-template`/`apply-template`). Fixing the underlying mechanism (`expandAliases`) is deferred — it runs interpreter-wide and already caused one revert (the `case` "any macro opaque" attempt above).

### `run-tests` uses `reduce` + `merge-with`, not `apply merge-with +`

**Anti-pattern (don't revert):** `run-tests` (`test.clj`) uses `(reduce #(merge-with + %1 %2) *initial-report-counters* (map test-ns namespaces))`, *not* Clojure's exact idiom `(apply merge-with + (map test-ns namespaces))`. The `apply merge-with +` form **segfaults with a stack overflow under Swift Testing's runner thread** — calling a variadic user fn through `apply` at this call depth costs more native stack than its wall-clock cost suggests, and the smaller runner-thread stack surfaces it (same root cause as `do-template`'s `walk` above). The `reduce` form is logically identical and crash-free.

### `re-pattern`/`re-matches`/`re-find`/`re-seq` + stateful matchers

Implemented natively (`CoreRegex.swift`, `SwishMatcher.swift`), matching Clojure's arg order and nil/bare-string/vector result shapes, on `Expr.regex(SwishRegex)`/`Regex<AnyRegexOutput>`. A matcher is its own `Expr` case (`.matcher`), keeping `atom?`/`deref` correctly false; matches are precomputed eagerly at `re-matcher` time. **`re-seq` is eager, not lazily realized** (`lazy-seq?` is `false` where Clojure reports `true`) — a measured divergence: `firstMatch(of:)` on a chopped `Substring` re-anchors `^` to the substring's local start, so genuine incremental laziness gives wrong results; `s.matches(of:)` on the whole string is correct but eager (NOTES.md). `swish-regex-whole-match?` (`CoreStringNS.swift`, used by `run-all-tests`) predates and is now redundant with `re-matches`.

### `into-array`'s `type` argument is accepted but not enforced

`SwishArray` is untyped (a plain `[Expr]` wrapper), so `into-array` (`CoreSequence.swift`) accepts the optional `type` arg for source compatibility but never inspects/validates it — same simplification `int-array`/`object-array` already make. Real class-reference symbols (`Integer/TYPE`, `String`) won't resolve if passed (no JVM class vars); a keyword/`nil` stand-in works since it's never inspected.

### Interpreter has a high per-element constant cost for lazy-seq-driven code

The tree-walker costs ~300–475µs per element for lazy-seq chains (`filter`/`range`/`map`-driven walks) — confirmed **linear**, not O(n²). Root cause: `range`/`filter`/`map`/etc. are ordinary interpreted `defn`s, and realizing one lazy element runs a full recursive interpreted call graph whose cost compounds with how many lazy layers it composes through. **Design guidance:** a core.clj sequence fn built as a single self-recursive `lazy-seq` is much cheaper than one composing multiple lazy layers (measured 4.5x for `range`) — prefer the former. The biggest wins so far (macro pre-expansion at definition time, the `first`-on-list and vector-`conj` O(n²) fixes, `range` delegation) are all shipped; benchmarks in NOTES.md. **The remaining lever is architectural, not micro-optimization** — a release-build profile of `(filter odd? (map inc (range …)))` shows the per-element cost dominated by three *inherent* categories: **ARC** retain/release (`Expr` is a heap `indirect enum`, so every value churns refcounts), **allocation** (a fresh `Environment` class + `[String: Expr]` dictionary per call), and **string-keyed dictionary hashing** (`Environment.get` hashes the symbol at every scope level; `specialFormNames.contains` hashes every list head). Cutting these needs a data-structure change (interning symbols to integers; a small-N binding structure to avoid per-call dict alloc; reducing `Expr` ARC), not lock elimination (removing `Environment`'s lock gave no measurable win). Two small per-call constant-cost wins — the thread-local mechanism swap and the `*ns*`-Var cache (NOTES.md) — together moved a sequence workload only ~5-6%, confirming the cost is distributed, not a hot spot.

## Deferred Performance/Architecture Items

Deferred because each needs a real design change, not a mechanical fix. Re-verify against current source before acting — this is a map, not a guarantee. (Items that were on this list and are now **done** — `cons`/`conj`-on-list O(1) via `SwishPersistentList`, `Environment` per-level `Mutex` removed, `evalList` fast-path + `evalSpecialForm` extraction, global-symbol `qualifiedVarCache`, the `currentNs()` double-lookup (now a cached `*ns*` Var), and the per-call thread-local storage swap off `Thread.current.threadDictionary` — are written up in NOTES.md; several carry load-bearing invariants repeated below.)

**Invariants from shipped work (don't regress):**
- **`evalList`'s special-form switch lives in a separate `evalSpecialForm(_:_:in:)` for stack depth** — `evalList` is the deepest-recursing function, and in debug builds every recursive frame would otherwise carry the whole switch's frame size (this caused a SIGBUS when `reify` was added as a 25th case). **Add any future special form to `evalSpecialForm`, not `evalList`.**
- **`qualifiedVarCache` (`Evaluator`) is invalidated only by the two mapping-deleting APIs** — it caches only literal-namespace (`findNs`) resolutions of home vars (`v.namespace === ns`), never alias/referred resolutions; `intern` reuses the Var object and `refer` never replaces a home var, so the *only* way a cached entry goes stale is deletion: **`ns-unmap` deletes the one `"<ns>/<name>"` key; `remove-ns` prefix-clears every `"<ns>/…"` key.** (Was "needs no invalidation" before those APIs existed.)
- **`starNsVar` (the cached `*ns*` Var) needs no invalidation** — same immutability as `qualifiedVarCache`: `*ns*` is interned once at init and its Var object is never replaced (only its value changes, via `in-ns`/`setCurrentNs`). `currentNs()`/`setCurrentNs()` read/write it directly. (The *remaining* deferral here is unrelated: `*ns*` is a plain non-dynamic Var, so `in-ns` is not thread-local — a threading-correctness concern documented in `Evaluator+Namespaces.swift`, deferred to whenever real background execution lands, not a perf item.)
- **Per-call thread-local state (`callDepth`/`bindingFrames`) lives in `EvaluatorThreadState`, keyed by thread identity in a `Mutex`-guarded dict** — the `Mutex` guards only the registry (lookup/insert); each state object is single-thread-owned and its fields mutate lock-free. **Don't** move the cold-path thread-locals (`currentTransaction`/`currentCancellationCheck`/`currentAgentActionSends`) off `Thread.current.threadDictionary` for this reason — they aren't per-call, so the ObjC lookup cost is irrelevant there; only the hot per-call slots earned the swap.

### `fn` literals redo static analysis on every evaluation

`evalFn`/`buildFnArity` (`Evaluator+FnDef.swift`) run destructuring expansion, recur validation, local-name collection, alias-expansion, and `macroexpandAll` over the `fn` form every time that *literal* is evaluated — e.g. `(fn [y] (+ x y))` inside `(defn make-adder [x] …)` is re-analyzed on every `make-adder` call. All of it depends only on the literal AST, so it's cacheable — but caching needs stable per-AST-node identity, which `Expr` (equal-by-value) doesn't have. A real design question, not a one-line memoization.

### Pasting a large multi-line form into the REPL costs O(n²) in the pasted text's length

`Repl.swift`'s `readMultilineInput` calls `continuationNeeded`/`computeIndent` (`ReplInputScanner.swift`) once per added line, and both rescan the whole accumulated input from the start — so an N-line paste triggers ~1+2+…+N character scans, O(n²), though the real work is O(n). Not yet reproduced at a perceptible size; would need incremental re-scanning (carry depth/position across calls) or scanning only the new suffix.

## REPL Commands

REPL commands are preceded by `/` (e.g., `/quit`, `/q`). This distinguishes them from Swish expressions.
