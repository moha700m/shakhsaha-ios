import XCTest
@testable import Shakhsaha

/// Scenario-based tests in the style of qadanm/elmulator: scripted ELM327 replies, no Bluetooth radio.
final class ParserTests: XCTestCase {
    func testStoredDTCsCAN() {
        XCTAssertEqual(ELMParser.dtcs("43 02 04 20 03 01\r\r>", response: 0x43), ["P0420", "P0301"])
    }
    func testLegacyDTCs() {
        XCTAssertEqual(ELMParser.dtcs("43 01 71 00 00 00 00\r>", response: 0x43), ["P0171"])
    }
    func testNoCodes() {
        XCTAssertEqual(ELMParser.dtcs("43 00\r>", response: 0x43), [])
        XCTAssertEqual(ELMParser.dtcs("NO DATA\r>", response: 0x47), [])
    }
    func testSystemLetters() {
        XCTAssertEqual(ELMParser.dtcString(0x41, 0x23), "C0123")
        XCTAssertEqual(ELMParser.dtcString(0x81, 0x00), "B0100")
        XCTAssertEqual(ELMParser.dtcString(0xC1, 0x00), "U0100")
    }
    func testRPMSpeedCoolant() {
        XCTAssertEqual(ELMParser.decode(.rpm, ELMParser.pidData("41 0C 1A F8\r>", pid: 0x0C)!), 1726)
        XCTAssertEqual(ELMParser.decode(.speed, ELMParser.pidData("410D3C>", pid: 0x0D)!), 60)
        XCTAssertEqual(ELMParser.decode(.coolant, ELMParser.pidData("SEARCHING...\r41 05 7B\r>", pid: 0x05)!), 83)
    }
    func testVoltage() {
        XCTAssertEqual(ELMParser.decode(.voltage, ELMParser.pidData("4142 3710>", pid: 0x42)!)!, 14.096, accuracy: 0.001)
        XCTAssertEqual(ELMParser.atrv("12.6V\r>"), 12.6)
    }
    func testVINMultiFrame() {
        let raw = "014\r0:490201314E34\r1:414C33415032\r2:4332383933343536\r>"
        XCTAssertEqual(ELMParser.vin(raw), "1N4AL3AP2C2893456")
        XCTAssertEqual(VINDecoder.make("1N4AL3AP2C2893456"), "Nissan")
        XCTAssertEqual(VINDecoder.year("1N4AL3AP2C2893456"), 2012)
    }
    func testReadiness() {
        let r = ELMParser.readiness("41 01 83 07 E1 00\r>")!
        XCTAssertTrue(r.milOn); XCTAssertEqual(r.dtcCount, 3); XCTAssertEqual(r.incomplete, 0)
        let r2 = ELMParser.readiness("41 01 00 07 E1 E1\r>")!
        XCTAssertFalse(r2.milOn); XCTAssertEqual(r2.incomplete, 4)
    }
    func testDatabaseNeverUnknown() {
        XCTAssertEqual(DTCDatabase.info("P0420").severity, .medium)
        let g = DTCDatabase.info("P1A99")
        XCTAssertFalse(g.titleAr.isEmpty)
        XCTAssertFalse(DTCDatabase.explain(g).isEmpty)
    }
    func testCostFallback() {
        let c = CatalogStore.cost(for: DTCDatabase.info("P0217"), in: CatalogStore.bundled)
        XCTAssertEqual(c.min, 300)
        let g = CatalogStore.cost(for: DTCDatabase.info("P0799"), in: CatalogStore.bundled)
        XCTAssertGreaterThan(g.max, 0)
    }
    func testHealthScore() {
        XCTAssertEqual(HealthScore.compute(codes: [], readiness: nil, voltage: 14), 100)
        let s = HealthScore.compute(codes: [FoundCode(code: "P0300", kind: .stored)], readiness: nil, voltage: 11.8)
        XCTAssertEqual(s, 67)
    }
    func testDemoScenarioEndToEnd() async throws {
        let t = DemoTransport()
        let r = try await t.send("03")
        XCTAssertEqual(ELMParser.dtcs(r, response: 0x43), ["P0420", "P0301"])
        _ = try await t.send("04")
        let r2 = try await t.send("03")
        XCTAssertEqual(ELMParser.dtcs(r2, response: 0x43), [])
    }
    func testBundledCatalogMatchesRemoteSchema() throws {
        let d = try JSONEncoder().encode(CatalogStore.bundled)
        XCTAssertNoThrow(try JSONDecoder().decode(RemoteCatalog.self, from: d))
    }

    func testUDSModuleDTCs() {
        XCTAssertEqual(Modules.parseUDS("5902FF04200009030100 09>"), ["P0420", "P0301"])
        XCTAssertEqual(Modules.parseUDS("5902FF>"), [])
        XCTAssertNil(Modules.parseUDS("NO DATA>"))
        XCTAssertNil(Modules.parseUDS("7F1911>"))
    }
    func testMode06() {
        let r = ELMParser.mode06("4621 80 0D 01 F4 00 C8 03 E8>")
        XCTAssertEqual(r.count, 1); XCTAssertEqual(r[0].value, 500); XCTAssertTrue(r[0].pass)
        XCTAssertFalse(ELMParser.mode06("46A3 0B 24 00 0F 00 00 00 0A>")[0].pass)
    }
    func testSupportedPIDs() {
        let s = ELMParser.supported("4100BE3EB813>", base: 0)
        XCTAssertTrue(s.contains(0x0C)); XCTAssertTrue(s.contains(0x0D)); XCTAssertTrue(s.contains(0x05))
    }
    func testPIDCatalog() {
        XCTAssertEqual(PIDs.def("stft1")!.decode([0x80])!, 0, accuracy: 0.01)
        XCTAssertEqual(PIDs.def("maf")!.decode([0x01, 0xF4])!, 5, accuracy: 0.01)
    }
}
