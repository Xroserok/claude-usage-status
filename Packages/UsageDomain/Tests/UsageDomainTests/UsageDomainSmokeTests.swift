import Testing

@testable import UsageDomain

@Suite struct UsageDomainSmokeTests {
    @Test func moduleLinks() {
        #expect(Bool(true))
    }
}
