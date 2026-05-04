(ns clojure.core)

(defmacro defn [name params & body]
  `(def ~name (fn ~name ~params ~@body)))
