(ns clojure.set)

(defn union
  "Return a set that is the union of the input sets."
  {:added "1.0"}
  ([] #{})
  ([s1] s1)
  ([s1 s2]
   (if (< (count s1) (count s2))
     (reduce conj s2 s1)
     (reduce conj s1 s2)))
  ([s1 s2 & sets]
   (reduce union (union s1 s2) sets)))

(defn intersection
  "Return a set that is the intersection of the input sets."
  {:added "1.0"}
  ([s1] s1)
  ([s1 s2]
   (if (< (count s2) (count s1))
     (recur s2 s1)
     (reduce (fn [result item]
               (if (contains? s2 item)
                 result
                 (disj result item)))
             s1 s1)))
  ([s1 s2 & sets]
   (let [bubbled-sets (sort-by count (conj sets s2 s1))]
     (reduce intersection (first bubbled-sets) (rest bubbled-sets)))))

