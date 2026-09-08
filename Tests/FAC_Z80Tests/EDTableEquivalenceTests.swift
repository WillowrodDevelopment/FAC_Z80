import XCTest
@testable import FAC_Z80

/// Proves the migrated ED table is byte-for-byte equivalent to the switch
/// implementation (opCodeED) for every ED operand across varied register/flag
/// states, comparing CPU state and memory log.
final class EDTableEquivalenceTests: XCTestCase {

    private struct ProbeState {
        let a: UInt8
        let bc: UInt16
        let de: UInt16
        let hl: UInt16
        let sp: UInt16
        let flags: UInt8
        let i: UInt8
        let r: UInt8
    }

    private static let states: [ProbeState] = [
        ProbeState(a: 0x00, bc: 0x0003, de: 0x4000, hl: 0x8000, sp: 0xFFFE, flags: 0x00, i: 0x00, r: 0x00),
        ProbeState(a: 0x55, bc: 0x0001, de: 0x4001, hl: 0x6000, sp: 0x8000, flags: 0x47, i: 0x12, r: 0x34),
        ProbeState(a: 0xFF, bc: 0x0002, de: 0x8000, hl: 0x4000, sp: 0x0004, flags: 0x80, i: 0xAB, r: 0xCD),
        ProbeState(a: 0x0F, bc: 0x0000, de: 0x2000, hl: 0x5000, sp: 0x6000, flags: 0x01, i: 0xFF, r: 0x7F),
    ]

    private func makeMemory(operand: UInt8) -> LoggingMemory {
        let mem = LoggingMemory()
        mem.setByte(operand, at: 0x0000)
        // Operands for LD (nn),rp / LD rp,(nn) etc.
        mem.setByte(0xCD, at: 0x0001)
        mem.setByte(0xAB, at: 0x0002)
        mem.setByte(0x01, at: 0x0003)
        // Target data.
        mem.setByte(0xAA, at: 0xABCD)
        mem.setByte(0xBB, at: 0xABCE)
        mem.setByte(0xCC, at: 0x4000)
        mem.setByte(0xDD, at: 0x4001)
        mem.setByte(0x12, at: 0xFFFE)
        mem.setByte(0x34, at: 0xFFFF)
        return mem
    }

    private func runViaSwitch(_ s: ProbeState, operand: UInt8) -> (CPUSnapshot, [MemAccess]) {
        let mem = makeMemory(operand: operand)
        let cpu = Z80(memory: mem)
        cpu.PC = 0x0000
        cpu.A = s.a
        cpu.BC = s.bc
        cpu.DE = s.de
        cpu.HL = s.hl
        cpu.SP = s.sp
        cpu.F = s.flags
        cpu.I = s.i
        cpu.R = s.r
        mem.resetLog()
        cpu.opCodeED()
        return (CPUSnapshot(cpu: cpu), mem.accessLog)
    }

    private func runViaTable(_ s: ProbeState, operand: UInt8) -> (CPUSnapshot, [MemAccess]) {
        let mem = makeMemory(operand: operand)
        let cpu = Z80(memory: mem)
        cpu.PC = 0x0000
        cpu.A = s.a
        cpu.BC = s.bc
        cpu.DE = s.de
        cpu.HL = s.hl
        cpu.SP = s.sp
        cpu.F = s.flags
        cpu.I = s.i
        cpu.R = s.r
        mem.resetLog()
        cpu.opCodeEDViaTable()
        return (CPUSnapshot(cpu: cpu), mem.accessLog)
    }

    func testEDTableMatchesSwitchForAllOperandsAndStates() {
        for state in Self.states {
            for operand in 0..<256 {
                let viaSwitch = runViaSwitch(state, operand: UInt8(operand))
                let viaTable = runViaTable(state, operand: UInt8(operand))

                XCTAssertEqual(viaSwitch.0, viaTable.0,
                               "State mismatch for ED 0x\(String(format: "%02X", operand)) in state \(state)")
                XCTAssertEqual(viaSwitch.1, viaTable.1,
                               "Memory log mismatch for ED 0x\(String(format: "%02X", operand)) in state \(state)")
            }
        }
    }
}
