# Task: Implement transducers in Swish

Implement Clojure-style transducers (added in Clojure 1.7) in Swish. Read the
authoritative reference first: https://clojure.org/reference/transducers
(and the related https://clojure.org/news/2014/08/06/transducers-take-two).
Cross-check arities and semantics against
https://clojure.github.io/clojure for `transduce`, `sequence`, `into`,
`completing`, `reduced`, `eduction`, and the 1-arity forms of `map`, `filter`,
`take`, etc.

## What a transducer is (so we build the whole protocol, not half of it)

A transducer is a function that takes one reducing function and returns another.
A reducing function `rf` supports three arities:

- `(rf)` — init (0-arity), produces the seed when none is supplied
- `(rf result)` — completion (1-arity), called once at the end to flush state
  and finalize the accumulator
- `(rf result input)` — step (2-arity), the normal reduce step

The 1-arity forms of the sequence functions (`(map f)`, `(filter pred)`,
`(take n)`, etc.) must return a transducer — NOT a sequence. These are useless
on their own; they only have value when fed to `transduce`, `sequence`, `into`,
or `eduction`. Therefore this is a single cohesive unit of work: do not ship
1-arity forms without also shipping the consumers. Partial delivery = dead code.

## Prerequisite: early termination via `reduced` (do this first)

Grep confirms Swish has no `reduced`/`reduced?` today, and `reduce` is a native
in `Sources/SwishKit/Core/CoreHOF.swift`. Transducers like `take` and
`take-while` depend on early termination, so this must land first:

1. Add a `reduced` wrapper (a boxed value marking "stop now"). Implement
   `reduced`, `reduced?`, `ensure-reduced`, `unreduced`, and make `deref`
   work on a reduced box to extract its value.
2. Make the native `reduce` in `CoreHOF.swift` check for a reduced value after
   each step and stop immediately, returning the unwrapped value. Existing
   `reduce` callers and behavior must be unchanged when no reduced is produced.
3. Add tests proving `reduce` short-circuits on `reduced`.

Decide deliberately whether `reduced` is a new `Expr` case or a tagged
boxed object, consistent with how Swish already models boxed runtime values
(see `Expr.swift`, `SwishAtom.swift`, `LazySeqBox.swift`, `Var.swift`).
Document the choice.

## Core deliverables

Implement in `Sources/SwishKit/Resources/clojure/core.clj` where possible
(preferred — these are ordinary Clojure definitions), dropping to Swift in
`Sources/SwishKit/Core/` only where a primitive or performance/early-exit
hook is required.

1. `completing` — wraps a 2-arity rf to add 0/1-arity, with optional finalizer:
   `([f] ...)` and `([f cf] ...)`.
2. `transduce` — `([xform f coll] ...)` and `([xform f init coll] ...)`.
   Builds `(xform (completing f))`, runs `reduce` over `coll`, then calls the
   1-arity completion exactly once. Must honor `reduced`.
3. `into` — add transducer arity `([to xform from] ...)` alongside existing
   `([to from] ...)`. Use `transduce` with a conj-based rf; use transients if
   Swish's transient support (`CoreTransient.swift`) makes that sound, else
   plain `conj`.
4. `sequence` — `([xform coll] ...)` and the multi-coll arity. This is the
   hardest piece: it must apply the transducer LAZILY and incrementally, so an
   infinite input still works when the transducer (e.g. `(take n)`) bounds the
   output. Build on Swish's existing lazy machinery (`LazySeqBox`,
   `lazy-seq`). If a fully incremental implementation is too large for one pass,
   implement it correctly for finite input first and leave a clearly marked
   TODO with the laziness gap described — but state explicitly that infinite
   input + `(take n)` is the acceptance bar.
5. `eduction` — returns a reducible/seqable view that applies the xform on
   demand. Acceptable to implement in terms of `sequence` if a faithful
   reducible type is out of scope; note the tradeoff.

## Add 1-arity (transducer-returning) forms

Extend these to return a transducer when called without a collection. Keep all
existing seq-producing arities working exactly as before:

`map`, `filter`, `remove`, `take`, `take-while`, `take-nth`, `drop`,
`drop-while`, `map-indexed`, `keep`, `keep-indexed`, `mapcat`, `interpose`,
`dedupe`, `distinct`, `partition-all`, `replace`, `halt-when` (optional),
plus `cat` (a transducer, no seq form).

Stateful transducers (`take`, `drop`, `take-nth`, `partition-all`, `dedupe`,
`distinct`, `drop-while`, `take-while`) must hold per-invocation mutable state.
Use Swish's `volatile!`/`vswap!` if present, otherwise atoms
(`SwishAtom.swift`) — confirm which exists before writing. Each call to the
1-arity form returns a fresh transducer; state must not leak across reductions.

`take`'s transducer must return `(reduced result)` once `n` items have passed,
to enable the short-circuit. `cat` and `mapcat` must call the downstream rf
per element and propagate reduced correctly (`reduce`-within-reduce needs
`ensure-reduced`/`unreduced` handling).

## Reference semantics to match exactly

- Composition order: `(comp xf1 xf2)` applies `xf1` to each element first.
  Verify with `(transduce (comp (filter odd?) (map inc)) conj [] (range 10))`.
- Completion is called exactly once and flushes buffered state
  (`partition-all` must emit its final partial partition on completion).
- `into`/`transduce` with `(take n)` over `(range)` (infinite) must terminate.

## Tests (required, part of the same change)

Add tests alongside the existing Swish test suite. Cover at minimum:

- `(transduce (map inc) + 0 [1 2 3])` => 9
- `(transduce (filter even?) conj [] (range 10))` => `[0 2 4 6 8]`
- `(into [] (take 3) (range))` => `[0 1 2]` (proves laziness/early exit)
- `(into [] (comp (map inc) (filter even?)) (range 6))` => `[2 4 6]`
- `(sequence (take 3) (range))` => `(0 1 2)` over an infinite seq
- `(transduce (partition-all 2) conj [] (range 5))` =>
  `[[0 1] [2 3] [4]]` (proves completion flush)
- `reduce` short-circuits on `(reduced x)`
- A stateful transducer reused across two reductions starts clean each time

## Constraints

- Do not regress existing `map`/`filter`/`take`/`reduce`/`into` behavior; run
  the full test suite before and after.
- Prefer `core.clj` definitions; touch Swift only for `reduced` plumbing,
  `reduce` early-exit, and any lazy-`sequence` primitive that can't be
  expressed in core.
- Update `CLAUDE.md` with a short "Transducers" architecture note (where
  `reduced` lives, how `sequence` achieves laziness, which transducers are
  stateful).
- Work in small commits: (1) `reduced` + `reduce` early-exit + tests,
  (2) `completing`/`transduce`/`into`, (3) 1-arity transducer forms,
  (4) `sequence`/`eduction`. Build and test after each.

Report at the end: which functions are fully Clojure-compatible, and any
deliberately deferred gaps (especially in `sequence`/`eduction` laziness).
