import Testing
@testable import SwishKit

@Suite("Core Callable Tests", .serialized)
struct CoreCallableTests {
    nonisolated(unsafe) static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: Map as function

    @Test("map as fn: ({:a 1 :b 2} :a) → 1")
    func mapAsFnHit() throws {
        #expect(try swish.eval("({:a 1 :b 2} :a)") == .integer(1))
    }

    @Test("map as fn miss: ({:a 1 :b 2} :c) → nil")
    func mapAsFnMiss() throws {
        #expect(try swish.eval("({:a 1 :b 2} :c)") == .nil)
    }

    @Test("map as fn with not-found: ({:a 1} :c :missing) → :missing")
    func mapAsFnNotFound() throws {
        #expect(try swish.eval("({:a 1} :c :missing)") == .keyword("missing"))
    }

    @Test("apply map as fn: (apply {:a 1 :b 2} [:a]) → 1")
    func applyMapAsFn() throws {
        #expect(try swish.eval("(apply {:a 1 :b 2} [:a])") == .integer(1))
    }

    @Test("apply map as fn with not-found: (apply {:a 1} [:c :missing]) → :missing")
    func applyMapAsFnNotFound() throws {
        #expect(try swish.eval("(apply {:a 1} [:c :missing])") == .keyword("missing"))
    }

    // MARK: Keyword on set

    @Test("keyword on set hit: (:a #{:a :b :c}) → :a")
    func keywordOnSetHit() throws {
        #expect(try swish.eval("(:a #{:a :b :c})") == .keyword("a"))
    }

    @Test("keyword on set miss: (:d #{:a :b :c}) → nil")
    func keywordOnSetMiss() throws {
        #expect(try swish.eval("(:d #{:a :b :c})") == .nil)
    }

    @Test("apply keyword on set hit: (apply :a [#{:a :b :c}]) → :a")
    func applyKeywordOnSetHit() throws {
        #expect(try swish.eval("(apply :a [#{:a :b :c}])") == .keyword("a"))
    }

    @Test("apply keyword on set miss: (apply :d [#{:a :b :c}]) → nil")
    func applyKeywordOnSetMiss() throws {
        #expect(try swish.eval("(apply :d [#{:a :b :c}])") == .nil)
    }

    // MARK: Vector as function

    @Test("vector as fn: ([10 20 30] 1) → 20")
    func vectorAsFn() throws {
        #expect(try swish.eval("([10 20 30] 1)") == .integer(20))
    }

    @Test("apply vector as fn: (apply [10 20 30] [1]) → 20")
    func applyVectorAsFn() throws {
        #expect(try swish.eval("(apply [10 20 30] [1])") == .integer(20))
    }

    // MARK: Set as function

    @Test("set as fn hit: (#{:a :b :c} :a) → :a")
    func setAsFnHit() throws {
        #expect(try swish.eval("(#{:a :b :c} :a)") == .keyword("a"))
    }

    @Test("set as fn miss: (#{:a :b :c} :d) → nil")
    func setAsFnMiss() throws {
        #expect(try swish.eval("(#{:a :b :c} :d)") == .nil)
    }

    @Test("apply set as fn hit: (apply #{:a :b :c} [:a]) → :a")
    func applySetAsFnHit() throws {
        #expect(try swish.eval("(apply #{:a :b :c} [:a])") == .keyword("a"))
    }
}
