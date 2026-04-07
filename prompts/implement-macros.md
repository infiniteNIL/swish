# Implement Clojure-Style Macros for Swish

## Overview

Implement macros for Swish that behave like Clojure macros. Macros are functions that run at expansion time on unevaluated code (receiving Expr AST nodes, not runtime values) and return new code that is then evaluated. This is the key difference from regular functions: **macro arguments are not evaluated before being passed to the macro body**.

Read CLAUDE.md and swift.md before writing any code.

## What to Implement

### 1. New `Expr` Case: `.macro`

In `Parser.swift`, add a new case to the `Expr` enum:

```swift
indirect case macro(name: String?, params: [String], body: [Expr])
```

Make sure `Equatable` conformance and the `Printer` handle this new case. The printer should render macros as `#<macro name>` (or `#<macro>` if unnamed).

### 2. Variadic Parameter Destructuring (`&` rest args)

Before implementing macros, extend the existing `fn` parameter handling to support `&` for variadic/rest parameters. This is needed for both `fn` and `defmacro` since many useful macros require variadic args (e.g., `when`, `cond`, `->`, `->>`, `do` wrappers).

**Syntax:** `[a b & rest]` — `a` and `b` are bound positionally; `rest` is bound to a **list** of all remaining arguments. If no extra arguments are passed, `rest` is bound to an empty list `()`.

**In the Parser** (`Parser.swift`):
- When validating `fn` or `defmacro` param vectors, allow the symbol `&` followed by exactly one more symbol:
  - `[x & rest]` is valid
  - `[x &]` is invalid (nothing after `&`)
  - `[x & a b]` is invalid (more than one symbol after `&`)
  - `[& rest]` is valid (zero fixed params, everything goes to rest)
- Add `ParserError.invalidFn("& must be followed by exactly one symbol")` (reuse existing error case)

**In the Evaluator** (`Eval.swift`):
- When creating a function or macro from a param vector, detect whether `&` is present:
  1. Find the index of `&` in the params list
  2. Split into `fixedParams` (before `&`) and `restParam` (after `&`)
  3. Store this info — you have options:
     - **Option A (recommended):** Keep the `&` and rest param name in the `params` array as-is. At call time, detect `&` in the params to determine variadic behavior.
     - **Option B:** Add a `restParam: String?` field to `.function` and `.macro` cases.

  Option A is simpler and requires no Expr enum changes beyond the `.macro` case.

- **At function/macro call time:**
  1. Check if params contains `&`
  2. If yes: bind fixed params positionally, collect remaining args into a `.list(...)`, bind to the rest param
  3. Arity check: must have **at least** `fixedParams.count` arguments (can have more)
  4. If no `&`: existing exact-arity behavior unchanged

Example implementation sketch for call-site binding:
```swift
if let ampIndex = params.firstIndex(of: "&") {
    let fixedParams = Array(params[..<ampIndex])
    let restParam = params[ampIndex + 1]  // the symbol after &
    guard args.count >= fixedParams.count else {
        throw EvaluatorError.arityMismatch(...)
    }
    for (param, arg) in zip(fixedParams, args) {
        callEnv.set(param, arg)
    }
    let restArgs = Array(args.dropFirst(fixedParams.count))
    callEnv.set(restParam, .list(restArgs))
}
else {
    // existing exact-arity binding
    guard args.count == params.count else { ... }
    for (param, arg) in zip(params, args) {
        callEnv.set(param, arg)
    }
}
```

This applies to **both** `.function` calls and `.macro` expansion. Extract a shared helper like `bindParams(params:args:into:name:)` to avoid duplication.

**Update `checkUndefinedSymbols`:** When walking `fn` or `defmacro` param vectors, filter out the `&` symbol — it's not a binding, just a delimiter. Only add actual param names (not `&`) to the local bindings set.

### 3. `defmacro` Special Form

`defmacro` is a special form (like `def` or `fn`) with the syntax:

```clojure
(defmacro name [params] body...)
```

Supports variadic params:
```clojure
(defmacro when [test & body]
  `(if ~test (do ~@body) nil))
```

Example:
```clojure
(defmacro unless [condition then]
  `(if ~condition nil ~then))
```

**In the Parser** (`Parser.swift`):
- Add parse-time validation for `defmacro` in `parseList()`, similar to `def`/`fn` validation:
  - Must have at least 3 elements: `defmacro`, name symbol, param vector, and at least one body form
  - First arg must be a symbol (the macro name)
  - Second arg must be a vector of symbols (parameters)
- Add a `ParserError.invalidDefmacro(String)` case

**In the Evaluator** (`Eval.swift`):
- When the head of a list is `(defmacro ...)`:
  1. Extract the name, params, and body (same pattern as `fn`)
  2. Create a `.macro(name: name, params: params, body: body)` value
  3. Store it in `environment` (same as `def` does): `environment.set(name, macroValue)`
  4. Return `.symbol(name)` (same as `def`)

### 4. Macro Expansion at Call Site

When evaluating a list `(head arg1 arg2 ...)` and the head resolves to a `.macro`, the evaluator must:

1. **Do NOT evaluate the arguments.** Pass the raw `Expr` nodes from `elements.dropFirst()` directly as the macro's arguments.
2. Create a child environment with macro params bound to these unevaluated argument expressions.
3. Evaluate the macro body in that environment. This produces the **expanded form** (a new `Expr`).
4. **Evaluate the expanded form** in the original calling environment (`env`).

This is the fundamental difference from function calls. In the existing function call code, args are evaluated with `try elements.dropFirst().map { try eval($0, in: env) }`. For macros, skip that step.

Place the macro dispatch **before** the general function-call code in the eval method. After resolving the head with `let callee = try eval(head, in: env)`, check for `.macro` before checking for `.nativeFunction` and `.function`.

### 5. `gensym` Function

Register a native function `gensym` in `Core.swift` that generates unique symbols to prevent variable capture in macro expansions.

Add an atomic counter to the `Evaluator` class:

```swift
private var gensymCounter = 0

func gensym(prefix: String = "G__") -> String {
    gensymCounter += 1
    return "\(prefix)\(gensymCounter)"
}
```

Register in `Core.swift`:
```swift
evaluator.register(name: "gensym", arity: .variadic) { args in
    let prefix: String
    if let first = args.first, case .string(let p) = first {
        prefix = p
    }
    else {
        prefix = "G__"
    }
    return .symbol(evaluator.gensym(prefix: prefix))
}
```

`(gensym)` → a unique symbol like `G__1`
`(gensym "tmp__")` → a unique symbol like `tmp__2`

### 6. Auto-Gensym in Syntax-Quote (`foo#` Syntax)

This is Clojure's main macro hygiene mechanism. Inside a syntax-quote (backtick) template, any symbol ending in `#` is automatically replaced with a gensym'd symbol, and all occurrences of the same `foo#` within that template map to the same generated symbol.

Modify `syntaxQuoteExpand` in `Eval.swift`:

1. Add a `gensyms: inout [String: String]` dictionary parameter (or use a local dict at the top-level call).
2. When encountering a `.symbol(name)` where `name.hasSuffix("#")`, look up or create a gensym for it:
   ```swift
   case .symbol(let name) where name.hasSuffix("#"):
       let base = String(name.dropLast()) + "__"
       let generated = gensyms[name] ?? gensym(prefix: base)
       gensyms[name] = generated
       return .symbol(generated)
   ```
3. At the top-level `syntaxQuoteExpand` entry point, create a fresh `var gensyms: [String: String] = [:]` and thread it through recursive calls.

Example usage:
```clojure
(defmacro my-let [val body]
  `(let [x# ~val] ~body))
```
Each expansion gets a unique symbol for `x#`, preventing capture.

### 7. `macroexpand-1` and `macroexpand`

Register these as native functions in `Core.swift`. They are essential for debugging macros.

**`macroexpand-1`**: Takes a **quoted** form. If the form is a list whose head resolves to a macro, expand it one step (call the macro body on the unevaluated args). Otherwise return the form unchanged.

```swift
evaluator.register(name: "macroexpand-1", arity: .fixed(1)) { args in
    guard case .list(let elements) = args[0], !elements.isEmpty else {
        return args[0]
    }
    guard case .symbol(let name) = elements[0],
          let value = evaluator.environment.get(name),
          case .macro(_, let params, let body) = value else {
        return args[0]
    }
    let macroArgs = Array(elements.dropFirst())
    guard macroArgs.count == params.count else {
        throw EvaluatorError.arityMismatch(
            name: name, expected: .fixed(params.count), got: macroArgs.count)
    }
    let macroEnv = Environment(parent: evaluator.environment)
    for (param, arg) in zip(params, macroArgs) {
        macroEnv.set(param, arg)
    }
    var result: Expr = .nil
    for bodyExpr in body {
        result = try evaluator.eval(bodyExpr, in: macroEnv)
    }
    return result
}
```

Note: `macroexpand-1` needs to call `eval` on the macro body in the macro env. This means you'll need to either:
- Make the `eval(_:in:)` method internal (not private), or
- Add a `public func expandMacro(...)` helper on `Evaluator` that `macroexpand-1` and the main eval loop both call.

The cleaner approach: extract a helper method on Evaluator:

```swift
/// Expands a macro call once. Returns nil if the form is not a macro call.
func macroexpand1(_ expr: Expr) throws -> Expr? {
    guard case .list(let elements) = expr,
          !elements.isEmpty,
          case .symbol(let name) = elements[0],
          let value = environment.get(name),
          case .macro(_, let params, let body) = value else {
        return nil
    }
    let macroArgs = Array(elements.dropFirst())
    guard macroArgs.count == params.count else {
        throw EvaluatorError.arityMismatch(
            name: name, expected: .fixed(params.count), got: macroArgs.count)
    }
    let macroEnv = Environment(parent: environment)
    for (param, arg) in zip(params, macroArgs) {
        macroEnv.set(param, arg)
    }
    var result: Expr = .nil
    for bodyExpr in body {
        result = try eval(bodyExpr, in: macroEnv)
    }
    return result
}
```

Then use this in the eval method for macro dispatch, and register macroexpand-1/macroexpand as:

```swift
evaluator.register(name: "macroexpand-1", arity: .fixed(1)) { args in
    try evaluator.macroexpand1(args[0]) ?? args[0]
}

evaluator.register(name: "macroexpand", arity: .fixed(1)) { args in
    var form = args[0]
    while let expanded = try evaluator.macroexpand1(form) {
        form = expanded
    }
    return form
}
```

**Usage** (note: the argument is quoted so it isn't evaluated as a call):
```clojure
(defmacro unless [condition then]
  `(if ~condition nil ~then))

(macroexpand-1 '(unless false 42))
;; => (if false nil 42)
```

### 8. Update `checkUndefinedSymbols`

Add awareness of `defmacro` so that symbol checking doesn't reject macro bodies. Handle `defmacro` the same way `fn` is handled: the macro params are local bindings for the body.

Also add `.macro` to the self-evaluating forms at the top of `eval(_:in:)`.

### 9. Update the REPL

No changes needed for basic functionality — macros will just work since they go through `eval`. But if the REPL has any special-casing for display, make sure `.macro` values display nicely (e.g., `#<macro unless>`).

## Files to Modify

1. **`Sources/SwishKit/Parser.swift`** — Add `.macro` case to `Expr`, add `ParserError.invalidDefmacro`, add parse-time validation for `defmacro`
2. **`Sources/SwishKit/Eval.swift`** — Add `defmacro` special form handling, macro expansion in call dispatch, `macroexpand1` helper, gensym counter, auto-gensym in `syntaxQuoteExpand`
3. **`Sources/SwishKit/Core.swift`** — Register `gensym`, `macroexpand-1`, `macroexpand`
4. **`Sources/SwishKit/Print.swift`** — Handle `.macro` case in `printString`/`displayString`
5. **`Tests/SwishKitTests/EvaluatorTests.swift`** — Add macro tests (see below)

## Tests to Write

Add a new `// MARK: - Macros` section in `EvaluatorTests.swift`. Use the existing test patterns (Swift Testing framework with `@Test` and `#expect`). Tests should use `Swish().eval(source)` for string-based tests or `evaluator.eval(expr)` for AST-based tests.

### Required test cases:

```swift
// MARK: - Variadic parameters (& rest)

@Test("fn with & rest collects extra args into list")
// (def f (fn [x & rest] rest))
// (f 1 2 3) => (2 3)
func fnVariadicRest() throws { ... }

@Test("fn with & rest and no extra args binds empty list")
// (def f (fn [x & rest] rest))
// (f 1) => ()
func fnVariadicRestEmpty() throws { ... }

@Test("fn with only & rest param")
// (def f (fn [& args] args))
// (f 1 2 3) => (1 2 3)
// (f) => ()
func fnOnlyRestParam() throws { ... }

@Test("fn with & rest too few fixed args throws arity error")
// (def f (fn [x y & rest] rest))
// (f 1) => throws arityMismatch
func fnVariadicTooFewArgs() throws { ... }

@Test("& in param vector must be followed by exactly one symbol")
// (fn [x &] x) => throws parser error
// (fn [x & a b] x) => throws parser error
func ampersandValidation() throws { ... }

// MARK: - Macros

@Test("defmacro defines a macro and returns its name")
// (defmacro my-macro [x] x) => my-macro
func defmacroReturnsName() throws { ... }

@Test("Simple macro expands and evaluates")
// (defmacro unless [cond then] `(if ~cond nil ~then))
// (unless false 42) => 42
func simpleMacroExpansion() throws { ... }

@Test("Macro receives unevaluated arguments")
// Define a macro that quotes its argument, proving it gets the raw symbol
// (defmacro get-code [x] `(quote ~x))
// (get-code (+ 1 2)) => (+ 1 2)   ; not 3
func macroReceivesUnevaluatedArgs() throws { ... }

@Test("Macro with multiple body forms")
// Body forms evaluated sequentially, last one is the expansion
func macroMultipleBodyForms() throws { ... }

@Test("gensym produces unique symbols")
// (gensym) and (gensym) produce different symbols
func gensymUnique() throws { ... }

@Test("gensym accepts custom prefix")
// (gensym "tmp__") produces symbol starting with "tmp__"
func gensymCustomPrefix() throws { ... }

@Test("Auto-gensym in syntax-quote replaces foo# with unique symbol")
// `(let [x# 1] x#) should produce (let [G__1 1] G__1) or similar
// where both x# map to the same generated symbol
func autoGensymInSyntaxQuote() throws { ... }

@Test("Auto-gensym produces consistent symbols within one template")
// Two occurrences of x# in the same syntax-quote get the same gensym
func autoGensymConsistent() throws { ... }

@Test("Auto-gensym produces different symbols across expansions")
// Two separate syntax-quote evaluations produce different gensyms for x#
func autoGensymFreshAcrossExpansions() throws { ... }

@Test("macroexpand-1 expands one step")
// (macroexpand-1 '(unless false 42)) => (if false nil 42)
func macroexpand1OneStep() throws { ... }

@Test("macroexpand-1 returns non-macro form unchanged")
// (macroexpand-1 '(+ 1 2)) => (+ 1 2)
func macroexpand1NonMacro() throws { ... }

@Test("macroexpand fully expands nested macros")
// Define macro A that expands to macro B call, verify full expansion
func macroexpandFull() throws { ... }

@Test("Macro arity mismatch throws error")
// (defmacro m [x] x) then (m 1 2) should throw arityMismatch
func macroArityMismatch() throws { ... }

@Test("defmacro with invalid syntax throws parser error")
// (defmacro 42 [x] x) — name must be symbol
func defmacroInvalidSyntax() throws { ... }

@Test("Variadic macro with & rest")
// (defmacro when [test & body]
//   `(if ~test (do ~@body) nil))
// (when true 1 2 3) => 3   (assuming do is implemented, or test with simpler body)
// Note: if `do` is not yet a special form, implement it as part of this work
// or test with a simpler variadic macro like:
// (defmacro my-list [& items] `(quote ~items))
func variadicMacro() throws { ... }

@Test("Macro expansion result is evaluated in caller's environment")
// Define a macro that expands to a reference to a caller-defined var
// (def y 10)
// (defmacro use-y [] `y)  ; note: no ~ needed, y is just a symbol in the template
// Actually: (defmacro use-y [] 'y) — returns the symbol y
// (use-y) => 10   ; evaluated in caller's env where y=10
func macroEvalsInCallerEnv() throws { ... }
```

### Parser tests to add in `ParserTests.swift`:

```swift
@Test("defmacro parses correctly")
// (defmacro m [x] x) parses to list with symbol defmacro, symbol m, vector, symbol x

@Test("defmacro requires symbol name")
// (defmacro 42 [x] x) throws invalidDefmacro

@Test("defmacro requires parameter vector")
// (defmacro m x x) throws invalidDefmacro
```

## Implementation Order

1. Add `&` rest-param support to parser validation for `fn` param vectors
2. Add `&` rest-param binding logic to function calls in the evaluator (extract a shared `bindParams` helper)
3. Write & run variadic param tests to confirm `fn` variadic works
4. Add `.macro` to `Expr` enum and update `Equatable`
5. Add `ParserError.invalidDefmacro` and parse validation (reuse `&` validation from step 1)
6. Add `.macro` to `Printer`
7. Add `.macro` to self-evaluating forms in `eval`
8. Implement `defmacro` special form in evaluator
9. Add `macroexpand1` helper method
10. Add macro dispatch in function call path (before `.nativeFunction`/`.function` checks), reusing `bindParams` from step 2
11. Add gensym counter and method to `Evaluator`
12. Register `gensym` in Core
13. Add auto-gensym to `syntaxQuoteExpand`
14. Register `macroexpand-1` and `macroexpand` in Core
15. Update `checkUndefinedSymbols` for `defmacro` and `&` in param vectors
16. Write all remaining tests
17. Run `swift test` and fix any issues

## Key Correctness Points

- Macro args are **never evaluated** before passing to the macro body. This is the whole point.
- The expanded form **is evaluated** in the caller's environment, not the macro's definition environment.
- The macro body itself is evaluated in a child of the global environment (with params bound), just like `fn` calls.
- `gensym` must produce globally unique symbols across the entire evaluator lifetime.
- Auto-gensym (`foo#`) must be scoped per syntax-quote expansion — each backtick-template gets a fresh mapping, but within one template all `foo#` resolve to the same generated symbol.
- `macroexpand-1` and `macroexpand` take **quoted** forms as arguments (since otherwise the macro would be invoked before macroexpand sees it).
