(ns clojure.string)

(defn join
  "Returns a string of all elements in coll, as returned by (seq coll),
   separated by an optional separator."
  ([coll]
   (apply str coll))
  ([sep coll]
   (loop [result "" more (seq coll) sep2 ""]
     (if more
       (recur (str result sep2 (str (first more)))
              (next more)
              sep)
       result))))
