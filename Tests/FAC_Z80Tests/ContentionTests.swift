import XCTest
@testable import FAC_Z80

/// A fake bus-contention model that inserts a fixed delay for contended addresses.
private final class FakeContention: BusContention {
    let contended: Set<UInt16>
    let delayPerAccess: Int
    init(contended: Set<UInt16>, delayPerAccess: Int) {
        self.contended = contended
        self.delayPerAccess = delayPerAccess
    }
    func delay(beginningAt tStateInFrame: Int, address: UInt16) -> Int {
        contended.contains(address) ? delayPerAccess : 0
    }
}

/// Verifies that a bus-contention model's wait states are inserted into the CPU
/// clock at each contended memory access.
final class ContentionTests: XCTestCase {

    private func makeCPU(_ program: [UInt8]) -> (Z80, LoggingMemory) {
        let mem = LoggingMemory()
        mem.loadProgram(program, at: 0x0000)
        let cpu = Z80(memory: mem)
        cpu.PC = 0x0000
        return (cpu, mem)
    }

    func testContendedMemoryAccessAddsWaitStates() {
        // LD A,(0x4000) is 0x3A lo hi — reads the contended address 0x4000.
        let (cpu, mem) = makeCPU([0x3A, 0x00, 0x40])
        let contention = FakeContention(contended: [0x4000], delayPerAccess: 6)
        cpu.contention = contention
        mem.setByte(0xAA, at: 0x4000)
        cpu.fetchAndExecute()
        // LD A,(nn) is 13 t-states; the contended read adds 6 wait states.
        XCTAssertEqual(cpu.tStates, 13 + 6)
    }

    func testUncontendedMemoryAccessAddsNoWaitStates() {
        // LD A,(0x2000) — not contended.
        let (cpu, mem) = makeCPU([0x3A, 0x00, 0x20])
        let contention = FakeContention(contended: [0x4000], delayPerAccess: 6)
        cpu.contention = contention
        cpu.fetchAndExecute()
        XCTAssertEqual(cpu.tStates, 13)
    }

    func testNoContentionModelAddsNoWaitStates() {
        let (cpu, _) = makeCPU([0x3A, 0x00, 0x40])
        cpu.fetchAndExecute()
        XCTAssertEqual(cpu.tStates, 13)
    }

    func testMultipleContendedAccessesAccumulateDelays() {
        // EX (SP),HL is 0xE3 — reads and writes to SP (0xFFFE/0xFFFF).
        let (cpu, mem) = makeCPU([0xE3])
        cpu.SP = 0xFFFE
        cpu.HL = 0x1234
        let contention = FakeContention(contended: [0xFFFE, 0xFFFF], delayPerAccess: 2)
        cpu.contention = contention
        mem.setByte(0xAA, at: 0xFFFE)
        mem.setByte(0xBB, at: 0xFFFF)
        cpu.fetchAndExecute()
        // EX (SP),HL is 19 t-states; it does one 16-bit read (2 bytes) and one
        // 16-bit write (2 bytes) = 4 byte accesses, each delayed by 2.
        XCTAssertEqual(cpu.tStates, 19 + 4 * 2)
    }
}
