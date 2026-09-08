import XCTest
@testable import FAC_Z80

/// M0 maskable-INT timing, implemented correctly:
/// - fires at most once per frame (intServicedThisFrame gate)
/// - accepting an INT clears IFF1/IFF2 (real Z80), so it cannot re-fire
/// - EI defers acceptance by one instruction
/// - HALT wakes on the INT
/// - frame-end fallback guarantees once-per-frame even if the window is missed
final class M0InterruptTimingTests: XCTestCase {

    private func makeCPU(_ program: [UInt8]) -> (Z80, LoggingMemory) {
        let mem = LoggingMemory()
        mem.loadProgram(program, at: 0x0000)
        let cpu = Z80(memory: mem)
        cpu.PC = 0x0000
        cpu.interuptMode = 1
        return (cpu, mem)
    }

    // MARK: Once per frame + IFF cleared on accept

    func testINTFiresOnceInsideWindowAndClearsIFF() {
        let (cpu, _) = makeCPU([0x00, 0x00, 0x00])
        cpu.iff1 = 1
        cpu.iff2 = 1
        cpu.tStates = 4 // inside [0,32)
        cpu.serviceInterrupts()
        XCTAssertEqual(cpu.PC, 0x0038)
        XCTAssertTrue(cpu.intServicedThisFrame)
        XCTAssertEqual(cpu.iff1, 0) // IFF cleared on accept
        XCTAssertEqual(cpu.iff2, 0)

        // A second instruction boundary inside the window must NOT re-fire.
        cpu.PC = 0x0001
        cpu.serviceInterrupts()
        XCTAssertEqual(cpu.PC, 0x0001) // unchanged — no re-fire
    }

    func testINTNotServicedWhenDisabled() {
        let (cpu, _) = makeCPU([0x00])
        cpu.iff1 = 0
        cpu.tStates = 4
        cpu.serviceInterrupts()
        XCTAssertEqual(cpu.PC, 0x0000)
        XCTAssertFalse(cpu.intServicedThisFrame)
    }

    func testINTNotServicedOutsideWindow() {
        let (cpu, _) = makeCPU([0x00])
        cpu.iff1 = 1
        cpu.tStates = 100 // outside [0,32)
        cpu.serviceInterrupts()
        XCTAssertEqual(cpu.PC, 0x0000)
        XCTAssertFalse(cpu.intServicedThisFrame)
    }

    func testFrameBoundaryResetsServicedFlag() {
        let (cpu, mem) = makeCPU([0x00, 0x00])
        cpu.iff1 = 1
        cpu.intServicedThisFrame = true
        cpu.tStates = 69_887
        cpu.fetchAndExecute() // wraps frame → resets intServicedThisFrame
        XCTAssertFalse(cpu.intServicedThisFrame)
        XCTAssertTrue(cpu.frameBoundaryHit)
    }

    // MARK: EI deferral

    func testEIDefersOneInstructionThenAllowsINT() {
        let (cpu, _) = makeCPU([0xFB, 0x00]) // EI; NOP
        cpu.tStates = 4
        cpu.fetchAndExecute() // EI: iff1=1, eiDeferred=true
        cpu.serviceInterrupts() // deferred: no INT, deferral consumed
        XCTAssertEqual(cpu.PC, 0x0001)
        XCTAssertFalse(cpu.eiDeferred)

        cpu.fetchAndExecute() // NOP
        cpu.serviceInterrupts() // now INT can be taken
        XCTAssertEqual(cpu.PC, 0x0038)
    }

    func testDIClearsDeferralAndDisables() {
        let (cpu, _) = makeCPU([0xFB, 0xF3]) // EI; DI
        cpu.fetchAndExecute() // EI
        XCTAssertTrue(cpu.eiDeferred)
        cpu.fetchAndExecute() // DI
        XCTAssertFalse(cpu.eiDeferred)
        XCTAssertEqual(cpu.iff1, 0)
        XCTAssertEqual(cpu.iff2, 0)
    }

    // MARK: HALT wakes on INT

    func testHALTWakesWhenINTAssertedAndEnabled() {
        let (cpu, _) = makeCPU([0x76]) // HALT
        cpu.iff1 = 1
        cpu.tStates = 8
        cpu.fetchAndExecute() // HALT: enters halt state
        cpu.serviceInterrupts() // INT accepted, wakes halt
        XCTAssertFalse(cpu.isInHaltState)
        XCTAssertEqual(cpu.PC, 0x0038)
    }

    // MARK: Fallback

    func testFrameEndFallbackFiresIfWindowMissed() {
        let (cpu, _) = makeCPU([0x00])
        cpu.iff1 = 1
        cpu.intServicedThisFrame = false
        // Simulate render() fallback: window was never serviced.
        let pcBefore = cpu.PC
        cpu.intServicedThisFrame = true
        cpu.serviceMaskableInterrupt()
        XCTAssertEqual(cpu.PC, 0x0038)
        XCTAssertNotEqual(cpu.PC, pcBefore)
    }
}