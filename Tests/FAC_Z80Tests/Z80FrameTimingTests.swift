import XCTest
@testable import FAC_Z80

/// A read-only zeroed memory so the CPU can fetch NOPs forever.
private final class ZeroMemory: MemoryDelegate {
    func write(to address: UInt16, value: UInt8) {}
    func read(from address: UInt16) -> UInt8 { 0x00 }
    func writeWord(to address: UInt16, value: UInt16) {}
    func readWord(from address: UInt16) -> UInt16 { 0x0000 }
    func fetchBatch(from address: Int, size: Int) -> [UInt8] {
        [UInt8](repeating: 0x00, count: size)
    }
}

/// A machine whose frame budget differs from the default 48K figure.
private final class WideFrameZ80: Z80 {
    override var frameTStates: Int { 70_908 }
}

final class Z80FrameTimingTests: XCTestCase {

    private func makeCPU() -> Z80 {
        Z80(memory: ZeroMemory())
    }

    func testDefaultFrameBudgetIs48K() {
        XCTAssertEqual(makeCPU().frameTStates, 69_888)
        XCTAssertEqual(tStatesPerFrame, 69_888)
    }

    func testNOPAdvancesFourTStates() {
        let cpu = makeCPU()
        XCTAssertEqual(cpu.tStates, 0)
        cpu.fetchAndExecute() // 0x00 NOP
        XCTAssertEqual(cpu.tStates, 4)
        XCTAssertFalse(cpu.frameBoundaryHit)
    }

    func testFrameLengthOverrideControlsBoundary() {
        let cpu = WideFrameZ80(memory: ZeroMemory())
        XCTAssertEqual(cpu.frameTStates, 70_908)

        // Push the machine past its (short, overridden) budget with NOPs, then
        // confirm the frame boundary trips and the counter wraps to zero.
        cpu.tStates = 70_907
        cpu.fetchAndExecute() // +4 → 70_911 ≥ 70_908
        XCTAssertTrue(cpu.frameBoundaryHit)
        XCTAssertEqual(cpu.tStates, 0)
    }

    func testDefaultBudgetBoundary() {
        let cpu = makeCPU()
        cpu.tStates = 69_887
        cpu.fetchAndExecute() // +4 → 69_891 ≥ 69_888
        XCTAssertTrue(cpu.frameBoundaryHit)
        XCTAssertEqual(cpu.tStates, 0)
    }
}
