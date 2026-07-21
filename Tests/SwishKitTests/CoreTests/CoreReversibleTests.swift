import Testing
@testable import SwishKit

@Suite("Core reversible? Tests", .serialized)
struct CoreReversibleTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    // MARK: - true for vectors and sorted collections

    @Test("reversible? is true for vectors")
    func reversibleTrueForVector() throws {
        #expect(try swish.eval("(reversible? [1 2 3])") == .boolean(true))
    }

    @Test("reversible? is true for sorted-map")
    func reversibleTrueForSortedMap() throws {
        #expect(try swish.eval("(reversible? (sorted-map :a 1))") == .boolean(true))
    }

    @Test("reversible? is true for sorted-set")
    func reversibleTrueForSortedSet() throws {
        #expect(try swish.eval("(reversible? (sorted-set :a))") == .boolean(true))
    }

    // MARK: - false for everything else

    @Test("reversible? is false for lists and lazy seqs")
    func reversibleFalseForListsAndLazySeqs() throws {
        #expect(try swish.eval("(reversible? '(1 2 3))") == .boolean(false))
        #expect(try swish.eval("(reversible? (range 0 10))") == .boolean(false))
        #expect(try swish.eval("(reversible? (range))") == .boolean(false))
    }

    @Test("reversible? is false for hash-map, hash-set, and array-map")
    func reversibleFalseForUnorderedCollections() throws {
        #expect(try swish.eval("(reversible? (hash-map :a 1))") == .boolean(false))
        #expect(try swish.eval("(reversible? (hash-set :a))") == .boolean(false))
        #expect(try swish.eval("(reversible? (array-map :a 1))") == .boolean(false))
    }

    @Test("reversible? is false for a seq'd vector, sorted-map, or sorted-set")
    func reversibleFalseForSeqdCollections() throws {
        // Only the collection itself is Reversible, not a seq view over it.
        #expect(try swish.eval("(reversible? (seq [1 2 3]))") == .boolean(false))
        #expect(try swish.eval("(reversible? (seq (sorted-map :a 1)))") == .boolean(false))
        #expect(try swish.eval("(reversible? (seq (sorted-set :a)))") == .boolean(false))
    }

    @Test("reversible? is false for scalars, keywords, symbols, strings, and chars")
    func reversibleFalseForScalars() throws {
        #expect(try swish.eval("(reversible? nil)") == .boolean(false))
        #expect(try swish.eval("(reversible? 1)") == .boolean(false))
        #expect(try swish.eval("(reversible? 1N)") == .boolean(false))
        #expect(try swish.eval("(reversible? 1.0)") == .boolean(false))
        #expect(try swish.eval("(reversible? 1.0M)") == .boolean(false))
        #expect(try swish.eval("(reversible? :a-keyword)") == .boolean(false))
        #expect(try swish.eval("(reversible? 'a-sym)") == .boolean(false))
        #expect(try swish.eval(#"(reversible? "a string")"#) == .boolean(false))
        #expect(try swish.eval(#"(reversible? \a)"#) == .boolean(false))
    }

    @Test("reversible? is false for arrays")
    func reversibleFalseForArray() throws {
        #expect(try swish.eval("(reversible? (object-array 3))") == .boolean(false))
    }
}
