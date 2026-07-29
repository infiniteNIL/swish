# NOTES.md — implementation history & fix war-stories

This file holds the detailed history behind the entries in [CLAUDE.md](CLAUDE.md):
how a divergence or fix was found, before/after benchmark numbers, bugs surfaced
during implementation, and alternatives that were tried and rejected.

**It is not auto-loaded** — CLAUDE.md links here with a plain link, not an
`@import`. Read it when you need the *why/how* behind a specific CLAUDE.md entry.
CLAUDE.md remains the source of truth for current behavior, active divergences,
and invariants; this file is the archive of reasoning. Sections mirror
CLAUDE.md's order. Deep detail also lives in git commit messages.

---

## Missing core forms — the two implementation batches

A systematic audit (direct eval of each candidate, not just grepping source —
grep alone gives false negatives for Swift-native/special-form registrations)
found these completely missing, confirmed by `Undefined symbol` on direct eval.
Unlike most divergences, these aren't JVM-hierarchy-driven simplifications —
they're common general-purpose Clojure forms that were simply never ported. All
are faithful ports of real Clojure's own source, placed alongside their
conceptual siblings.

**Batch 1** (`core.clj`, no Swift/native code, no new `Expr` case): `dotimes`,
`while`, `condp`, `declare`, `cond->`, `cond->>`, `as->`, `some->`, `some->>`,
`memoize`, `trampoline`.

**Batch 2**: `mapv`, `filterv`, `reduce-kv`, `partition-by`, `distinct?`,
`every-pred`, `reductions`, `when-some`, `if-some`, `doto`, `bound?` (all pure
`core.clj`); `clojure.set/rename-keys` (`set.clj`); `clojure.walk/keywordize-keys`
/`stringify-keys` (`walk.clj`); and three needing small native Swift: `ns-resolve`
(`CoreNamespace.swift`, reusing `resolveVar(name:in:)`/`the-ns`, parameterized by
the passed namespace) and `clojure.string/index-of`/`last-index-of`
(`CoreStringNS.swift`, via Swift `String.range(of:)`/`.backwards`, returning `nil`
not −1 when not found). `partition-by` and `reductions` are single self-recursive
`lazy-seq`s (not composed lazy layers) for the stack-depth reasons under the
per-element-cost section — verified stack-safe at 5000/10000 elements.
`partition-by`'s 1-arg stateful-transducer form buffers with `(volatile! [])`
rather than Clojure's `java.util.ArrayList`, the same adaptation `partition-all`
makes.

Two dependency gaps closed the same way (faithful port over inlining): `split-at`
(needed by `condp`'s real algorithm) is now a real port `[(take n coll) (drop n
coll)]`; and `unchecked-inc` (used by Clojure's `dotimes` as a JVM boxing hint
with no behavioral effect) has no Swish equivalent worth porting — `dotimes` uses
plain `inc`, exactly equivalent since Swish integers are already 64-bit.

## Multimethods — `mm-prefers?` stack overflow

`ancestors`/`parents` gained protocol-awareness via `protocols-of` (`core.clj`
Hierarchies): a real O(all interned vars) scan (~5.7ms/call against 461 vars in a
fresh env, linear in var count), since there's no type→protocols index to look up
directly.

`isa?` deliberately does NOT get this protocol-awareness — confirmed by reading
its source (`(contains? ((:ancestors h) child) parent)`, a raw hierarchy-map
lookup bypassing the `ancestors` function). One easy-to-miss consequence during
implementation: `mm-prefers?` (ambiguity resolution) calls `parents` *directly*,
not just `isa?` — initially missed, and wiring the protocol scan through it caused
a genuine stack overflow under Swift Testing's smaller-stack runner thread (the
recursive `mm-prefers?` walk compounding with each `parents` call's now-larger
frame, not the scan's O(n) cost — a neutralized empty-returning `protocols-of`
reproduced the crash just as reliably, isolating it to call-site depth). Fixed by
having `mm-prefers?` read `(:parents h)` directly instead of calling the public
`parents` fn — which matches real Clojure's own `MultiFn.prefers()` more
faithfully anyway (it accesses the hierarchy's internal parents map directly).

## Protocols — built-in-type dispatch design

`core.clj` binds a var for each built-in type name to the dispatch keyword the
runtime produces (= the value's `type`/`Expr.description`): `(def String
:string)`, `(def Int :integer)`, `(def Vector :vector)`, `(def Number :Number)`,
`(def Object :Object)`, etc. — so `(extend-type String P …)`/`(instance? Number
3)` resolve their type argument to a keyword exactly as a `deftype` type-var does.

**Naming is deliberately Swift-first, not Java:** scalars use their honest
underlying Swift type name (`String`/`Int`/`Double`/`Float`/`Bool`/`Character` — a
Swish string *is* a Swift `String`), forward-compatible with eventual Swift/ObjC
interop and avoiding fake `java.lang` names (the "no fake JVM symbols" rule);
persistent collections and Clojure-native scalars use Swish-native names
(`Vector`/`List`/`Map`/`Set`/`Seq`/`Keyword`/`Symbol`/`Ratio`/`BigInt`/
`BigDecimal`). `Long`/`Integer`/`Boolean` are intentionally absent (use
`Int`/`Bool`, or a `:swish` overlay for ported code).

Dispatch (`protocol-dispatch`, `core.clj`) checks the exact type key first, then
walks a fixed built-in ancestor table (`builtinAncestors`, `CoreProtocol.swift`,
exposed as `builtin-ancestors`): numerics → `[Number, Object]`, everything else →
`[Object]`, `nil` → `[]` (so `nil` never falls back to `Object`, matching
Clojure/Java where `null` is not an `Object`; `(extend-type nil …)` is its own
slot). This mirrors real Clojure's `find-protocol-impl` walking the class chain,
just backed by data. `satisfies?`/`extends?`/`instance?` respect the same table.
`deftype`/`defrecord` types fall back to `Object` too, so `(extend-type Object …)`
is a universal non-`nil` default. Swish's `:impls` is a single unified registry
for inline and `extend`-added impls, unlike Clojure's separate generated-interface
fast path — making `satisfies?`/`extends?`/`extenders` simpler.

Real ObjC/Swift class-hierarchy dispatch (for genuine `NSObject`/`NSNumber`
instances) is a deliberate *future* concern: it will arrive as an **additive**
foreign-object `Expr` case bridged at the interop boundary, whose dispatch can
consult the object's real runtime hierarchy — not a rewrite of the
value-representation `enum` (the enum + data-table was a deliberate architecture
choice, confirmed with the user).

Because Swish binds `Object` as an ordinary keyword tag rather than a class,
`(descendants Object)`/`(ancestors Object)` no longer throw the way real Clojure's
"can't get descendants of classes" does — the jank suite's fixtures carry
`:swish` overlays dropping those class-throwing assertions.

## reify — the `expandReifyForm` alias hazard

Adding `reify` as a special-form case is what forced the `evalList`→
`evalSpecialForm` switch extraction (see the evalList section below — a debug-build
stack-frame issue, not anything reify-specific).

The feature reuses existing protocol machinery — no new `Expr` case. Lexical
closure comes for free: `buildProtocolMethodImpls(_, in: env, …)` already builds
each method as a `SwishFunction` with `capturedEnv: env`; `evalReify` passes the
*local* env, so methods capture locals (deftype/extend-type pass a more global
env, which is why their methods don't get this). Each instance carries its own
per-instance inline method table (not `:impls` registration, since two evaluations
of one reify form need distinct closures): an anonymous `.deftype(typeName:
<gensym>, fields: [], data: {reifyMethodsKey → map, reifyProtocolsKey → set})`
with reserved `__swish_reify_*__` keys. `printDeftype` iterates only declared
fields (empty), so it prints as `#reify__N[]`. Dispatch touch-points: a native
`reify-method-table` (`CoreProtocol.swift`) fast-path in `protocol-dispatch`, and
`satisfies?` checking the instance's protocol-name set.

**The alias hazard** (`expandReifyForm`, `Evaluator+AliasExpansion.swift`): a
`reify` inside a `fn`/`defn` body is rewritten by `expandAliases` at definition
time; the generic list-recursion would treat each `(mname [params] body...)`
clause as a call and qualify the *method name* `mname → ns/mname`, so the
per-instance table would be keyed under a qualified name while `protocol-dispatch`
looks up the bare keyword — a silent dispatch miss (manifested as a `reify`-in-
`defn` test failing while the bare-`let` case passed). `expandReifyForm` qualifies
only the leading protocol symbols and leaves method clauses untouched. Same
`quote`/`case`/`fn`/`let`-style special-casing that list already needs;
`deftype`/`defrecord` have the identical latent hazard but never hit it (always
effectively top-level).

## Agent lifecycle — send buffering implementation

Real Clojure funnels every agent's actions through two shared process-wide pools
because JVM threads are expensive; GCD queues don't carry that per-thread cost, so
giving every agent its own dedicated serial queue was a deliberate architecture
choice. Consequence: `set-agent-send-executor!`/`set-agent-send-off-executor!`
aren't implemented (no shared executor to reassign).

Sends issued inside a `dosync` are held until commit; sends issued inside a running
agent action are held until the action completes — both matching Clojure's
dispatch priority (transaction → running action → immediate). The `dosync` half
(the real correctness gap): `send`/`send-off` in a transaction is buffered on
`TransactionContext.pendingActions` (`Evaluator+STM.swift`); `coreDosync`
(`CoreRef.swift`) releases the buffer — dispatching each held send exactly once —
only after `attemptCommit` succeeds. A retry/abort discards that attempt's
`TransactionContext` and buffer without releasing, so a retrying/aborting
transaction no longer fires its sends per attempt. The running-agent-action half
mirrors Clojure's `Agent.nested`: a thread-local `currentAgentActionSends` buffer
(`Evaluator+Concurrency.swift`) installed by `SwishAgent.runAction`; a nested
`send` is held (`holdAgentActionSend`) and released (`releaseAgentActionSends`)
only after the action completes successfully — discarded if it throws. The
user-facing `release-pending-sends` (`CoreConcurrency.swift`) flushes held nested
sends and returns the count (0 outside an action). Send-time dynamic bindings are
preserved: `coreSend` snapshots `captureCurrentBindings()` at the call site and
dispatches via `SwishAgent.enqueueCaptured(…, frames:)` when the buffer releases.
Priority is transaction-first, so a `send` inside a `dosync` nested in an agent
action goes to the transaction buffer.

## `case` — the `expandAliases` literal-data bug

Implementing `case` surfaced and fixed a real pre-existing bug: `expandAliases`
(`Evaluator+AliasExpansion.swift`, run on every `fn`/`defn` body to pre-qualify
bare symbols) walked into every list argument uniformly, with no awareness that a
macro's arguments might be unevaluated literal data rather than code. This
silently corrupted `case`'s test-constants (e.g. `list` inside a `(list of syms)`
test-constant rewritten to `clojure.core/list`) whenever `case` appeared inside a
`fn` body. Fixed by adding `case` to `expandAliasesInExpr`'s existing
`quote`/`syntax-quote`/`fn`/`let`/`loop` skip-list (skip it entirely, like
`quote`). **A broader fix (treat *any* macro call as opaque) was tried first and
reverted** — it broke `cond` and everything like it, since most macros' arguments
genuinely are code that should be qualified; only macros with `quote`-like
literal-data arguments (currently just `case`) need this, and that can't be
determined generically from "is this a macro," only from each macro's semantics.

## with-precision — the vendored BigDecimal negative-rounding bug

`BigDecimal.withPrecision(_:)` (`.build/checkouts/BigDecimal/Sources/BigDecimal/
BigDecimal.swift`) silently fails to round negative values in cases that need to
round away from zero. Its internal "does this need rounding" check (`p < 10 * r`)
compares against `r`, the remainder of a `BigInt` division that truncates toward
zero and so carries the sign of the input — for a negative input, `10 * r` is
always negative, making the check always false, so the rounding-adjustment step is
silently skipped (result truncated toward zero instead of rounded). Confirmed by
hand-tracing `BigDecimal(-0.12355).withPrecision(3)` → `-0.123` (wrong; should be
`-0.124`) against the positive case rounding correctly. Swish's
`bigdec-round-to-precision` (`CoreArithmeticPrecision.swift`) works around this by
sign-normalizing before calling `withPrecision` and re-negating after — the same
trick the package's own `/` operator uses internally (which is why plain division
doesn't exhibit it). **This is a bug in the vendored package, not something to
"fix" a second time if it's ever patched upstream — check first.**

## format — the two SIGSEGV fixes

Two crashes found and fixed during implementation, both from C varargs having no
type safety — the format string alone dictates what shape each argument position
must be, independent of the argument's own Swift type:
- `(format "%s" "hello")` crashed because a Swift `String` bridges to `CVarArg` as
  an object reference, but `%s` expects a raw C string pointer. Fixed by marshaling
  any string-shaped-directive argument through `NSString`/`.utf8String`, keeping
  the `NSString` alive for the call's duration.
- `(format "%s" 42)` crashed because the original marshaling was based on the
  *argument's* Swift type (`.integer` → native `Int`), not what the *directive*
  expects. Fixed by scanning the format string (`formatDirectiveShapes`) to
  classify each consuming directive as string-shaped, numeric-shaped, or no-arg,
  then marshaling each argument to match its directive's shape. A non-numeric value
  passed to a numeric-shaped directive now throws a clean
  `EvaluatorError.invalidArgument`.

This scanner is minimal — no positional-argument support, no comma-grouping —
purely to make the two natural patterns (`%s` on anything, numeric directives on
numbers) safe, not to achieve Java-`Formatter` parity.

## clojure.test — assert-expr / try-expr implementation

`is`'s general (non-`thrown?`) case dispatches through a real `assert-expr`
multimethod (`test.clj`), following the `defmulti`/`defmethod` pattern already used
by `report`/`use-fixtures`. A `:default` method fixes the previously-documented bug
where failure output showed `(not false)` (a re-evaluated opaque boolean) instead
of `(not (= 5 4))` (the quoted source form) — the fix quotes the form once at
macro-expansion time rather than splicing it back as code to re-run. A `'=` method
evaluates each side of `=` exactly once and reports the real runtime values. Since
`are` was rewritten to use real `do-template` substitution, this richer display now
fires for `are`-driven equality checks too.

Scope boundaries: `is`'s bare `thrown?`/`p/thrown?` handling stays outside
`assert-expr` dispatch, as a single hardcoded `cond` branch in `is`. (A second
branch for `(let [...] (thrown? ...))` was removed once `are` stopped burying
`thrown?` in a `let`.)

## ex-info — the uncaught-exception printing bug

While implementing `ex-info`/`ex-message`/`ex-data`/`ex-cause` (pure `core.clj`,
`;;; Exceptions` section, via `(defrecord ExceptionInfo [message data cause])`), a
separate previously-undiscovered bug was found: uncaught-exception printing was
broken for *every* thrown value. Confirmed by running the REPL before the fix:
`(throw (str "boom"))` printed `❌ SwishException(value: string)`; `(throw (Foo. 1
2))` printed `❌ SwishException(value: user/Foo)` — `Repl.swift` and `CLI.swift`
interpolated the raw Swift `Error` (`"\(error)"`, Swift's default struct-reflection
format) instead of routing the caught `Expr` through the printer. Fixed with a new
`Swish.describeError(_:) -> String` (`SwishKit.swift`), which runs `exprForError`'s
result through `Printer.strString` (the `str`-style unquoted formatter, so `(throw
"boom")` displays as `boom`, not `"boom"`) — both `Repl.swift`'s `printError` and
`CLI.swift`'s file-run error path now use it.

## clojure.template/do-template — the walk/partial stack overflow

`do-template` is backed by a minimal `clojure.walk` port (`walk.clj`) providing
just `walk`/`postwalk`/`postwalk-replace`. `walk`'s collection dispatch is narrowed
to `list?`/`vector?`/`map?`/`set?` — real Clojure's `walk` also special-cases
`IMapEntry`/`IRecord`, which only matter when walking runtime data; a macro
template is unevaluated reader syntax and never shaped like either.

`clojure.test/are` is now `` `(temp/do-template ~argv (is ~expr) ~@args)`` —
matching real Clojure exactly — replacing the old `partition`+`interleave`+`let`
expansion. Because real `do-template` does pure textual substitution (no enclosing
`let`), it reaches *inside* `quote`, which the old `let`-based `are` couldn't do —
so the `special_symbol_qmark.cljc` overlay that worked around that was deleted.

**The bug:** an initial upstream-literal port of `walk`/`postwalk` (using
`map`/`mapv` to rebuild collections and `partial` for `postwalk`'s self-recursion)
segfaulted with a stack overflow under Swift Testing's runner thread — reproducible
even substituting into `(p/thrown? (/ x 0))` (2 levels), confirmed as stack-depth
by reproducing outside the harness with `ulimit -s 512`. Root cause: `map`/`filter`
are lazy `core.clj` defns composing multiple independently-recursing layers — for a
small form the wall-clock cost is negligible but the native call-stack depth per
logical level is not, stacking on `walk`'s own nesting recursion. Fixed by
rebuilding collections with `reduce` (native, non-lazy) instead of `map`, and
having `postwalk` recurse directly instead of through `partial`.

## run-tests — the `apply merge-with +` segfault

Reverting to real Clojure's exact idiom `(apply merge-with + (map test-ns
namespaces))` segfaults with a stack overflow under Swift Testing's runner thread
(confirmed against the real test runner). Same class as the `walk`/`postwalk`
issue: calling a variadic user-defined function (`merge-with`) through `apply` from
this position costs more native stack depth than the operation's wall-clock cost
suggests, and the smaller runner-thread stack surfaces it — `apply merge-with +`
alone (top-level) and `(map test-ns namespaces)` alone both work in isolation; only
the combination, nested at this call depth, crashes.

`run-tests` uses `(reduce #(merge-with + %1 %2) *initial-report-counters* (map
test-ns namespaces))` instead — logically identical (still calls `merge-with` once
per namespace), crash-free, and covered by a multi-namespace regression test (the
cross-namespace merge had never been directly tested before). `doall` isn't needed
— `reduce` consumes the lazy `map` without it.

`run-all-tests`'s regex-filter arity separately called `re-find`, which didn't
exist at the time; it was fixed narrowly with `swish-regex-whole-match?`
(`CoreStringNS.swift`, via `String.wholeMatch(of:)`) rather than implementing
general `re-find` (which has since been implemented independently, see below).
`swish-regex-whole-match?` is now redundant with `re-matches` for new code but kept
to avoid touching `test.clj`'s call site.

## regex — re-seq eager, and the firstMatch re-anchoring probe

`re-pattern`/`re-matches`/`re-find`/`re-seq`/`re-matcher`/`re-groups`
(`CoreRegex.swift`) build on `Expr.regex(SwishRegex)`/`Regex<AnyRegexOutput>`.
Stateful matchers precompute matches eagerly at `re-matcher` time via `s.matches(of:
re.regex)`, so `(re-find m)` is O(1) walking a fixed `[Expr]` list.

**Why `re-seq` is eager (a measured divergence, not an oversight):** the
alternative — chopping `s` into successive substrings and re-running
`firstMatch(of:)` on each remainder for genuine incremental laziness — was tried
and empirically confirmed **unsafe**: Swift's
`Regex<AnyRegexOutput>.firstMatch(of:)` re-anchors `^` to a `Substring`'s own local
start rather than treating the original string's start as the sole `^` anchor
(standalone probe: `^\d` against `"123"` chopped after each match finds 3 matches,
one per digit, instead of 1). `s.matches(of:)` operates on the whole original
string throughout and gets `(re-seq #"^\d+" "1 2 3")` right (one match, `"1"`), but
at the cost of full-string eagerness: `(take 3 (re-seq re huge-string))` does the
full scan up front. `seq?` is `true` (an ordinary `.seq`), matching Clojure, but
`lazy-seq?` is `false` where Clojure reports `true` — the visible seam.

---

## Performance — per-element cost investigation & fixes

Swish's tree-walking interpreter costs roughly 300–475µs per element for chains
like `filter`/`range`/`vec`+`seq`+`next`-walks — confirmed **linear** (not
quadratic) by direct measurement with the built binary: `(count (filter (fn [_]
false) (range n)))` at n = 8000/16000/32000 → 3.88s/7.73s/15.16s, and `(dorun (seq
(vec (range n))))` from 16000→64000 (4x) took ~3.2x longer. A pure `loop`/`recur`
baseline with zero lazy-seq involvement costs only ~4.9µs/element (100k in 0.489s),
~20-100x cheaper — ruling out generic env-lookup/dispatch overhead as the dominant
cause. The real driver: `range`/`filter`/`map`/`iterate`/`take-while` are ordinary
interpreted `defn`s; realizing one lazy element runs a full recursive interpreted
call graph, and cost compounds multiplicatively with how many separate lazy layers
that graph composes through. **Design guidance (still active):** a core.clj
sequence fn built by composing multiple lazy layers pays a per-layer interpreter
tax on every element — prefer a single self-recursive `lazy-seq`.

### range 1-arg/2-arg delegation
`range`'s 1-arg form used to be `(take-while #(< % end) (iterate inc 0))`, composing
**two** independently-recursing interpreted functions (each wrapping its own
`LazySeqBox`), ~94µs/element, vs. the 3-arg form's single self-recursive `lazy-seq`
at ~21µs/element — a measured **4.5x** difference from composition depth alone. Fix:
1-arg/2-arg delegate to the 3-arg form (`step` fixed at 1). Release before/after on
`(count (filter (fn [_] false) (range 32000)))`: ~3.85s → ~2.15s (~44%).

### Macro pre-expansion (biggest per-element win)
Found by profiling (`sample` on `(count (filter (fn [_] false) (range 300000)))`):
the hot path was `syntaxQuoteExpand`/`expandSplicingElements` — a macro being
re-expanded per realized element. `callMacro` ran the full expansion and eval'd it
on every call, so `filter`'s `lazy-seq` body re-ran `when-let`'s `assert-args` +
`~@body` template on every element. Fix: `buildFnArity` (`Evaluator+FnDef.swift`)
runs `macroexpandAll` over each `fn`/`defn`/`deftype`-method body once at
definition, so per-element evaluation never re-expands (gated **off** for
`defmacro` bodies via `expandMacros: false`). Measured release before/after: `(count
(filter (fn [_] false) (range 32000)))` **2.14s → 0.58s (~3.7x)**; `(count (take
20000 (map inc (range 100000))))` **2.51s → 0.54s (~4.6x)**. Two latent bugs fixed
as part of it: (1) `expandAliases`/`macroexpandAll` only handled `.list`, not
`.seq`, but `cons`/`list` (and macro expansions like `when`→`(if … (do …))`)
produce `.seq` subforms — a stray `.seq` slipped through un-alias-qualified (broke
`clojure.test`'s `*report-counters*` cross-namespace); fixed by normalizing
`.seq`→`.list` in `macroexpandAll`. (2) `validateRecurTailPosition` descended into
`quote`/`syntax-quote`, treating a template `(recur …)` (e.g. `for`'s `do-mod`) as
a real recur; fixed by skipping `quote`/`syntax-quote` there. Recur-validation runs
on the *un*-expanded body (it's macro-aware); macros never introduce `recur`, so
validate-then-expand is equivalent.

### The two O(n²) fixes (found investigating random_sample's ≈n^1.5 runtime)
**`(first coll)` was O(n) on a `.list`.** `coreFirst` read the head via
`seqOf(coll).first`, and `seqOf`→`asSequence` converts a whole `SwishPersistentList`
to an array (O(n)) just to return element 0. So every `(first s)` in a first/next
walk was O(n), making the walk O(n²). Fix: `coreFirst` reads the head directly
(O(1)) for `.list`/`.seq`/`.vector`/`.sharedVector`/`.lazySeq`/`.nil`, keeping the
`seqOf` fallback for other seqables. `(every? pos? (vec (range 20000)))` **~5.5s →
~0.24s (~23x)**.

**`conj` onto a `.vector` was O(n).** `conjOne` did `.vector(elems + [item])` — a
full array copy per `conj` — so all vector-building was O(n²), because `.vector`
was a flat Swift array with no sharing. Fix: `.vector` is now backed by
`SwishPersistentVector` (`SwishPersistentVector.swift`), a Clojure-style 32-way
bit-partitioned persistent vector trie with a tail buffer — the indexed analogue of
`SwishPersistentList`, giving O(1)-amortized `conj`/`pop`, O(log₃₂ n) `nth`/`assoc`,
structural sharing. `conjOne`→`elems.conj(item)`; transient `conj!`, `pop`/`peek`/
`pop!`, and `assoc` all route through the trie. Measured release before/after
(best-of-3): `(count (into [] (range 100000)))` **27.3s → 1.15s (~24x)**; `(count
(transduce (map inc) conj [] (range 100000)))` **30.0s → 1.46s (~20x)**; `(count
(reduce conj [] (range 20000)))` **1.27s → 0.25s (~5x)**; `(count (filter even?
(mapv inc (vec (range 100000)))))` **31.8s → 3.4s (~9x)**; `(nth (vec (range
100000)) 99999)` **1.09s → 1.14s** (no read regression). This closed upstream
`random_sample`: at nitems=10000 the fixture went **~49s → 6.4s**, so the
`random_sample.cljc` overlay (sole diff: nitems 10000→2500) was deleted, restoring
full upstream coverage. Verified by `SwishPersistentVectorTests.swift`
(conj/subscript/assoc/pop across the 32/1024/32768 boundaries). `.sharedVector`
stays a flat `[Expr]`; `subvec` still copies its slice (trie-slice sharing
deferred).

### Persistent maps/sets (HAMT) — same O(n²) build, fixed via swift-collections
`SwishMap`/`SwishSet` wrapped a plain Swift `[Expr:Expr]`/`Set<Expr>`, so every
`assoc`/`dissoc`/`conj`/`disj` full-copied (COW, O(n)) and all map/set building was
O(n²) — the same class as the vector-`conj` bug, hitting `into`/`reduce`+`assoc`/
`zipmap`/`merge`/`frequencies`/`group-by`. Unlike the indexed vector,
swift-collections HAS the right structure, so `.map`/`.set` are now backed by
`TreeDictionary`/`TreeSet` (HAMT: structural sharing, O(log n) persistent ops).
Measured, release before/after (best-of-3): `(count (into {} (map (fn [i] [i i])
(range 100000))))` **80.9s → 2.1s (~38x)**; `(count (into #{} (range 100000)))`
**28.1s → 1.4s (~20x)**; `(count (zipmap (range 50000) (range 50000)))`
**13.9s → 1.5s (~9x)**. `.sortedMap`/`.sortedSet` stay plain (no persistent sorted
structure in swift-collections; deferred).

**Two correctness subtleties surfaced.** (1) **Cross-backing hash consistency:** a
`.map`/`.set` and an equal `.sortedMap`/`.sortedSet` are `=` and must hash equal,
but `TreeDictionary`/`TreeSet` don't hash like Swift `Dictionary`/`Set`. Fixed by
hashing both sides through backing-independent XOR-of-per-entry helpers
(`hashMapContents`/`hashSetContents`, Expr+Hashable.swift). Verified by
`CoreSortedMapTests` (a hash-map and equal sorted-map collide as one set element /
same map key). (2) **`keys`/`vals` correspondence:** the `case` macro zips `(keys
pairs)` with `(vals pairs)` positionally. `mapCollection`'s `project` closure
initially materialized a *fresh* `[Expr:Expr]` per call via `.swiftDictionary`, so
`(keys m)` and `(vals m)` read two independently-ordered Swift dictionaries and
misaligned — breaking `case` under some hash seeds (deterministic-looking in a
fresh process, flaky in the shared test evaluator). Fixed by having `project`
operate on the single stored `TreeDictionary` (its `.keys`/`.values` views
correspond). Iteration order of `(seq m)` is unchanged — `asSequence`/`Printer`
sort map keys explicitly regardless of backing.

### Sorted collections — comparators honored (was a silent correctness bug)
`.sortedMap`/`.sortedSet` were plain `[Expr:Expr]`/`[Expr]` with NO comparator
field, and `sorted-map-by`/`sorted-set-by` (`CoreSet.swift`) **dropped `args[0]`
(the comparator) entirely**, building with the default `compareExprValue` — so
`(sorted-set-by > 5 1 3)` silently came back ascending. Worse, `keys`/`vals` on a
sorted map were unsorted (they went through the hash-ordered `mapCollection`
path), and `subseq`/`rsubseq` didn't exist. Fixed by backing `.sortedMap`/
`.sortedSet` with `SwishSortedMap`/`SwishSortedSet` — a comparator-sorted array +
a stored `comparator: Expr?`.

**Why not swift-collections' `SortedSet`/`SortedDictionary`:** they exist (the
`SortedCollections` module, a B-tree), but are (a) **`Comparable`-only** — no
per-instance runtime comparator, which is exactly what `sorted-*-by` needs, and a
runtime comparator is a Swish fn that needs the evaluator to invoke and can throw
(comparing a keyword to a number errors), which a static non-throwing
`Comparable.<` can't express (and the underlying `_BTree` is `internal`); and (b)
explicitly **unstable prototypes** (the product is literally
`UnstableSortedCollections`, not re-exported by the `Collections` umbrella). Same
situation as the indexed vector — no library type matches our model — so we rolled
our own.

**Chosen: sorted array, not a balanced tree.** The foundational win is
correctness; a sorted array delivers it plus O(log n) lookup and O(n log n) batch
construction. Incremental `conj`/`into` stays O(n)/op (O(n²) build), acceptable for
the least-used core collection; a persistent balanced tree (O(log n) insert) is
deferred as not worth the complexity/risk.

**Two design points.** (1) **Comparator-defined equality:** in a sorted
collection, two keys/elements comparing `0` are the "same" (Clojure semantics), so
membership/dedup/lookup go through the comparator, never a Swift `Dictionary`/`Set`
— this falls out of binary-search insert naturally. `(count (sorted-set-by (fn [a
b] 0) 1 2 3))` → 1. (2) **Evaluator threading:** a custom comparator is a Swish fn,
so it must be invoked through the evaluator (`Evaluator.makeComparator` — native
`compareExprValue` for the nil default, else `call` the fn, promoting a boolean
result to 3-way with a reversed call, like `CoreSort`). This made the
mutation/lookup ops evaluator-aware: `conjOne` gained an evaluator param, and
`conj`/`conj!`/`assoc`/`assoc!`/`dissoc`/`dissoc!`/`disj`/`disj!`/`get`/`get-in`/
`find`/`contains?` + the sorted constructors are now registered `{ [evaluator]
args in … }`. Read ops (`seq`/`keys`/`vals`/`printer`) just read the pre-sorted
backing, no evaluator needed. Equality/hashing ignore the comparator and reuse
`hashMapContents`/`hashSetContents` for cross-`==`/hash-consistency with `.map`/
`.set`. `subseq`/`rsubseq` (`CoreSet.swift`) are native, filtering the sorted
backing by a bound-fn built from the comparator + the test fn applied to
`(compare ek key)` vs 0 — the same semantics as Clojure's `mk-bound-fn`. (Known
pre-existing gap, orthogonal: calling a *sorted* set/map as a function isn't
wired into the call dispatch, though `get`/`contains?` work.)

### LazySeqBox NSLock stays (rejected Mutex swap) — measured
`LazySeqBox.swift` uses `NSLock`, not `Synchronization.Mutex` like the rest of the
codebase (an oversight per git history: the `Mutex` retrofit `c511047` never
touched it). A full conversion was prototyped and empirically tested at multiple
chain depths: converting the ordinary lock/unlock sites is safe, but converting the
custom `deinit` (which iteratively unlinks a long realized chain to avoid
stack-overflow-prone recursive ARC teardown) **reintroduces essentially the same
stack overflow**, crashing at ~30-40k chain depth instead of surviving 1M+ —
`Mutex` has no lock-free escape hatch, and this `deinit`'s stack-safety depends on
plain non-opaque field mutation the optimizer can see through, which
`Mutex.withLock`'s generic closure boundary defeats. No partial-conversion path
exists. **Left on `NSLock` deliberately — don't revisit casually.** (`DelayBox`,
the same-shaped sibling, WAS safely converted to `Mutex<State>` — it holds a single
`Expr`, no chain, no custom `deinit`.)

### LazySeqBox custom deinit (why it exists)
`next`/`seq` memoize each realized step as `.cons(head, tail: .lazySeq(nextBox))`,
forming a singly-linked chain of `LazySeqBox` objects once walked. Since `Expr` is
an `indirect enum` (heap-boxed), the compiler-generated `deinit` for a long chain
isn't tail-call-optimized — releasing the head recursively releases each link, one
native frame per link, crashing at ~20000 elements (confirmed via `(dorun (range
n))`, independent of forcing logic). Fixed with a custom `deinit` that iteratively
unlinks the tail chain (using `isKnownUniquelyReferenced` to only detach unaliased
links). **Don't remove it.**

### Environment per-level Mutex removed — measured, no perf win
`Environment` used to take a `Mutex` lock at every scope level on every lookup,
added defensively. No `Environment` is ever shared-and-mutated across threads
(global `def`s live in namespace var tables; each env is written only during setup
on its creating thread, then read-only). The one exception, `loop`/`recur` mutating
a single `loopEnv` in place, was **also a latent correctness bug**: a closure
capturing a loop variable saw the loop's *final* value, not its iteration's (`(map
#(%) (loop [i 0 fns []] (if (< i 3) (recur (inc i) (conj fns (fn [] i))) fns)))`
gave `(3 3 3)` vs Clojure's `(0 1 2)`). Fixed by building a **fresh env per
iteration** (as `fn` recur already did), which corrects the capture bug and makes
every env write-once-then-read-only, so the `Mutex` could drop. **Measured, and the
perf motivation did not materialize:** `(count (filter … (range 32000)))` ~2.12s →
~2.16s (no change — uncontended `Mutex` is ~one CAS, lost in the noise); the loop
benchmark got ~8% *slower* (per-iteration env allocation). Kept as a correctness
fix + simplification, not a speedup — a "measured, not assumed" cautionary tale.
**The invariant to preserve: loop/recur builds a fresh env per iteration.**

### evalList dispatch + evalSpecialForm extraction
Two changes. (1) A fast-path guard was added before the 20-way special-form switch
(`guard … Evaluator.specialFormNames.contains(name) else { straight to call path
}`) so ordinary calls don't fail all 20 comparisons. Measured humbler than theory:
~1.5–1.7% on two benchmarks (vs range's 44%) — dispatch is a small fraction of
per-call cost. Another "measured, not assumed" case. (2) **The switch was extracted
into a separate `evalSpecialForm(_:_:in:)` for stack depth, not speed** — and this
is load-bearing. In the debug build the tests run under, `evalList`'s frame
allocated space for the whole switch, so *every* recursive `evalList` frame carried
that cost, and `evalList` is the deepest-recursing function. Adding `reify` as a
25th case grew the frame enough to push `runTestsMergesAcrossMultipleNamespaces`
(a stack-marginal test) into a hard SIGBUS on the runner thread — reproduced 3/3
vs 0/3, pinned by bisection + crash backtrace. Moving the switch to its own function
makes the hot ordinary-call frame small again (guard, then a tail call only for
actual special forms), and *more* than absorbs the reify case. **Any future special
form goes into `evalSpecialForm`, whose frame growth the deep ordinary-call
recursion doesn't multiply — not into `evalList`.** No `@inline(never)` needed.

### Global-symbol resolution cached
Every reference to a builtin by name that isn't a local binding used to re-resolve
from scratch with ~10 uncached `Mutex` lock/unlock pairs per reference (traced:
`env.get` miss 2 → `resolveQualifiedVar`: `currentNs()` 3 + `findAlias` 1 + `findNs`
1 + `findVar` 1 → `dynamicValue` 2). Fixed with a `qualifiedVarCache: Mutex<[String:
Var]>` on `Evaluator`, checked first in `resolveQualifiedVar`. **No invalidation
logic is needed — verified against current source:** `Namespace.intern` always
reuses the existing Var object for an already-home mapping (only `.value` changes,
never identity), `Namespace.refer` throws rather than replacing a differing Var, and
there's no `ns-unmap`/`remove-ns`/any API deleting a mapping; `in-ns`/`create-ns` on
an existing name returns the *same* `Namespace` object. Cached only when both hold:
(1) resolution went through the literal-namespace branch (`findNs`), never the alias
branch (an alias means different things per caller's namespace); (2) the resolved
Var's home namespace is the namespace searched (`v.namespace === ns`) — a referred
non-home var can later be shadowed by a local `def` creating a new Var.
`Var.dynamicValue`'s two lock acquisitions were combined into one
(`snapshotIsDynamicAndValue()`). Measured: `(count (filter … (range 32000)))`
~5.6s → ~3.9s (~30%).
