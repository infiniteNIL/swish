(ns demo23)

(println)
(println "Reader conditionals")
(println "-------------------")
(println "#?(:jank 23 :swish 24) ->" #?(:jank 23 :swish 24))

(println)
(println "clojure.test")
(println "------------")

(println)
(println "int?")
(println "----")
(println "(int? 23) ->" (int? 23))
(println "(integer? 23) ->" (integer? 23))

(println)
(println "lazy-seq?")
(println "---------")
(println "(lazy-seq? [1 2 3] ->" (lazy-seq? [1 2 3]))
(println "(lazy-seq? (take 5 (range)) ->" (lazy-seq? (take 5 (range))))

(println)
(println "source paths")
(println "------------")

(println)
(println "BigInt/BigDecimal")
(println "-----------------")

(println)
(println "Radix Notation")
(println "--------------")

(println)
(println "Records")
(println "-------")
(println "(defrecord Point [x y]) ->" (defrecord Point [x y]))
(println "(def p (Point. 3 4) ->" (def p (Point. 3 4)))
(println "p ->" p)
(println "(:x p) ->" (:x p))
(println "(->Point 3 4) ->" (->Point 3 4))
(println "(map->Point {:x 3 :y 4}) ->" (map->Point {:x 3 :y 4}))

