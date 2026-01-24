import Testing
@testable import SwishKit

@Suite("SwishKit Tests")
struct SwishKitTests {
    @Test("Swish initializes successfully")
    func initialization() {
        let swish = Swish()
        #expect(swish.eval("hello") == "=> hello")
    }
}
