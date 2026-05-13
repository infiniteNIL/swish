(ns clojure.core)

(defmacro comment
  "Ignores body, yields nil"
  ;{:added "1.0"}
  [& body])

(defmacro defn [name params & body]
  `(def ~name (fn ~name ~params ~@body)))
