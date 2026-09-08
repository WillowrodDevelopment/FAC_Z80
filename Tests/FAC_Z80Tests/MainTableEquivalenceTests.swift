import XCTest
@testable import FAC_Z80

/// Proves the migrated main 256-opcode table is byte-for-byte equivalent to
/// the switch implementation (fetchAndExecute) for every opcode across varied
/// register/flag states, by running identical pre-state through both paths
/// and comparing the resulting CPU state and memory log.
final class MainTableEquivalenceTests: XCTestCase {

    private struct ProbeState {
        let a: UInt8
        let bc: UInt16
        let de: UInt16
        let hl: UInt16
        let sp: UInt16
        let flags: UInt8
        let ix: UInt16
        let iy: UInt16
    }

    /// States chosen to exercise every conditional branch and both halves of
    /// the LD/ALU register matrix.
    private static let states: [ProbeState] = [
        ProbeState(a: 0x00, bc: 0x1234, de: 0xABCD, hl: 0x4000, sp: 0xFFFE, flags: 0x00, ix: 0x1111, iy: 0x2222),
        ProbeState(a: 0x55, bc: 0x0001, de: 0x8000, hl: 0x5555, sp: 0x8000, flags: 0x47, ix: 0x3333, iy: 0x4444),
        ProbeState(a: 0xFF, bc: 0x8000, de: 0x0002, hl: 0xFFFF, sp: 0x0004, flags: 0x80, ix: 0xAAAA, iy: 0xBBBB),
        ProbeState(a: 0x0F, bc: 0xFFFF, de: 0x4000, hl: 0x8000, sp: 0x6000, flags: 0x01, ix: 0x0000, iy: 0xFFFF),
    ]

    /// Builds a memory image: the single opcode at 0x0000, generous operands,
    /// and pre-filled data at the register-pointed addresses.
    private func makeMemory(opcode: UInt8) -> LoggingMemory {
        let mem = LoggingMemory()
        mem.setByte(opcode, at: 0x0000)
        // Operand bytes after the opcode (for next()/nextWord()).
        mem.setByte(0xCD, at: 0x0001) // e.g. low operand
        mem.setByte(0xAB, at: 0x0002) // high operand
        mem.setByte(0x01, at: 0x0003)
        mem.setByte(0x02, at: 0x0004)
        // For prefix opcodes (CB/DD/ED/FD): the prefix operand byte.
        mem.setByte(0x07, at: 0x0001) // RLC A style
        mem.setByte(0x40, at: 0x0002) // LD B,B style
        mem.setByte(0xE1, at: 0x0003)
        // Target data at plausible addresses.
        mem.setByte(0xAA, at: 0x1234)
        mem.setByte(0xBB, at: 0xABCD)
        mem.setByte(0xCC, at: 0x4000)
        mem.setByte(0xDD, at: 0x4001)
        mem.setByte(0xEE, at: 0x8000)
        mem.setByte(0xFF, at: 0x8001)
        mem.setByte(0x12, at: 0xFFFE)
        mem.setByte(0x34, at: 0xFFFF)
        return mem
    }

    private func runViaSwitch(_ s: ProbeState, opcode: UInt8) -> (CPUSnapshot, [MemAccess]) {
        let mem = makeMemory(opcode: opcode)
        let cpu = Z80(memory: mem)
        cpu.PC = 0x0000
        cpu.A = s.a
        cpu.BC = s.bc
        cpu.DE = s.de
        cpu.HL = s.hl
        cpu.SP = s.sp
        cpu.F = s.flags
        cpu.IX = s.ix
        cpu.IY = s.iy
        mem.resetLog()
        cpu.fetchAndExecute()
        return (CPUSnapshot(cpu: cpu), mem.accessLog)
    }

    private func runViaTable(_ s: ProbeState, opcode: UInt8) -> (CPUSnapshot, [MemAccess]) {
        let mem = makeMemory(opcode: opcode)
        let cpu = Z80(memory: mem)
        cpu.PC = 0x0000
        cpu.A = s.a
        cpu.BC = s.bc
        cpu.DE = s.de
        cpu.HL = s.hl
        cpu.SP = s.sp
        cpu.F = s.flags
        cpu.IX = s.ix
        cpu.IY = s.iy
        mem.resetLog()
        cpu.fetchAndExecuteViaTable()
        return (CPUSnapshot(cpu: cpu), mem.accessLog)
    }

    func testMainTableMatchesSwitchForAllOpcodesAndStates() {
        for state in Self.states {
            for opcode in 0..<256 {
                let viaSwitch = runViaSwitch(state, opcode: UInt8(opcode))
                let viaTable = runViaTable(state, opcode: UInt8(opcode))

                XCTAssertEqual(viaSwitch.0, viaTable.0,
                               "State mismatch for 0x\(String(format: "%02X", opcode)) in state \(state)")
                XCTAssertEqual(viaSwitch.1, viaTable.1,
                               "Memory log mismatch for 0x\(String(format: "%02X", opcode)) in state \(state)")
            }
        }
    }
}
