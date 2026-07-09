(ns clojure.edn
  (:require [clojure.string :as str]))

(defn read-string
  ([s]
   (edn-read-string* {} s))
  ([opts s]
   (edn-read-string* opts s)))
