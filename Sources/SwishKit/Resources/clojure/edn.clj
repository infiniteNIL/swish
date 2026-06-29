(ns clojure.edn)

(defn read-string
  ([s]
   (clojure.core/read-string s))
  ([opts s]
   (if (clojure.string/blank? s)
     (get opts :eof nil)
     (clojure.core/read-string s))))
