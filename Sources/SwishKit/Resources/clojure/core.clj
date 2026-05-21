(ns clojure.core)

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

(defmacro defn [name & args]
  (let [has-doc  (string? (first args))
        doc      (if has-doc (first args) nil)
        args     (if has-doc (rest args) args)
        has-attr (map? (first args))
        attr     (if has-attr (first args) nil)
        args     (if has-attr (rest args) args)
        m        (merge (meta name) attr)
        m        (if doc (assoc (if m m {}) :doc doc) m)]
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

(defn second
  "Same as (first (next x))"
  {:added "1.0"}
  [x] (first (next x)))

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
  [x] (= x 0))

(defn pos?
  "Returns true if num is greater than zero, else false."
  {:added "1.0"}
  [x] (> x 0))

(defn neg?
  "Returns true if num is less than zero, else false."
  {:added "1.0"}
  [x] (< x 0))

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

(defn complement
  "Takes a fn f and returns a fn that takes the same arguments as f,
   has the same effects, if any, and returns the opposite truth value."
  {:added "1.0"}
  [f]
  (fn [& args] (not (apply f args))))

(defn into
  "Returns a new coll consisting of to-coll with all items of from-coll conjoined."
  {:added "1.0"}
  [to from]
  (reduce conj to from))

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

(defn mapcat
  "Returns the result of applying concat to the result of applying map
   to f and coll."
  {:added "1.0"}
  [f coll]
  (apply concat (map f coll)))
