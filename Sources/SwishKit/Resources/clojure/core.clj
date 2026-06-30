(ns clojure.core
  "Fundamental library of the Clojure language")

(defmacro and
  "Evaluates exprs one at a time, from left to right. If a form
   returns logical false (nil or false), and returns that value and
   doesn't evaluate any of the other expressions, otherwise it returns
   the value of the last expr. (and) returns true."
  {:added "1.0"}
  ([] true)
  ([x] x)
  ([x & next]
  `(let [and# ~x]
  (if and# (and ~@next) and#))))

(defmacro comment
  "Ignores body, yields nil"
  {:added "1.0"}
  [& body])

; lazy-seq is a special form handled in Evaluator+SpecialForms.swift.
; It captures the body and lexical environment without evaluating them.

(defmacro doc
  "Prints documentation for the var named by name."
  {:added "1.0"}
  [name]
  `(print-doc '~name))

(defmacro defn [name & args]
  (let [has-doc  (string? (first args))
        doc      (if has-doc (first args) nil)
        args     (if has-doc (rest args) args)
        has-attr (map? (first args))
        attr     (if has-attr (first args) nil)
        args     (if has-attr (rest args) args)
        arglists (if (vector? (first args))
                   (list (first args))
                   (map first args))
        m        (merge (meta name) attr)
        m        (if doc (assoc (if m m {}) :doc doc) m)
        m        (assoc (if m m {}) :arglists arglists)]
    (if m
      `(def ~(with-meta name m) (fn ~name ~@args))
      `(def ~name (fn ~name ~@args)))))

(defmacro defn-
  "same as defn, yielding non-public def"
  {:added "1.0"}
  [name & decls]
  (list* `defn (with-meta name (assoc (meta name) :private true)) decls))

(defn not
  "Returns true if x is logical false, false otherwise."
  {:tag Boolean
   :added "1.0"
   :static true}
  [x] (if x false true))

(defn not=
  "Same as (not (= obj1 obj2))"
  {:tag Boolean
   :added "1.0"
   :static true}
  ([x] false)
  ([x y] (not (= x y)))
  ([x y & more] (not (apply = x y more))))

(defmacro or
  "Evaluates exprs one at a time, from left to right. If a form
   returns a logical true value, or returns that value and doesn't
   evaluate any of the other expressions, otherwise it returns the
   value of the last expression. (or) returns nil."
  {:added "1.0"}
  ([] nil)
  ([x] x)
  ([x & next]
  `(let [or# ~x]
  (if or# or# (or ~@next)))))

(defn some?
  "Returns true if x is not nil, false otherwise."
  {:tag Boolean
   :added "1.6"
   :static true}
  [x] (not (nil? x)))

(defmacro when
  "Evaluates test. If logical true, evaluates body in an implicit do."
  {:added "1.0"}
  [test & body]
  (list 'if test (cons 'do body)))

(defmacro when-not
  "Evaluates test. If logical false, evaluates body in an implicit do."
  {:added "1.0"}
  [test & body]
  (list 'if test nil (cons 'do body)))

(defmacro if-not
  "Evaluates test. If logical false, evaluates and returns then expr,
  otherwise else expr, if supplied, else nil."
  {:added "1.0"}
  ([test then] `(if (not ~test) ~then nil))
  ([test then else] `(if (not ~test) ~then ~else)))

(defmacro assert-args
  [& pairs]
  (when pairs
    `(do
       (when-not ~(first pairs)
         (throw (str "requires " ~(second pairs))))
       (assert-args ~@(next (next pairs))))))

(defmacro when-let
  "bindings => binding-form test

  When test is true, evaluates body with binding-form bound to the value of test"
  {:added "1.0"}
  [bindings & body]
  (assert-args
    (vector? bindings) "a vector for its binding"
    (= 2 (count bindings)) "exactly 2 forms in binding vector")
  (let [form (bindings 0) tst (bindings 1)]
    `(let [temp# ~tst]
       (when temp# (let [~form temp#] ~@body)))))

(defmacro if-let
  "bindings => binding-form test

  If test is true, evaluates then with binding-form bound to the value of
  test, if not, yields else"
  {:added "1.0"}
  ([bindings then]
   `(if-let ~bindings ~then nil))
  ([bindings then else & oldform]
   (assert-args
     (vector? bindings) "a vector for its binding"
     (nil? oldform) "1 or 2 forms after binding vector"
     (= 2 (count bindings)) "exactly 2 forms in binding vector")
   (let [form (bindings 0) tst (bindings 1)]
     `(let [temp# ~tst]
        (if temp#
          (let [~form temp#]
            ~then)
          ~else)))))

(defmacro when-first
  "bindings => x xs

  Roughly the same as (when (seq xs) (let [x (first xs)] body)) but xs is evaluated only once"
  {:added "1.0"}
  [bindings & body]
  (let [form (bindings 0) xs (bindings 1)]
    `(when-let [xs# (seq ~xs)]
       (let [~form (first xs#)]
         ~@body))))

(defn second
  "Same as (first (next x))"
  {:added "1.0"}
  [x] (first (next x)))

(defn nnext
  "Same as (next (next x))"
  {:added "1.1"}
  [x] (next (next x)))

(defn last
  "Return the last item in coll, in linear time"
  {:added "1.0"
   :static true}
  [s]
  (if (next s)
    (recur (next s))
    (first s)))

(defn butlast
  "Return a seq of all but the last item in coll, in linear time"
  {:added "1.0"
   :static true}
  [s]
  (loop [ret [] s s]
    (if (next s)
      (recur (conj ret (first s)) (next s))
      (seq ret))))

; Private alias used by functions copied verbatim from Clojure source.
; In JVM Clojure, reduce1 is a bootstrap helper defined before reduce;
; in Swish, reduce is native so reduce1 is simply an alias.
(def ^:private reduce1 reduce)

(defn reverse
  "Returns a seq of the items in coll in reverse order. Not lazy."
  {:added "1.0"
   :static true}
  [coll]
  (reduce conj () coll))

(defn to-array
  "Returns a vector containing the contents of coll."
  {:added "1.0"
   :static true}
  [coll]
  (vec coll))

(defn object-array
  "Returns a vector of n nils (stub; no Java array semantics)."
  [n]
  (vec (repeat n nil)))

(def array-map
  "Returns a map created from kvs (delegates to hash-map)."
  hash-map)

(defn take
  "Returns a lazy sequence of the first n items in coll, or all items if
  there are fewer than n. Returns a stateful transducer when no collection
  is provided."
  {:added "1.0"
   :static true}
  ([n]
   (fn [rf]
     (let [nv (volatile! n)]
       (fn
         ([] (rf))
         ([result] (rf result))
         ([result input]
          (let [n @nv
                nn (vswap! nv dec)
                result (if (pos? n) (rf result input) result)]
            (if (pos? nn)
              result
              (reduced result))))))))
  ([n coll]
   (lazy-seq
    (when (pos? n)
      (when-let [s (seq coll)]
        (cons (first s) (take (dec n) (rest s))))))))

(defn take-while
  "Returns a lazy sequence of successive items from coll while
  (pred item) returns logical true. pred must be free of side-effects.
  Returns a transducer when no collection is provided."
  {:added "1.0"
   :static true}
  ([pred]
   (fn [rf]
     (fn
       ([] (rf))
       ([result] (rf result))
       ([result input]
        (if (pred input)
          (rf result input)
          (reduced result))))))
  ([pred coll]
   (lazy-seq
    (when-let [s (seq coll)]
      (when (pred (first s))
        (cons (first s) (take-while pred (rest s))))))))

(defn drop
  "Returns a lazy sequence of all but the first n items in coll.
  Returns a stateful transducer when no collection is provided."
  {:added "1.0"
   :static true}
  ([n]
   (fn [rf]
     (let [nv (volatile! n)]
       (fn
         ([] (rf))
         ([result] (rf result))
         ([result input]
          (let [n @nv]
            (if (pos? n)
              (do (vswap! nv dec) result)
              (rf result input))))))))
  ([n coll]
   (let [step (fn step [n coll]
                (let [s (seq coll)]
                  (if (and (pos? n) s)
                    (recur (dec n) (rest s))
                    s)))]
     (lazy-seq (step n coll)))))

(defn drop-while
  "Returns a lazy sequence of the items in coll starting from the
  first item for which (pred item) returns logical false. Returns a
  stateful transducer when no collection is provided."
  {:added "1.0"
   :static true}
  ([pred]
   (fn [rf]
     (let [dv (volatile! true)]
       (fn
         ([] (rf))
         ([result] (rf result))
         ([result input]
          (let [drop? @dv]
            (if (and drop? (pred input))
              result
              (do (vreset! dv false) (rf result input)))))))))
  ([pred coll]
   (let [step (fn step [pred coll]
                (let [s (seq coll)]
                  (if (and s (pred (first s)))
                    (recur pred (rest s))
                    s)))]
     (lazy-seq (step pred coll)))))

(defn iterate
  "Returns a lazy sequence of x, (f x), (f (f x)) etc."
  {:added "1.0"
   :static true}
  [f x]
  (lazy-seq (cons x (iterate f (f x)))))

(defn range
  "Returns a lazy sequence of nums from start (inclusive) to end
  (exclusive) by step. start defaults to 0, step defaults to 1.
  With no args, returns an infinite lazy seq starting at 0."
  {:added "1.0"
   :static true}
  ([] (iterate inc 0))
  ([end] (take-while #(< % end) (iterate inc 0)))
  ([start end] (take-while #(< % end) (iterate inc start)))
  ([start end step]
   (lazy-seq
     (let [pred (if (pos? step) #(< % end) #(> % end))]
       (when (pred start)
         (cons start (range (+ start step) end step)))))))

(defn repeat
  "Returns a lazy (infinite, or length n if supplied) sequence of xs."
  {:added "1.0"
   :static true}
  ([x]
   (lazy-seq (cons x (repeat x))))
  ([n x]
   (take n (repeat x))))

(defn repeatedly
  "Takes a function of no args, presumably with side effects, and
  returns an infinite (or length n if supplied) lazy sequence of calls
  to it."
  {:added "1.0"
   :static true}
  ([f]
   (lazy-seq (cons (f) (repeatedly f))))
  ([n f]
   (take n (repeatedly f))))

(defn cycle
  "Returns a lazy (infinite) sequence cycling through the items in coll."
  {:added "1.0"
   :static true}
  [coll]
  (lazy-seq
    (let [s (seq coll)]
      (when s
        (concat s (cycle coll))))))

(defn concat
  "Returns a lazy seq representing the concatenation of the elements in
  the supplied colls."
  {:added "1.0"
   :static true}
  ([] (lazy-seq nil))
  ([x] (lazy-seq x))
  ([x y]
   (lazy-seq
     (let [s (seq x)]
       (if s
         (cons (first s) (concat (rest s) y))
         y))))
  ([x y & zs]
   (let [step (fn step [xys zs]
                (lazy-seq
                  (let [xys (seq xys)]
                    (if xys
                      (cons (first xys) (step (rest xys) zs))
                      (when-let [zs (seq zs)]
                        (step (first zs) (rest zs)))))))]
     (step (concat x y) zs))))

(defn map
  "Returns a lazy sequence consisting of the result of applying f to
  the set of first items of each coll, followed by applying f to the
  set of second items in each coll, until any one of the colls is
  exhausted. Returns a transducer when no collection is provided."
  {:added "1.0"
   :static true}
  ([f]
   (fn [rf]
     (fn
       ([] (rf))
       ([result] (rf result))
       ([result input] (rf result (f input))))))
  ([f coll]
   (lazy-seq
     (when-let [s (seq coll)]
       (cons (f (first s)) (map f (rest s))))))
  ([f c1 c2]
   (lazy-seq
     (let [s1 (seq c1) s2 (seq c2)]
       (when (and s1 s2)
         (cons (f (first s1) (first s2))
               (map f (rest s1) (rest s2)))))))
  ([f c1 c2 & colls]
   (let [step (fn step [cs]
                (lazy-seq
                  (let [ss (map seq cs)]
                    (when (every? identity ss)
                      (cons (apply f (map first ss))
                            (step (map rest ss)))))))]
     (step (list* c1 c2 colls)))))

(defn filter
  "Returns a lazy sequence of the items in coll for which (pred item)
  returns logical true. pred must be free of side-effects. Returns a
  transducer when no collection is provided."
  {:added "1.0"
   :static true}
  ([pred]
   (fn [rf]
     (fn
       ([] (rf))
       ([result] (rf result))
       ([result input] (if (pred input) (rf result input) result)))))
  ([pred coll]
   (lazy-seq
     (when-let [s (seq coll)]
       (let [f (first s) r (rest s)]
         (if (pred f)
           (cons f (filter pred r))
           (filter pred r)))))))

(defn remove
  "Returns a lazy sequence of the items in coll for which (pred item)
  returns logical false/nil. Returns a transducer when no collection
  is provided."
  {:added "1.0"}
  ([pred] (filter (complement pred)))
  ([pred coll] (filter (complement pred) coll)))

(defmacro lazy-cat
  "Expands to code which yields a lazy sequence of the concatenation
  of the supplied colls. Each coll expr is not evaluated until it is
  needed."
  {:added "1.0"}
  [& colls]
  `(concat ~@(map (fn [c] `(lazy-seq ~c)) colls)))

(defmacro cond
  "Takes a set of test/expr pairs. It evaluates each test one at a
   time. If a test returns logical true, cond evaluates and returns
   the value of the corresponding expr and doesn't evaluate any of the
   other tests or exprs. (cond) returns nil."
  {:added "1.0"}
  [& clauses]
  (when (seq clauses)
    (list 'if (first clauses)
          (if (next clauses)
            (second clauses)
            (throw "cond requires an even number of forms"))
          (cons 'cond (next (next clauses))))))

(defmacro ->
  "Threads the expr through the forms. Inserts x as the
   second item in the first form, making a list of it if it is not a
   list already. If there are more forms, inserts the first form as the
   second item in second form, etc."
  {:added "1.0"}
  [x & forms]
  (loop [x x, forms forms]
    (if forms
      (let [form     (first forms)
            threaded (if (seq? form)
                       `(~(first form) ~x ~@(next form))
                       (list form x))]
        (recur threaded (next forms)))
      x)))

(defmacro ->>
  "Threads the expr through the forms. Inserts x as the
   last item in the first form, making a list of it if it is not a
   list already. If there are more forms, inserts the first form as the
   last item in second form, etc."
  {:added "1.1"}
  [x & forms]
  (loop [x x, forms forms]
    (if forms
      (let [form     (first forms)
            threaded (if (seq? form)
                       `(~(first form) ~@(next form) ~x)
                       (list form x))]
        (recur threaded (next forms)))
      x)))

(defn inc
  "Returns a number one greater than num."
  {:added "1.0"}
  [x] (+ x 1))

(defn dec
  "Returns a number one less than num."
  {:added "1.0"}
  [x] (- x 1))

(defn zero?
  "Returns true if num is zero, else false."
  {:added "1.0"}
  [x] (not (or (pos? x) (neg? x))))

(defn pos?
  "Returns true if num is greater than zero, else false."
  {:added "1.0"}
  [x] (> x 0))

(defn neg?
  "Returns true if num is less than zero, else false."
  {:added "1.0"}
  [x] (< x 0))

(defn max
  "Returns the greatest of its arguments."
  {:added "1.0"
   :static true}
  ([x] x)
  ([x y] (if (> x y) x y))
  ([x y & more]
   (reduce (fn [m n] (if (> m n) m n)) (if (> x y) x y) more)))

(defn min
  "Returns the least of its arguments."
  {:added "1.0"
   :static true}
  ([x] x)
  ([x y] (if (< x y) x y))
  ([x y & more]
   (reduce (fn [m n] (if (< m n) m n)) (if (< x y) x y) more)))

(defn even?
  "Returns true if n is even, throws if n is not an integer."
  {:added "1.0"}
  [n] (= 0 (mod n 2)))

(defn odd?
  "Returns true if n is odd, throws if n is not an integer."
  {:added "1.0"}
  [n] (not (even? n)))

(defn identity
  "Returns its argument."
  {:added "1.0"}
  [x] x)

(defn constantly
  "Returns a function that takes any number of arguments and returns x."
  {:added "1.0"}
  [x] (fn [& args] x))

(defn complement
  "Takes a fn f and returns a fn that takes the same arguments as f,
   has the same effects, if any, and returns the opposite truth value."
  {:added "1.0"}
  [f]
  (fn [& args] (not (apply f args))))

(defn comp
  "Takes a set of functions and returns a fn that is the composition
  of those fns. ((comp f g) x) = (f (g x))."
  {:added "1.0"}
  ([] identity)
  ([f] f)
  ([f g]
   (fn [& args] (f (apply g args))))
  ([f g h]
   (fn [& args] (f (g (apply h args)))))
  ([f g h & fs]
   (reduce comp (list* f g h fs))))

(defn some-fn
  "Takes a set of predicates and returns a fn that returns the first
   logical true value returned by one of its predicates against any of
   its arguments, else nil."
  {:added "1.3"}
  [& preds]
  (fn [& args]
    (some #(some % args) preds)))

(defn juxt
  "Takes a set of functions and returns a fn that is the juxtaposition
  of those fns.  The returned fn takes a variable number of args, and
  returns a vector containing the result of applying each fn to the
  args (left-to-right).
  ((juxt a b c) x) => [(a x) (b x) (c x)]"
  {:added "1.1"
   :static true}
  ([f]
     (fn
       ([] [(f)])
       ([x] [(f x)])
       ([x y] [(f x y)])
       ([x y z] [(f x y z)])
       ([x y z & args] [(apply f x y z args)])))
  ([f g]
     (fn
       ([] [(f) (g)])
       ([x] [(f x) (g x)])
       ([x y] [(f x y) (g x y)])
       ([x y z] [(f x y z) (g x y z)])
       ([x y z & args] [(apply f x y z args) (apply g x y z args)])))
  ([f g h]
     (fn
       ([] [(f) (g) (h)])
       ([x] [(f x) (g x) (h x)])
       ([x y] [(f x y) (g x y) (h x y)])
       ([x y z] [(f x y z) (g x y z) (h x y z)])
       ([x y z & args] [(apply f x y z args) (apply g x y z args) (apply h x y z args)])))
  ([f g h & fs]
     (let [fs (list* f g h fs)]
       (fn
         ([] (reduce1 #(conj %1 (%2)) [] fs))
         ([x] (reduce1 #(conj %1 (%2 x)) [] fs))
         ([x y] (reduce1 #(conj %1 (%2 x y)) [] fs))
         ([x y z] (reduce1 #(conj %1 (%2 x y z)) [] fs))
         ([x y z & args] (reduce1 #(conj %1 (apply %2 x y z args)) [] fs))))))

(defn volatile!
  "Creates and returns a Volatile with an initial value of val."
  {:added "1.7"}
  [val]
  (atom val))

(defn vswap!
  "Non-atomically swaps the value of the volatile as if: (apply f current-value-of-volatile args)."
  {:added "1.7"}
  [vol f & args]
  (apply swap! vol f args))

(defn vreset!
  "Sets the value of volatile to newval without regard for the current value."
  {:added "1.7"}
  [vol newval]
  (reset! vol newval))

(defn completing
  "Takes a reducing function f of 2 args and returns a fn suitable for
  transduce by adding an arity-1 signature that calls cf (default:
  identity) on the result argument."
  {:added "1.7"}
  ([f] (completing f identity))
  ([f cf]
   (fn
     ([] (f))
     ([x] (cf x))
     ([x y] (f x y)))))

(defn transduce
  "Reduce with a transformation of f (xf). If init is not supplied,
  (f) will be called to produce it. f should be a reducing step
  function that accepts both 1 and 2 arity forms. Returns the result
  of applying (f result) to the final accumulated value."
  {:added "1.7"}
  ([xform f coll]
   (transduce xform f (f) coll))
  ([xform f init coll]
   (let [f (xform (completing f))]
     (f (reduce f init coll)))))

(defn into
  "Returns a new coll consisting of to-coll with all items of from-coll
  conjoined. A transducer may be supplied."
  {:added "1.0"}
  ([to from]
   (reduce conj to from))
  ([to xform from]
   (transduce xform conj to from)))

(defn set
  "Returns a set of the distinct elements of coll."
  {:added "1.0"}
  [coll]
  (reduce conj #{} coll))

(defn vec
  "Creates a new vector containing the contents of coll."
  {:added "1.0"}
  [coll]
  (into [] coll))

(defmacro assert
  "Evaluates expr and throws an exception if it does not evaluate to
  logical true."
  {:added "1.0"}
  ([x]
   `(when-not ~x
      (throw (str "Assert failed"))))
  ([x message]
   `(when-not ~x
      (throw ~message))))

(defn close
  "Closes a resource. Handles SwishReader, SwishWriter, and map resources
  with a :close key pointing to a zero-arity function."
  {:added "1.0"}
  [resource]
  (cond
    (reader? resource) (swish-close-reader! resource)
    (writer? resource) (swish-close-writer! resource)
    :else (when-let [f (:close resource)] (f))))

(defmacro with-open
  "bindings => [name init ...]

  Evaluates body in a try expression with names bound to the values
  of the inits, and a finally clause that calls (close name) on each
  name in reverse order."
  {:added "1.0"}
  [bindings & body]
  (assert (vector? bindings) "with-open requires a vector for its bindings")
  (assert (even? (count bindings)) "with-open requires an even number of forms in binding vector")
  (cond
    (= (count bindings) 0) `(do ~@body)
    (symbol? (first bindings)) `(let [~(first bindings) ~(second bindings)]
                                    (try
                                      (with-open ~(vec (drop 2 bindings)) ~@body)
                                      (finally
                                        (close ~(first bindings)))))
    :else (throw "with-open only allows Symbols in bindings")))

(defn line-seq
  "Returns the lines of text from rdr as a lazy sequence of strings.
  rdr must be a reader (use with with-open)."
  {:added "1.0"}
  [rdr]
  (when-let [line (swish-read-line! rdr)]
    (lazy-seq (cons line (line-seq rdr)))))

(defn sequence
  "Coerces coll to a (possibly empty) sequence, if it is not already
  one. Will not force a lazy seq. When a transducer xform is supplied,
  returns a lazy sequence of applications of the transform to the items
  in coll."
  {:added "1.7"}
  ([coll]
   (if (seq? coll) coll
     (or (seq coll) ())))
  ([xform coll]
   (let [rf (xform (completing conj))]
     (letfn [(advance [s]
               (lazy-seq
                 (if-let [s (seq s)]
                   (let [new-result (rf [] (first s))]
                     (if (reduced? new-result)
                       (seq (rf (unreduced new-result)))
                       (drain new-result (rest s))))
                   (seq (rf [])))))
             (drain [buf s]
               (lazy-seq
                 (if (seq buf)
                   (cons (first buf) (drain (rest buf) s))
                   (advance s))))]
       (advance coll)))))

(defn eduction
  "Returns a reducible/seqable application of the transducers to the
  items in coll. Transducer state is fresh per call to eduction."
  {:added "1.7"}
  [& xforms+coll]
  (sequence (apply comp (butlast xforms+coll))
            (last xforms+coll)))

(defn assoc-in
  "Associates a value in a nested associative structure, where ks is a
   sequence of keys and v is the new value and returns a new nested structure.
   If any levels do not exist, hash-maps will be created."
  {:added "1.0"
   :static true}
  [m [k & ks] v]
  (if ks
    (assoc m k (assoc-in (get m k) ks v))
    (assoc m k v)))

(defn update
  "Updates a value in an associative structure, where k is a
  key and f is a function that will take the old value
  and any supplied args and return the new value, and returns a new
  structure. If the key does not exist, nil is supplied as the old value."
  {:added "1.7"
   :static true}
  ([m k f] (assoc m k (f (get m k))))
  ([m k f x] (assoc m k (f (get m k) x)))
  ([m k f x y] (assoc m k (f (get m k) x y)))
  ([m k f x y z] (assoc m k (f (get m k) x y z)))
  ([m k f x y z & more] (assoc m k (apply f (get m k) x y z more))))

(defn update-in
  "Updates a value in a nested associative structure, where ks is a
  sequence of keys and f is a function that will take the old value
  and any supplied args and return the new value, and returns a new
  nested structure. If any levels do not exist, hash-maps will be created."
  {:added "1.0"
   :static true}
  ([m ks f & args]
   (let [up (fn up [m ks f args]
              (let [[k & ks] ks]
                (if ks
                  (assoc m k (up (get m k) ks f args))
                  (assoc m k (apply f (get m k) args)))))]
     (up m ks f args))))

(defn select-keys
  "Returns a map containing only those entries in map whose key is in keys"
  {:added "1.0"
   :static true}
  [map keyseq]
  (loop [ret {} keys (seq keyseq)]
    (if keys
      (let [entry (find map (first keys))]
        (recur
          (if entry
            (conj ret entry)
            ret)
          (next keys)))
      (with-meta ret (meta map)))))

(defn key
  "Returns the key of the map entry."
  {:added "1.0"
   :static true}
  [e] (first e))

(defn val
  "Returns the value of the map entry."
  {:added "1.0"
   :static true}
  [e] (second e))

(defn merge-with
  "Returns a map that consists of the rest of the maps conj-ed onto
  the first.  If a key occurs in more than one map, the mapping(s)
  from the latter (left-to-right) will be combined with the mapping in
  the result by calling (f val-in-result val-in-latter)."
  {:added "1.0"
   :static true}
  [f & maps]
  (when (some identity maps)
    (let [merge-entry (fn [m e]
                        (let [k (key e) v (val e)]
                          (if (contains? m k)
                            (assoc m k (f (get m k) v))
                            (assoc m k v))))
          merge2 (fn [m1 m2]
                   (reduce merge-entry (or m1 {}) (seq m2)))]
      (reduce merge2 maps))))

(defn empty?
  "Returns true if coll has no items - same as (not (seq coll))."
  {:added "1.0"}
  [coll]
  (nil? (seq coll)))

(defn not-empty
  "If coll is empty, returns nil, else coll."
  {:added "1.0"}
  [coll]
  (when (seq coll) coll))

(defn every?
  "Returns true if (pred x) is logical true for every x in coll, else false."
  {:added "1.0"}
  [pred coll]
  (loop [s (seq coll)]
    (if (nil? s)
      true
      (if (pred (first s))
        (recur (next s))
        false))))

(defn some
  "Returns the first logical true value of (pred x) for any x in coll,
   else nil."
  {:added "1.0"}
  [pred coll]
  (loop [s (seq coll)]
    (if s
      (let [v (pred (first s))]
        (if v v (recur (next s))))
      nil)))

(def cat
  (fn [rf]
    (let [rf1 (fn [result input]
                (let [ret (rf result input)]
                  (if (reduced? ret)
                    (reduced ret)
                    ret)))]
      (fn
        ([] (rf))
        ([result] (rf result))
        ([result input]
         (reduce rf1 result input))))))

(defn mapcat
  "Returns the result of applying concat to the result of applying map
  to f and colls. Thus function f should return a collection. Returns a
  transducer when no collection is provided."
  {:added "1.0"}
  ([f] (comp (map f) cat))
  ([f & colls] (apply concat (apply map f colls))))

(defn sequential?
  "Returns true if coll implements Sequential"
  {:added "1.0"
   :static true}
  [coll]
  (or (seq? coll) (vector? coll)))

(defn tree-seq
  "Returns a lazy sequence of the nodes in a tree, via a depth-first walk.
  branch? must be a fn of one arg that returns true if passed a node
  that can have children (but may not). children must be a fn of one arg
  that returns a sequence of the children. Will only be consumed as much
  as is needed."
  {:added "1.0"
   :static true}
  [branch? children root]
  (let [walk (fn walk [node]
               (lazy-seq
                 (cons node
                       (when (branch? node)
                         (mapcat walk (children node))))))]
    (walk root)))

(defn flatten
  "Takes any nested combination of sequential things (lists, vectors,
  etc.) and returns their contents as a single, flat lazy sequence.
  (flatten nil) returns an empty sequence."
  {:added "1.1"
   :static true}
  [x]
  (filter (complement sequential?)
          (rest (tree-seq sequential? seq x))))

(defn dorun
  "When lazy sequences are produced via functions that have side
  effects, any effects other than those needed to produce the first
  element in the seq do not occur until the seq is realized. dorun can
  be used to force any effects. Walks through the successive nexts of
  the seq, does not retain the head and returns nil."
  {:added "1.0"
   :static true}
  ([coll]
   (when (seq coll)
     (recur (next coll))))
  ([n coll]
   (when (and (seq coll) (pos? n))
     (recur (dec n) (next coll)))))

(defn doall
  "When lazy sequences are produced via functions that have side
  effects, any effects other than those needed to produce the first
  element in the seq do not occur until the seq is realized. doall can
  be used to force any effects. Walks through the successive nexts of
  the seq, retains the head and returns it, thus causing the entire
  seq to be realized. dorun can be used to realize a seq without
  retaining the head. Returns the seq."
  {:added "1.0"
   :static true}
  ([coll]
   (dorun coll) coll)
  ([n coll]
   (dorun n coll) coll))

(defn partition
  "Returns a lazy sequence of lists of n items each, at offsets step
  apart. If step is not supplied, defaults to n, i.e. the partitions
  do not overlap. If a pad collection is supplied, use its elements as
  necessary to complete last partition upto n items. In case there are
  not enough padding elements, return a partition with less than n items."
  {:added "1.0"
   :static true}
  ([n coll]
   (partition n n coll))
  ([n step coll]
   (lazy-seq
     (when-let [s (seq coll)]
       (let [p (doall (take n s))]
         (when (= n (count p))
           (cons p (partition n step (drop step s))))))))
  ([n step pad coll]
   (lazy-seq
     (when-let [s (seq coll)]
       (let [p (take n s)]
         (if (= n (count p))
           (cons p (partition n step pad (drop step s)))
           (list (take n (concat p pad)))))))))

(defn partition-all
  "Returns a lazy sequence of lists like partition, but may include
  partitions with fewer than n items at the end. Returns a stateful
  transducer when no collection is provided."
  {:added "1.2"
   :static true}
  ([n]
   (fn [rf]
     (let [a (volatile! [])]
       (fn
         ([] (rf))
         ([result]
          (let [result (if (not-empty @a)
                         (let [v @a]
                           (vreset! a [])
                           (rf result v))
                         result)]
            (rf result)))
         ([result input]
          (let [buf (vswap! a conj input)]
            (if (= n (count buf))
              (do (vreset! a []) (rf result buf))
              result)))))))
  ([n coll]
   (partition-all n n coll))
  ([n step coll]
   (lazy-seq
     (when-let [s (seq coll)]
       (let [seg (doall (take n s))]
         (cons seg (partition-all n step (drop step s))))))))

(defn group-by
  "Returns a map of the elements of coll keyed by the result of
  f on each element. The value at each key will be a vector of the
  corresponding elements, in the order they appeared in coll."
  {:added "1.2"
   :static true}
  [f coll]
  (persistent!
   (reduce
    (fn [ret x]
      (let [k (f x)]
        (assoc! ret k (conj (get ret k []) x))))
    (transient {})
    coll)))

(defn frequencies
  "Returns a map from distinct items in coll to the number of times
  they appear."
  {:added "1.2"
   :static true}
  [coll]
  (persistent!
   (reduce (fn [counts x]
             (assoc! counts x (inc (get counts x 0))))
           (transient {})
           coll)))

(defn sort-by
  "Returns a sorted sequence of the items in coll, where the sort
  order is determined by comparing (keyfn item). comp can be
  boolean-valued comparison function, or a -/0/+ valued comparator.
  Comp defaults to compare."
  {:added "1.0"
   :static true}
  ([keyfn coll]
   (sort-by keyfn compare coll))
  ([keyfn comp coll]
   (sort #(comp (keyfn %1) (keyfn %2)) coll)))

(defn distinct
  "Returns a lazy sequence of the elements of coll with duplicates
  removed. Returns a stateful transducer when no collection is provided."
  {:added "1.0"
   :static true}
  ([]
   (fn [rf]
     (let [seen (volatile! #{})]
       (fn
         ([] (rf))
         ([result] (rf result))
         ([result input]
          (if (contains? @seen input)
            result
            (do (vswap! seen conj input) (rf result input))))))))
  ([coll]
   (let [step (fn step [xs seen]
                (lazy-seq
                 ((fn [[f :as xs] seen]
                    (when (seq xs)
                      (if (contains? seen f)
                        (recur (rest xs) seen)
                        (cons f (step (rest xs) (conj seen f))))))
                  xs seen)))]
     (step coll #{}))))

(def dedupe-none :__dedupe-none__)

(defn dedupe
  "Returns a lazy sequence removing consecutive duplicates in coll.
  Returns a stateful transducer when no collection is provided."
  {:added "1.7"}
  ([]
   (fn [rf]
     (let [pv (volatile! dedupe-none)]
       (fn
         ([] (rf))
         ([result] (rf result))
         ([result input]
          (let [prior @pv]
            (vreset! pv input)
            (if (= prior input)
              result
              (rf result input))))))))
  ([coll]
   (lazy-seq
     (when-let [s (seq coll)]
       (let [f (first s)]
         (cons f (dedupe (drop-while #(= % f) (rest s)))))))))

(defn take-nth
  "Returns a lazy seq of every nth item in coll. Returns a stateful
  transducer when no collection is provided."
  {:added "1.0"}
  ([n]
   (fn [rf]
     (let [iv (volatile! -1)]
       (fn
         ([] (rf))
         ([result] (rf result))
         ([result input]
          (if (zero? (mod (vswap! iv inc) n))
            (rf result input)
            result))))))
  ([n coll]
   (lazy-seq
     (when-let [s (seq coll)]
       (cons (first s) (take-nth n (drop n s)))))))

(defn interleave
  "Returns a lazy seq of the first item in each coll, then the second etc."
  {:added "1.0"
   :static true}
  ([] ())
  ([c1] (lazy-seq (seq c1)))
  ([c1 c2]
   (lazy-seq
    (let [s1 (seq c1) s2 (seq c2)]
      (when (and s1 s2)
        (cons (first s1) (cons (first s2)
                               (interleave (rest s1) (rest s2))))))))
  ([c1 c2 & colls]
   (lazy-seq
    (let [ss (map seq (cons c1 (cons c2 colls)))]
      (when (every? identity ss)
        (concat (map first ss) (apply interleave (map rest ss))))))))

(defn interpose
  "Returns a lazy seq of the elements of coll separated by sep. Returns
  a stateful transducer when no collection is provided."
  {:added "1.0"
   :static true}
  ([sep]
   (fn [rf]
     (let [started (volatile! false)]
       (fn
         ([] (rf))
         ([result] (rf result))
         ([result input]
          (if @started
            (let [result (rf result sep)]
              (if (reduced? result)
                result
                (rf result input)))
            (do (vreset! started true) (rf result input))))))))
  ([sep coll]
   (lazy-seq
    (when-let [s (seq coll)]
      (cons (first s)
            (mapcat (fn [x] [sep x]) (rest s)))))))

(defn zipmap
  "Returns a map with the keys mapped to the corresponding vals."
  {:added "1.0"
   :static true}
  [keys vals]
  (loop [map {}
         ks (seq keys)
         vs (seq vals)]
    (if (and ks vs)
      (recur (assoc map (first ks) (first vs))
             (next ks)
             (next vs))
      map)))

(defn keep
  "Returns a lazy sequence of the non-nil results of (f item). Note,
  this means false return values are included. f must be free of
  side-effects. Returns a transducer when no collection is provided."
  {:added "1.2"
   :static true}
  ([f]
   (fn [rf]
     (fn
       ([] (rf))
       ([result] (rf result))
       ([result input]
        (let [v (f input)]
          (if (nil? v) result (rf result v)))))))
  ([f coll]
   (lazy-seq
    (when-let [s (seq coll)]
      (let [x (f (first s))]
        (if (nil? x)
          (keep f (rest s))
          (cons x (keep f (rest s)))))))))

(defn keep-indexed
  "Returns a lazy sequence of the non-nil results of (f index item). Note,
  this means false return values are included. f must be free of
  side-effects. Returns a stateful transducer when no collection is provided."
  {:added "1.2"
   :static true}
  ([f]
   (fn [rf]
     (let [iv (volatile! -1)]
       (fn
         ([] (rf))
         ([result] (rf result))
         ([result input]
          (let [v (f (vswap! iv inc) input)]
            (if (nil? v) result (rf result v))))))))
  ([f coll]
   (letfn [(keepi [idx coll]
             (lazy-seq
              (when-let [s (seq coll)]
                (let [x (f idx (first s))]
                  (if (nil? x)
                    (keepi (inc idx) (rest s))
                    (cons x (keepi (inc idx) (rest s))))))))]
     (keepi 0 coll))))

(defn map-indexed
  "Returns a lazy sequence consisting of the result of applying f to 0
  and the first item of coll, followed by applying f to 1 and the second
  item in coll, etc, until coll is exhausted. Thus function f should
  accept 2 arguments, index and item. Returns a stateful transducer
  when no collection is provided."
  {:added "1.2"
   :static true}
  ([f]
   (fn [rf]
     (let [iv (volatile! -1)]
       (fn
         ([] (rf))
         ([result] (rf result))
         ([result input]
          (rf result (f (vswap! iv inc) input)))))))
  ([f coll]
   (letfn [(mapi [idx coll]
             (lazy-seq
              (when-let [s (seq coll)]
                (cons (f idx (first s)) (mapi (inc idx) (rest s))))))]
     (mapi 0 coll))))

(defmacro doseq
  "Repeatedly executes body (presumably for side-effects) with
  bindings and filtering as provided by \"for\".  Does not retain
  the head of the sequence. Returns nil."
  {:added "1.0"}
  [seq-exprs & body]
  (assert-args
   (vector? seq-exprs) "a vector for its binding"
   (even? (count seq-exprs)) "an even number of forms in binding vector")
  (let [step (fn step [recform exprs]
               (if-not exprs
                 [true `(do ~@body)]
                 (let [k (first exprs)
                       v (second exprs)]
                   (if (keyword? k)
                     (let [steppair (step recform (nnext exprs))
                           needrec  (first steppair)
                           subform  (second steppair)]
                       (cond
                         (= k :let)
                         [needrec `(let ~v ~subform)]

                         (= k :while)
                         [false `(when ~v
                                   ~subform
                                   ~@(when needrec [recform]))]

                         (= k :when)
                         [false `(if ~v
                                    (do ~subform
                                        ~@(when needrec [recform]))
                                    ~recform)]))
                     (let [sq       (gensym "sq")
                           recform2 `(recur (next ~sq))
                           steppair (step recform2 (nnext exprs))
                           needrec  (first steppair)
                           subform  (second steppair)]
                       [true `(loop [~sq (seq ~v)]
                                (when ~sq
                                  (let [~k (first ~sq)]
                                    ~subform)
                                  ~@(when needrec [recform2])))])))))]
    (second (step nil (seq seq-exprs)))))

(defmacro for
  "List comprehension. Takes a vector of one or more
  binding-form/collection-expr pairs, each followed by zero or more
  modifiers, and yields a lazy sequence of evaluations of expr.
  Collections are iterated in a nested fashion, rightmost fastest,
  and nested coll-exprs can refer to bindings created in prior
  binding-forms.  Supported modifiers are: :let [binding-form expr ...],
  :while test, :when test."
  {:added "1.0"}
  [seq-exprs body-expr]
  (assert-args
   (vector? seq-exprs) "a vector for its binding"
   (even? (count seq-exprs)) "an even number of forms in binding vector")
  (let [to-groups (fn [seq-exprs]
                    (reduce (fn [groups pair]
                              (let [k (first pair)
                                    v (second pair)]
                                (if (keyword? k)
                                  (conj (pop groups) (conj (peek groups) [k v]))
                                  (conj groups [k v]))))
                            [] (partition 2 seq-exprs)))
        emit-bind (fn emit-bind [groups]
                    (let [group       (first groups)
                          bind        (first group)
                          expr        (second group)
                          mod-pairs   (next (next group))
                          next-groups (next groups)
                          next-expr   (when next-groups
                                        (second (first next-groups)))
                          giter (gensym "iter")
                          gxs   (gensym "s")
                          do-mod (fn do-mod [pairs]
                                   (if-not (seq pairs)
                                     (if next-groups
                                       (let [gnext (gensym "niter")
                                             gfs   (gensym "fs")]
                                         `(let [~gnext ~(emit-bind next-groups)
                                                ~gfs   (seq (~gnext ~next-expr))]
                                            (if ~gfs
                                              (concat ~gfs (~giter (rest ~gxs)))
                                              (recur (rest ~gxs)))))
                                       `(cons ~body-expr (~giter (rest ~gxs))))
                                     (let [pair (first pairs)
                                           k    (first pair)
                                           v    (second pair)
                                           etc  (rest pairs)]
                                       (cond
                                         (= k :let)   `(let ~v ~(do-mod etc))
                                         (= k :while) `(when ~v ~(do-mod etc))
                                         (= k :when)  `(if ~v
                                                          ~(do-mod etc)
                                                          (recur (rest ~gxs)))))))]
                      (if next-groups
                        `(fn ~giter [~gxs]
                           (lazy-seq
                             (loop [~gxs ~gxs]
                               (when-first [~bind ~gxs]
                                 ~(do-mod mod-pairs)))))
                        `(fn ~giter [~gxs]
                           (lazy-seq
                             (loop [~gxs ~gxs]
                               (when-let [~gxs (seq ~gxs)]
                                 (let [~bind (first ~gxs)]
                                   ~(do-mod mod-pairs)))))))))]
    `(let [iter# ~(emit-bind (to-groups seq-exprs))]
       (or (iter# ~(second seq-exprs)) (list)))))

(defn rand-int
  "Returns a random integer between 0 (inclusive) and n (exclusive)."
  {:added "1.0"}
  [n]
  (int (rand n)))
