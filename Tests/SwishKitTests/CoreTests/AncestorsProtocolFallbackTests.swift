import Testing
@testable import SwishKit

@Suite("ancestors/parents Protocol Fallback Tests", .serialized)
struct AncestorsProtocolFallbackTests {
    static let _shared = Swish()
    var swish: Swish { Self._shared }

    @Test("ancestors includes a protocol declared inline on a defrecord")
    func ancestorsIncludesInlineRecordProtocol() throws {
        #expect(
            try swish.eval("""
                (do
                  (defprotocol APFProto1)
                  (defrecord APFRec1 [] APFProto1)
                  (contains? (ancestors APFRec1) (:name APFProto1)))
                """) == .boolean(true))
    }

    @Test("ancestors includes a protocol declared inline on a deftype")
    func ancestorsIncludesInlineTypeProtocol() throws {
        #expect(
            try swish.eval("""
                (do
                  (defprotocol APFProto2)
                  (deftype APFType2 [] APFProto2)
                  (contains? (ancestors APFType2) (:name APFProto2)))
                """) == .boolean(true))
    }

    @Test("ancestors includes a protocol added retroactively via extend-type")
    func ancestorsIncludesRetroactiveProtocol() throws {
        #expect(
            try swish.eval("""
                (do
                  (defprotocol APFProto3 (apf-method3 [this]))
                  (defrecord APFRec3 [])
                  (extend-type APFRec3 APFProto3 (apf-method3 [this] :ok))
                  (contains? (ancestors APFRec3) (:name APFProto3)))
                """) == .boolean(true))
    }

    @Test("parents also includes a type's declared protocol, not just ancestors")
    func parentsIncludesProtocol() throws {
        #expect(
            try swish.eval("""
                (do
                  (defprotocol APFProto4)
                  (defrecord APFRec4 [] APFProto4)
                  (contains? (parents APFRec4) (:name APFProto4)))
                """) == .boolean(true))
    }

    @Test("a protocol's own ancestors and parents are nil")
    func protocolHasNoAncestorsOrParents() throws {
        #expect(
            try swish.eval("""
                (do
                  (defprotocol APFProto5)
                  [(ancestors APFProto5) (parents APFProto5)])
                """) == .vector([.nil, .nil], metadata: nil))
    }

    @Test("an unrelated derive-based hierarchy is unaffected by the protocol scan")
    func unrelatedDeriveHierarchyUnaffected() throws {
        #expect(
            try swish.eval("""
                (do
                  (derive ::apf-child ::apf-parent)
                  (ancestors ::apf-child))
                """) == .set([.keyword("user/apf-parent")], metadata: nil))
    }

    @Test("a type implementing multiple protocols has all of them in ancestors")
    func multipleProtocolsAllPresent() throws {
        #expect(
            try swish.eval("""
                (do
                  (defprotocol APFProto6a)
                  (defprotocol APFProto6b)
                  (defrecord APFRec6 [] APFProto6a APFProto6b)
                  (let [a (ancestors APFRec6)]
                    (and (contains? a (:name APFProto6a))
                         (contains? a (:name APFProto6b)))))
                """) == .boolean(true))
    }

    @Test("isa? does not reflect protocol ancestry (deliberate scope boundary)")
    func isaDoesNotReflectProtocols() throws {
        #expect(
            try swish.eval("""
                (do
                  (defprotocol APFProto7)
                  (defrecord APFRec7 [] APFProto7)
                  (isa? APFRec7 (:name APFProto7)))
                """) == .boolean(false))
    }
}
