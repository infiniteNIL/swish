(ns clojure.edn
  (:require [clojure.string :as str]))

(defn read-string
  ([s]
   (try (clojure.core/read-string s)
        (catch Exception e
          (if (str/includes? e "no forms found in string")
            nil
            (throw e)))))
  ([opts s]
   (edn-read-string* opts s)))
