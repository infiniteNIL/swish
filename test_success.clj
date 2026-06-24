(ns test-success
  (:require [clojure.test :refer [deftest is run-tests successful?]]))

(deftest all-pass
  (is (= 1 1))
  (is (= 1 2)))

;(ns user)
(let [summary (binding [clojure.test/*test-out* *out*]
                (run-tests 'test-success))]
  (successful? summary))

