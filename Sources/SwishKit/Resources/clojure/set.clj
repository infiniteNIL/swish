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

(defn difference
  "Return a set that is the first set without elements of the remaining sets."
  {:added "1.0"}
  ([s1] s1)
  ([s1 s2]
   (if (< (count s1) (* 2 (count s2)))
     (reduce (fn [result item]
               (if (contains? s2 item)
                 (disj result item)
                 result))
             s1 s1)
     (reduce disj s1 s2)))
  ([s1 s2 & sets]
   (reduce difference s1 (conj sets s2))))

(defn subset?
  "Is set1 a subset of set2?"
  {:added "1.2"}
  [set1 set2]
  (and (<= (count set1) (count set2))
       (every? #(contains? set2 %) set1)))

(defn superset?
  "Is set1 a superset of set2?"
  {:added "1.2"}
  [set1 set2]
  (and (>= (count set1) (count set2))
       (every? #(contains? set1 %) set2)))

