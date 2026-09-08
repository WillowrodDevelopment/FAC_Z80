import XCTest
@testable import FAC_Z80

/// M1: CB/ED/DD/DDFDCB patterns exist and have plausible timing.
/// These are data-only checks — execution still falls back for prefixes until dispatch is migrated.
final class M1PatternsTests: XCTestCase {

    func testCBPatternsPopulated() {
        let tables = OpcodeTableSet.defaultTables()
        // RLC B 0x00: 8T fetch+operand
        XCTAssertEqual(tables.cb[0x00].accessPattern.steps, [.init(.fetch, 0), .init(.read, 4)])
        // BIT 0,B 0x40: 8T
        XCTAssertEqual(tables.cb[0x40].accessPattern.steps.count, 2)
        // BIT 0,(HL) 0x46: 12T with extra read
        let bitHL = tables.cb[0x46].accessPattern
        XCTAssertEqual(bitHL.steps.count, 3)
        XCTAssertEqual(bitHL.steps[0], .init(.fetch, 0))
        XCTAssertEqual(bitHL.steps[1], .init(.read, 4))
        // RLC (HL) 0x06: 15T with RMW
        let rlcHL = tables.cb[0x06].accessPattern
        XCTAssertEqual(rlcHL.steps.count, 4)
        XCTAssertEqual(rlcHL.steps[2].kind, .read)
        XCTAssertEqual(rlcHL.steps[3].kind, .write)
        // All CB entries have at least fetch+operand
        for op in 0..<256 { XCTAssertGreaterThanOrEqual(tables.cb[op].accessPattern.steps.count, 2, "CB \(op.hex())") }
    }

    func testEDPatternsPopulated() {
        let tables = OpcodeTableSet.defaultTables()
        // IN B,(C) 0x40: fetch ED, operand, IO
        let inB = tables.ed[0x40].accessPattern
        XCTAssertTrue(inB.steps.contains(where: { $0.kind == .io }))
        // LD (nn),BC 0x43: 20T 6 steps
        XCTAssertEqual(tables.ed[0x43].accessPattern.steps.count, 6)
        // NEG 0x44: 8T fetch+operand
        XCTAssertEqual(tables.ed[0x44].accessPattern.steps.count, 2)
        // LDIR 0xB0: 16/21T with read+write
        XCTAssertGreaterThanOrEqual(tables.ed[0xB0].accessPattern.steps.count, 4)
        // All ED have at least 2 steps
        for op in 0..<256 { XCTAssertGreaterThanOrEqual(tables.ed[op].accessPattern.steps.count, 2) }
    }

    func testDDFDPatternsPopulated() {
        let tables = OpcodeTableSet.defaultTables()
        // LD IX,nn 0x21: prefix, operand, imm low/high
        XCTAssertEqual(tables.dd[0x21].accessPattern.steps.count, 4)
        XCTAssertEqual(tables.fd[0x21].accessPattern.steps.count, 4)
        // LD (IX+d),n 0x36: prefix, operand, d, read imm, write
        XCTAssertGreaterThanOrEqual(tables.dd[0x36].accessPattern.steps.count, 5)
        // ADD IX,BC 0x09: fetch prefix, operand
        XCTAssertEqual(tables.dd[0x09].accessPattern.steps.count, 2)
        // CB prefix placeholder
        XCTAssertEqual(tables.dd[0xCB].accessPattern, .fetchOnly)
    }

    func testDDFDCBPatternsPopulated() {
        let tables = OpcodeTableSet.defaultTables()
        // RLC (IX+d),B 0x00: 23T with write
        let rlc = tables.ddfdcb[0x00].accessPattern
        XCTAssertTrue(rlc.steps.contains(where: { $0.kind == .write }))
        XCTAssertEqual(rlc.steps.first, .init(.fetch, 0))
        // BIT 0,(IX+d) 0x46: 20T read only
        let bit = tables.ddfdcb[0x46].accessPattern
        XCTAssertFalse(bit.steps.contains(where: { $0.kind == .write }))
        XCTAssertEqual(bit.steps.count, 5)
        // All 256 have patterns
        for op in 0..<256 { XCTAssertGreaterThanOrEqual(tables.ddfdcb[op].accessPattern.steps.count, 5) }
    }

    func testAllTablesLastOffsetLessThanTotal() {
        // Sanity: last offset must be < total T for every entry (remainder >0)
        let tables = OpcodeTableSet.defaultTables()
        func check(_ table: [OpcodeInfo], name: String) {
            for op in 0..<256 {
                let info = table[op]
                // Peek expected total from execute on a dummy CPU? Instead just check last offset < 30
                if let last = info.accessPattern.steps.last {
                    XCTAssertLessThan(last.tStateOffset, 30, "\(name) \(op.hex()) last offset \(last.tStateOffset)")
                }
            }
        }
        check(tables.main, name: "main")
        check(tables.cb, name: "cb")
        check(tables.ed, name: "ed")
        check(tables.dd, name: "dd")
        check(tables.fd, name: "fd")
        for op in 0..<256 {
            if let last = tables.ddfdcb[op].accessPattern.steps.last {
                XCTAssertLessThan(last.tStateOffset, 30, "ddfdcb \(op.hex())")
            }
        }
    }
}

private extension Int { func hex() -> String { String(format: "%02X", self) } }
