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
