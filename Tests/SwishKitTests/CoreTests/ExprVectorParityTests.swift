import Testing
@testable import SwishKit

/// The three vector-shaped `Expr` representations must be interchangeable.
///
/// `Expr` treats `.vector` (a `SwishPersistentVector` trie), `.sharedVector` (a real
/// `[Expr]` over a `SwishArray`) and a 2-element `.mapEntry` as cross-`==`, and
/// `Expr+Hashable.swift` hashes all three under one discriminator. `Hashable`'s contract
/// then requires their hashes to agree — if they drift, a vector stops finding itself as
/// a map key or set element depending on which representation built it.
///
/// This is load-bearing for `SwishPersistentVector.hash(into:)`, which reproduces
/// `Array<Expr>.hash(into:)` by hand (count, then each element in order) so it can iterate
/// leaves instead of materializing the trie. That hand-restatement is only safe because
/// these tests fail the moment it stops matching.
@Suite("Expr Vector Representation Parity Tests", .serialized)
struct ExprVectorParityTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    private func trieVector(_ n: Int) -> Expr {
        .vector(SwishPersistentVector((0..<n).map { .integer($0) }), metadata: nil)
    }

    private func arrayVector(_ n: Int) -> Expr {
        .sharedVector(SwishArray((0..<n).map { .integer($0) }), metadata: nil)
    }

    /// Sizes spanning the 32-element tail boundary, where the trie starts having levels.
    private static let sizes = [0, 1, 31, 32, 33, 63, 64, 65, 1024, 1025]

    @Test("A trie vector and an array-backed vector of equal contents are == and hash equal",
          arguments: sizes)
    func vectorAndSharedVectorParity(_ n: Int) throws {
        let trie = trieVector(n)
        let shared = arrayVector(n)
        #expect(trie == shared)
        #expect(shared == trie)
        #expect(trie.hashValue == shared.hashValue)
    }

    @Test("A 2-element mapEntry is == and hash-equal to the same 2-element vector")
    func mapEntryParity() throws {
        let entry = Expr.mapEntry(.keyword("k"), .integer(7))
        let trie = Expr.vector(SwishPersistentVector([.keyword("k"), .integer(7)]), metadata: nil)
        let shared = Expr.sharedVector(SwishArray([.keyword("k"), .integer(7)]), metadata: nil)
        #expect(entry == trie)
        #expect(entry == shared)
        #expect(entry.hashValue == trie.hashValue)
        #expect(entry.hashValue == shared.hashValue)
    }

    @Test("Differing contents of the same length are unequal", arguments: [1, 32, 33, 1025])
    func differingContents(_ n: Int) throws {
        var other = (0..<n).map { Expr.integer($0) }
        other[n - 1] = .integer(-1)
        #expect(trieVector(n) != .vector(SwishPersistentVector(other), metadata: nil))
        #expect(trieVector(n) != .sharedVector(SwishArray(other), metadata: nil))
    }

    @Test("Different lengths are unequal even when one is a prefix of the other")
    func differingLengths() throws {
        #expect(trieVector(32) != trieVector(33))
        #expect(trieVector(1024) != trieVector(1025))
    }

    /// `=` must be transitive across all three. It wasn't: `.mapEntry` had a cross-`==`
    /// arm for `.vector` but not for `.sharedVector`, so an entry equalled a vector
    /// literal, that literal equalled the array-backed vector, and the entry did not
    /// equal the array-backed one.
    @Test("Equality is transitive across mapEntry, vector and sharedVector")
    func equalityIsTransitive() throws {
        let entry = Expr.mapEntry(.keyword("k"), .integer(7))
        let trie = Expr.vector(SwishPersistentVector([.keyword("k"), .integer(7)]), metadata: nil)
        let shared = Expr.sharedVector(SwishArray([.keyword("k"), .integer(7)]), metadata: nil)
        #expect(entry == trie)
        #expect(trie == shared)
        #expect(entry == shared)
        #expect(shared == entry)
    }

    @Test("Transitivity holds for the values ordinary Swish code produces")
    func equalityIsTransitiveInUserCode() throws {
        #expect(try swish.eval("(= (first (seq {:k 7})) [:k 7])") == .boolean(true))
        #expect(try swish.eval("(= [:k 7] (vec (object-array [:k 7])))") == .boolean(true))
        #expect(try swish.eval("(= (first (seq {:k 7})) (vec (object-array [:k 7])))") == .boolean(true))
    }

    @Test("A mapEntry is still unequal to a vector of the wrong length or contents")
    func mapEntryNonMatches() throws {
        let entry = Expr.mapEntry(.keyword("k"), .integer(7))
        #expect(entry != .sharedVector(SwishArray([.keyword("k")]), metadata: nil))
        #expect(entry != .sharedVector(SwishArray([.keyword("k"), .integer(7), .integer(9)]), metadata: nil))
        #expect(entry != .sharedVector(SwishArray([.keyword("k"), .integer(9)]), metadata: nil))
        #expect(entry != .vector(SwishPersistentVector([.keyword("k")]), metadata: nil))
    }

    // MARK: - The invariant as user code sees it

    @Test("A map keyed by a vector is found by the other representation")
    func vectorMapKeyLookupAcrossRepresentations() throws {
        // `(vec (object-array …))` produces `.sharedVector`; a literal produces `.vector`.
        #expect(try swish.eval("(get {[0 1 2] :found} (vec (object-array [0 1 2])))") == .keyword("found"))
        #expect(try swish.eval("(contains? #{[0 1 2]} (vec (object-array [0 1 2])))") == .boolean(true))
    }

    @Test("A map entry from seq'ing a map is a usable vector key")
    func mapEntryAsKey() throws {
        #expect(try swish.eval("(get {[:k 7] :found} (first (seq {:k 7})))") == .keyword("found"))
    }

    @Test("Set/map identity holds for a vector large enough to have trie levels")
    func largeVectorKeyIdentity() throws {
        #expect(try swish.eval("(= (vec (range 100)) (vec (object-array (range 100))))") == .boolean(true))
        #expect(try swish.eval("(count (set [(vec (range 100)) (vec (range 100))]))") == .integer(1))
        #expect(try swish.eval("(get {(vec (range 100)) :found} (vec (range 100)))") == .keyword("found"))
    }
}
