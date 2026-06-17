(do
  (ns test-success-ns)
  (require '[clojure.test :refer [deftest is run-tests successful?]])
  (deftest all-pass (is (= 1 1)))
  (ns user)
  (let [summary (binding [clojure.test/*test-out* *out*]
                  (clojure.test/run-tests 'test-success-ns))]
    (clojure.test/successful? summary)))

