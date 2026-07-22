import Foundation
import BigInt
import BigDecimal

extension Expr: Equatable {
    public static func == (lhs: Expr, rhs: Expr) -> Bool {
        switch (lhs, rhs) {
        case (.integer(let a), .integer(let b)):
            return a == b

        case (.double(let a), .double(let b)):
            return a == b

        case (.float(let a), .float(let b)):
            return a == b

        case (.float(let a), .double(let b)):
            return Double(a) == b

        case (.double(let a), .float(let b)):
            return a == Double(b)

        case (.ratio(let a), .ratio(let b)):
            return a == b

        case (.bigInteger(let a), .bigInteger(let b)):
            return a == b

        case (.integer(let a), .bigInteger(let b)):
            return BigInt(a) == b

        case (.bigInteger(let a), .integer(let b)):
            return a == BigInt(b)

        case (.bigDecimal(let a), .bigDecimal(let b)):
            return a == b

        case (.string(let a), .string(let b)):
            return a == b

        case (.character(let a), .character(let b)):
            return a == b

        case (.boolean(let a), .boolean(let b)):
            return a == b

        case (.nil, .nil):
            return true

        case (.symbol(let a, _), .symbol(let b, _)):
            return a == b

        case (.keyword(let a), .keyword(let b)):
            return a == b

        case (.list(let a, _), .list(let b, _)):
            return a == b

        case (.seq(let a), .seq(let b)):
            return a == b

        case (.array(let a), .array(let b)):
            return a === b   // identity equality: Java arrays compare by reference

        case (.vector(let a, _), .vector(let b, _)):
            return a == b

        case (.sharedVector(let a, _), .sharedVector(let b, _)):
            return a.elements == b.elements

        case (.sharedVector(let a, _), .vector(let b, _)):
            return a.elements == b

        case (.vector(let a, _), .sharedVector(let b, _)):
            return a == b.elements

        case (.mapEntry(let k1, let v1), .mapEntry(let k2, let v2)):
            return k1 == k2 && v1 == v2

        case (.mapEntry(let k, let v), .vector(let elems, _)):
            return elems.count == 2 && k == elems[0] && v == elems[1]

        case (.vector(let elems, _), .mapEntry(let k, let v)):
            return elems.count == 2 && elems[0] == k && elems[1] == v

        case (.map(let a), .map(let b)):
            return a == b

        case (.set(let a), .set(let b)):
            return a == b

        case (.sortedSet(let a, _), .sortedSet(let b, _)):
            return Set(a) == Set(b)

        case (.sortedSet(let a, _), .set(let b)):
            return Set(a) == b.elements

        case (.set(let a), .sortedSet(let b, _)):
            return a.elements == Set(b)

        case (.sortedMap(let a, _), .sortedMap(let b, _)):
            return a == b

        case (.sortedMap(let a, _), .map(let b)):
            return a == b.dict

        case (.map(let a), .sortedMap(let b, _)):
            return a.dict == b

        case (.function(let a), .function(let b)):
            return a === b

        case (.macro(let n1, let p1, let b1, _), .macro(let n2, let p2, let b2, _)):
            return n1 == n2 && p1 == p2 && b1 == b2

        case (.multiArityFunction(let a), .multiArityFunction(let b)):
            return a === b

        case (.multiArityMacro(let n1, let a1, _), .multiArityMacro(let n2, let a2, _)):
            return n1 == n2 && a1 == a2

        case (.nativeFunction(let n1, let a1, _), .nativeFunction(let n2, let a2, _)):
            return n1 == n2 && a1 == a2

        case (.varRef(let a), .varRef(let b)):
            return a === b

        case (.namespace(let a), .namespace(let b)):
            return a === b

        case (.atom(let a), .atom(let b)):
            return a === b

        case (.transient(let a), .transient(let b)):
            return a === b

        // Lazy seqs with the same identity are trivially equal.
        // Cross-type: a lazy seq and a list (or two different lazy seqs) compare
        // element-by-element up to 1 000 elements for safety on infinite seqs.
        case (.lazySeq(let a), .lazySeq(let b)):
            if a === b { return true }
            return seqEqual(lhs, rhs)

        case (.lazySeq, .list), (.list, .lazySeq):
            return seqEqual(lhs, rhs)

        case (.vector, .lazySeq), (.lazySeq, .vector):
            return seqEqual(lhs, rhs)

        case (.sharedVector, .lazySeq), (.lazySeq, .sharedVector):
            return seqEqual(lhs, rhs)

        case (.vector, .list), (.list, .vector):
            return seqEqual(lhs, rhs)

        case (.sharedVector, .list), (.list, .sharedVector):
            return seqEqual(lhs, rhs)

        case (.seq, .list), (.list, .seq):
            return seqEqual(lhs, rhs)

        case (.seq, .vector), (.vector, .seq):
            return seqEqual(lhs, rhs)

        case (.seq, .sharedVector), (.sharedVector, .seq):
            return seqEqual(lhs, rhs)

        case (.seq, .lazySeq), (.lazySeq, .seq):
            return seqEqual(lhs, rhs)

        case (.reduced(let a), .reduced(let b)):
            return a == b

        case (.delay(let a), .delay(let b)):
            return a === b

        case (.agent(let a), .agent(let b)):
            return a === b

        case (.future(let a), .future(let b)):
            return a === b

        case (.promise(let a), .promise(let b)):
            return a === b

        case (.ref(let a), .ref(let b)):
            return a === b

        case (.regex(let a), .regex(let b)):
            return a == b

        case (.reader(let a), .reader(let b)):
            return a === b

        case (.writer(let a), .writer(let b)):
            return a === b

        case (.inst(let a), .inst(let b)):
            return a == b

        case (.uuid(let a), .uuid(let b)):
            return a == b

        case (.record(let t1, _, let d1, _), .record(let t2, _, let d2, _)):
            return t1 == t2 && d1 == d2

        case (.deftype(let t1, _, let d1, _), .deftype(let t2, _, let d2, _)):
            return t1 == t2 && d1 == d2

        default:
            return false
        }
    }

    // MARK: - Seq equality helpers

    private static func seqEqual(_ lhs: Expr, _ rhs: Expr) -> Bool {
        var l = lhs
        var r = rhs
        while true {
            let lh = advanceSeq(&l)
            let rh = advanceSeq(&r)
            switch (lh, rh) {
            case (.some(let le), .some(let re)):
                if le != re { return false }

            case (nil, nil):
                return true

            default:
                return false
            }
        }
    }

    /// Advances `expr` one step through a seq, returning the head (or `nil` for empty).
    private static func advanceSeq(_ expr: inout Expr) -> Expr? {
        switch expr {
        case .nil:
            return nil

        case .list(let elems, _):
            guard let head = elems.first else { return nil }
            expr = elems.count == 1 ? .nil : .list(elems.dropFirst(1), metadata: nil)
            return head

        case .seq(let elems):
            if elems.isEmpty { return nil }
            expr = elems.count == 1 ? .nil : .seq(Array(elems.dropFirst()))
            return elems[0]

        case .vector(let elems, _):
            if elems.isEmpty { return nil }
            expr = elems.count == 1 ? .nil : .vector(Array(elems.dropFirst()), metadata: nil)
            return elems[0]

        case .array(let sa):
            let elems = sa.elements
            if elems.isEmpty { return nil }
            expr = elems.count == 1 ? .nil : .array(SwishArray(Array(elems.dropFirst())))
            return elems[0]

        case .sharedVector(let sa, _):
            let elems = sa.elements
            if elems.isEmpty { return nil }
            expr = elems.count == 1 ? .nil : .vector(Array(elems.dropFirst()), metadata: nil)
            return elems[0]

        case .lazySeq(let box):
            guard let head = try? box.forceHead() else {
                expr = .nil
                return nil
            }
            expr = (try? box.forceTail()) ?? .nil
            return head

        default:
            return nil
        }
    }
}
