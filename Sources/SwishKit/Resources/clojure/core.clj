(ns clojure.core)

(defmacro comment
  "Ignores body, yields nil"
  ;{:added "1.0"}
  [& body])

(defmacro defn [name & args]
  (let [has-doc (string? (first args))
        doc     (first args)
        params  (if has-doc (first (rest args)) (first args))
        body    (if has-doc (rest (rest args)) (rest args))]
    (if has-doc
      `(def ~(with-meta name {:doc doc}) (fn ~name ~params ~@body))
      `(def ~name (fn ~name ~params ~@body)))))

(defmacro defn-
  "same as defn, yielding non-public def"
  ;{:added "1.0"}
  [name & decls]
  (list* `defn (with-meta name (assoc (meta name) :private true)) decls))

(defn not
  "Returns true if x is logical false, false otherwise."
  ;{:tag Boolean
  ; :added "1.0"
  ; :static true}
  [x] (if x false true))

(defmacro when
  "Evaluates test. If logical true, evaluates body in an implicit do."
  ;{:added "1.0"}
  [test & body]
  (list 'if test (cons 'do body)))

(defmacro when-not
  "Evaluates test. If logical false, evaluates body in an implicit do."
  ;{:added "1.0"}
  [test & body]
  (list 'if test nil (cons 'do body)))
