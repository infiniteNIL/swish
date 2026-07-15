(ns concurrency)

;; A tour of Swish's concurrency support: atoms, futures, promises, agents,
;; refs/STM, and bound-fn. Run with: swift run swish concurrency.clj

(println)
(println "Atoms — synchronized, uncoordinated state")
(println "------------------------------------------")
(def counter (atom 0))
(println "(def counter (atom 0)) ->" counter)
(add-watch counter :logger
  (fn [key ref old new] (println "  watch fired:" old "->" new)))
(println "(swap! counter inc) ->" (swap! counter inc))
(println "(swap! counter + 10) ->" (swap! counter + 10))
(println "@counter ->" @counter)
(remove-watch counter :logger)

(println)
(println "Futures — background computation")
(println "----------------------------------")
(def f (future
         (println "  [future thread] computing...")
         (sleep! 100)
         (+ 1 2 3 4 5)))
(println "(future? f) ->" (future? f))
(println "(realized? f) right after creation ->" (realized? f))
(println "@f (blocks until the future finishes) ->" @f)
(println "(realized? f) now ->" (realized? f))

(def slow-future (future (sleep! 10000) :never-gets-here))
(println "(future-cancel slow-future) ->" (future-cancel slow-future))
(println "(future-cancelled? slow-future) ->" (future-cancelled? slow-future))

(println)
(println "Promises — single-slot handoff between threads")
(println "-------------------------------------------------")
(def answer (promise))
(future
  (sleep! 50)
  (println "  [future thread] delivering...")
  (deliver answer 42))
(println "@answer (blocks until delivered) ->" @answer)

(println)
(println "Agents — asynchronous, serialized state changes")
(println "---------------------------------------------------")
(def total (agent 0))
(doseq [i (range 5)] (send total + i))
(await total)
(println "after sending (+ 0) (+ 1) ... (+ 4): @total ->" @total)

(println)
(println "  Validators and restart-agent")
(def guarded (agent 1 :validator pos?))
(send guarded (fn [x] (- x 10)))
(await guarded)
(println "  send that would go non-positive fails the agent")
(println "  (agent-error guarded) ->" (agent-error guarded))
(restart-agent guarded 1)
(println "  (restart-agent guarded 1) -> agent-error now ->" (pr-str (agent-error guarded)))

(println)
(println "  error-handler + :continue mode")
(def resilient (agent 0))
(set-error-handler! resilient (fn [ag ex] (println "  handler saw exception:" ex)))
(println "  (error-mode resilient) defaults to :continue once a handler is set ->" (error-mode resilient))
(send resilient (fn [_] (throw "boom")))
(send resilient inc)
(await resilient)
(println "  :continue mode swallows the error and keeps processing; @resilient ->" @resilient)

(println)
(println "Refs and STM — coordinated, synchronous state")
(println "---------------------------------------------------")
(def checking (ref 100))
(def savings (ref 100))

(defn transfer [from to amount]
  (dosync
    (alter from - amount)
    (alter to + amount)))

(transfer checking savings 30)
(println "(transfer checking savings 30) -> [@checking @savings] ->" [@checking @savings])

(def hits (ref 0))
(dosync (commute hits inc) (commute hits inc))
(println "(dosync (commute hits inc) (commute hits inc)) -> @hits ->" @hits)

(println "(dosync (ensure checking)) ->" (dosync (ensure checking)))

(println)
(println "  Concurrent transfers — dosync keeps the total consistent under contention")
(def acct-a (ref 500))
(def acct-b (ref 500))
(defn move [amount] (dosync (alter acct-a - amount) (alter acct-b + amount)))
(def transfers (doall (for [i (range 20)] (future (move 5)))))
(doseq [t transfers] @t)
(println "  20 concurrent $5 transfers a->b later: [@acct-a @acct-b] ->" [@acct-a @acct-b])
(println "  total (should still be 1000) ->" (+ @acct-a @acct-b))

(println)
(println "bound-fn — carrying dynamic bindings across threads")
(println "--------------------------------------------------------")
(def ^:dynamic *user* "guest")
(def whoami
  (binding [*user* "alice"]
    (bound-fn [] *user*)))
(println "whoami captured *user* = \"alice\" at creation time")
(println "(binding [*user* \"bob\"] @(future (whoami))) ->"
  (binding [*user* "bob"] @(future (whoami))))

(println)
(println "Done.")
