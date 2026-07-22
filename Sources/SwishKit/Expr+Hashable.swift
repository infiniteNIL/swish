import Foundation
import BigInt
import BigDecimal

// MARK: - Hash discriminants

/// Named type discriminants for Expr.hash(into:).
/// Sorted/unsorted variants that are value-equal share the same discriminant
/// so their hashes are compatible (required by Swift's Hashable contract).
private enum ExprHash {
    static let integer            = 0
    static let float              = 1
    static let ratio              = 2
    static let string             = 3
    static let character          = 4
    static let boolean            = 5
    static let `nil`              = 6
    static let symbol             = 7
    static let keyword            = 8
    static let list               = 9  // .seq shares this discriminant for cross-type equality
    static let vector             = 10  // mapEntry shares this for cross-type equality
    static let map                = 11  // sortedMap shares this for cross-type equality
    static let set                = 12  // sortedSet shares this for cross-type equality
    static let function           = 13
    static let macro              = 14
    static let multiArityFunction = 15
    static let multiArityMacro    = 16
    static let nativeFunction     = 17
    static let varRef             = 18
    static let namespace          = 19
    static let atom               = 20
    static let transient          = 21
    static let lazySeq            = 22
    static let reduced            = 23
    static let regex              = 24
    static let reader             = 25
    static let writer             = 26
    static let bigInteger         = 27
    static let bigDecimal         = 28
    static let record             = 29
    static let inst               = 30
    static let uuid               = 31
    static let delay              = 32
    static let array              = 33
    static let agent              = 34
    static let future              = 35
    static let promise             = 36
    static let ref                 = 37
    static let deftype             = 38
}

extension Expr: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch self {
        case .integer(let v):
            hasher.combine(ExprHash.integer);   hasher.combine(BigInt(v))

        case .double(let v):
            hasher.combine(ExprHash.float);     hasher.combine(v)

        case .float(let v):
            hasher.combine(ExprHash.float);     hasher.combine(Double(v))

        case .ratio(let v):
            hasher.combine(ExprHash.ratio);     hasher.combine(v)

        case .string(let v):
            hasher.combine(ExprHash.string);    hasher.combine(v)

        case .character(let v):
            hasher.combine(ExprHash.character); hasher.combine(v)

        case .boolean(let v):
            hasher.combine(ExprHash.boolean);   hasher.combine(v)

        case .nil:
            hasher.combine(ExprHash.nil)

        case .symbol(let v, _):
            hasher.combine(ExprHash.symbol);    hasher.combine(v)

        case .keyword(let v):
            hasher.combine(ExprHash.keyword);   hasher.combine(v)

        case .list(let v, _):
            hasher.combine(ExprHash.list);      hasher.combine(v)

        case .seq(let v):
            hasher.combine(ExprHash.list);      hasher.combine(v)

        case .array(let sa):
            hasher.combine(ExprHash.array);     hasher.combine(ObjectIdentifier(sa))

        case .vector(let v, _):
            hasher.combine(ExprHash.vector);    hasher.combine(v)

        case .sharedVector(let sa, _):
            hasher.combine(ExprHash.vector);    hasher.combine(sa.elements)

        case .mapEntry(let k, let v):
            hasher.combine(ExprHash.vector);    hasher.combine([k, v])

        case .map(let sm):
            hasher.combine(ExprHash.map);       hasher.combine(sm)

        case .sortedMap(let v, _):
            hasher.combine(ExprHash.map);       hasher.combine(v)

        case .set(let s):
            hasher.combine(ExprHash.set);       hasher.combine(s)

        case .sortedSet(let v, _):
            hasher.combine(ExprHash.set);       hasher.combine(Set(v))

        case .function(let f):
            hasher.combine(ExprHash.function);          hasher.combine(ObjectIdentifier(f))

        case .macro(let n, let p, let b, _):
            hasher.combine(ExprHash.macro);             hasher.combine(n); hasher.combine(p); hasher.combine(b)

        case .multiArityFunction(let maf):
            hasher.combine(ExprHash.multiArityFunction); hasher.combine(ObjectIdentifier(maf))

        case .multiArityMacro(let n, let a, _):
            hasher.combine(ExprHash.multiArityMacro);    hasher.combine(n); hasher.combine(a)

        case .nativeFunction(let n, let a, _):
            hasher.combine(ExprHash.nativeFunction);     hasher.combine(n); hasher.combine(a)

        case .varRef(let v):
            hasher.combine(ExprHash.varRef);    hasher.combine(ObjectIdentifier(v))

        case .namespace(let v):
            hasher.combine(ExprHash.namespace); hasher.combine(ObjectIdentifier(v))

        case .atom(let v):
            hasher.combine(ExprHash.atom);      hasher.combine(ObjectIdentifier(v))

        case .transient(let v):
            hasher.combine(ExprHash.transient); hasher.combine(ObjectIdentifier(v))

        // Identity hash. Lazy seqs can be == to lists via element comparison but
        // the hash contract is maintained within the lazy-seq type (same box → same hash).
        case .lazySeq(let box):
            hasher.combine(ExprHash.lazySeq);   hasher.combine(ObjectIdentifier(box))

        case .reduced(let v):
            hasher.combine(ExprHash.reduced);   hasher.combine(v)

        case .delay(let v):
            hasher.combine(ExprHash.delay);     hasher.combine(ObjectIdentifier(v))

        case .agent(let v):
            hasher.combine(ExprHash.agent);     hasher.combine(ObjectIdentifier(v))

        case .future(let v):
            hasher.combine(ExprHash.future);    hasher.combine(ObjectIdentifier(v))

        case .promise(let v):
            hasher.combine(ExprHash.promise);   hasher.combine(ObjectIdentifier(v))

        case .ref(let v):
            hasher.combine(ExprHash.ref);       hasher.combine(ObjectIdentifier(v))

        case .regex(let v):
            hasher.combine(ExprHash.regex);     hasher.combine(v)

        case .reader(let v):
            hasher.combine(ExprHash.reader);    hasher.combine(ObjectIdentifier(v))

        case .writer(let v):
            hasher.combine(ExprHash.writer);    hasher.combine(ObjectIdentifier(v))

        case .bigInteger(let v):
            if let i = Int(exactly: v) {
                hasher.combine(ExprHash.integer); hasher.combine(BigInt(i))
            } else {
                hasher.combine(ExprHash.bigInteger); hasher.combine(v)
            }

        case .bigDecimal(let v):
            hasher.combine(ExprHash.bigDecimal); hasher.combine(v)

        case .inst(let v):
            hasher.combine(ExprHash.inst);      hasher.combine(v)

        case .uuid(let v):
            hasher.combine(ExprHash.uuid);      hasher.combine(v)

        case .record(let t, _, let d, _):
            hasher.combine(ExprHash.record);    hasher.combine(t); hasher.combine(d)

        case .deftype(let t, _, let d, _):
            hasher.combine(ExprHash.deftype);   hasher.combine(t); hasher.combine(d)
        }
    }
}
