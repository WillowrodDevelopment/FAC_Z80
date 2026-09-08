import XCTest
@testable import FAC_Z80

/// M0 additions that do NOT touch the maskable-INT frame-boundary path (which
/// games depend on): scanline tracking and NMI. These are additive and cannot
/// alter existing game timing.
final class M0SafeTimingTests: XCTestCase {

    // MARK: Scanline tracking

    func testScanlineAdvancesWithTStates() {
        let mem = LoggingMemory()
        let cpu = Z80(memory: mem)
        cpu.tStates = 0
        XCTAssertEqual(cpu.currentScanline, 0)
        cpu.tStates = 223
        XCTAssertEqual(cpu.currentScanline, 0)
        cpu.tStates = 224
        XCTAssertEqual(cpu.currentScanline, 1)
        cpu.tStates = 447
        XCTAssertEqual(cpu.currentScanline, 1)
        cpu.tStates = 448
        XCTAssertEqual(cpu.currentScanline, 2)
    }

    func testScanlinesPerFrameDerivedFromBudget() {
        let mem = LoggingMemory()
        let cpu = Z80(memory: mem)
        XCTAssertEqual(cpu.scanlinesPerFrame, 69_888 / 224)
        XCTAssertEqual(cpu.tStatesPerScanline, 224)
    }

    func testScanlineCrossedHookFiresOnBoundary() {
        final class TrackingZ80: Z80 {
            var crossed: [Int] = []
            override func scanlineCrossed(line: Int) {
                crossed.append(line)
            }
        }
        let mem = LoggingMemory()
        let cpu = TrackingZ80(memory: mem)
        cpu.tStates = 220
        cpu.accumulate(m: 1, t: 10) // 230 → crosses into scanline 1
        XCTAssertEqual(cpu.crossed, [1])
        XCTAssertEqual(cpu.currentScanline, 1)
    }

    func testScanlineTrackingSurvivesFrameWrap() {
        // An instruction crossing the frame boundary must not crash or report
        // phantom scanlines (the forward-only guard).
        final class TrackingZ80: Z80 {
            var crossed: [Int] = []
            override func scanlineCrossed(line: Int) {
                crossed.append(line)
            }
        }
        let mem = LoggingMemory()
        let cpu = TrackingZ80(memory: mem)
        cpu.tStates = 69_887
        cpu.accumulate(m: 1, t: 4) // wraps to 0, frameBoundaryHit set
        XCTAssertTrue(cpu.frameBoundaryHit)
        XCTAssertEqual(cpu.tStates, 0)
        XCTAssertEqual(cpu.currentScanline, 0)
        XCTAssertEqual(cpu.crossed, []) // no phantom forward crossings
    }

    // MARK: NMI

    func testNMIRequestsAndVectorsTo0066() {
        let mem = LoggingMemory()
        let cpu = Z80(memory: mem)
        cpu.PC = 0x0000
        cpu.SP = 0xFFFE
        cpu.iff1 = 1
        cpu.requestNMI()
        cpu.checkNMI()
        XCTAssertEqual(cpu.PC, 0x0066)
        XCTAssertEqual(cpu.SP, 0xFFFC) // return address pushed
        XCTAssertFalse(cpu.nmiRequested)
    }

    func testNMISavesIFF1IntoIFF2AndClearsIFF1() {
        let mem = LoggingMemory()
        let cpu = Z80(memory: mem)
        cpu.iff1 = 1
        cpu.iff2 = 0
        cpu.requestNMI()
        cpu.checkNMI()
        // IFF1 saved to IFF2 so RETN can restore it; IFF1 cleared.
        XCTAssertEqual(cpu.iff2, 1)
        XCTAssertEqual(cpu.iff1, 0)
    }

    func testNMIWithoutRequestDoesNothing() {
        let mem = LoggingMemory()
        let cpu = Z80(memory: mem)
        cpu.PC = 0x1234
        cpu.checkNMI()
        XCTAssertEqual(cpu.PC, 0x1234)
        XCTAssertFalse(cpu.nmiRequested)
    }
}