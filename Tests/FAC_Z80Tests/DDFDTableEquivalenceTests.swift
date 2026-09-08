import XCTest
@testable import FAC_Z80

/// Proves the migrated DD/FD table is byte-for-byte equivalent to the switch
/// implementation (opCodeDDFD) for every operand, for both IX and IY, across
/// varied register/flag states.
final class DDFDTableEquivalenceTests: XCTestCase {

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

    private static let states: [ProbeState] = [
        ProbeState(a: 0x00, bc: 0x1234, de: 0xABCD, hl: 0x4000, sp: 0xFFFE, flags: 0x00, ix: 0x1111, iy: 0x2222),
        ProbeState(a: 0x55, bc: 0x0001, de: 0x8000, hl: 0x5555, sp: 0x8000, flags: 0x47, ix: 0x3333, iy: 0x4444),
        ProbeState(a: 0xFF, bc: 0x8000, de: 0x0002, hl: 0xFFFF, sp: 0x0004, flags: 0x80, ix: 0xAAAA, iy: 0xBBBB),
        ProbeState(a: 0x0F, bc: 0xFFFF, de: 0x4000, hl: 0x8000, sp: 0x6000, flags: 0x01, ix: 0x0000, iy: 0xFFFF),
    ]

    private func makeMemory(operand: UInt8) -> LoggingMemory {
        let mem = LoggingMemory()
        mem.setByte(operand, at: 0x0000)
        // Operands (nn, displacement, etc.)
        mem.setByte(0xCD, at: 0x0001)
        mem.setByte(0xAB, at: 0x0002)
        mem.setByte(0x01, at: 0x0003)
        mem.setByte(0x02, at: 0x0004)
        // For 0xCB: the DDFDCB operand + displacement.
        mem.setByte(0x07, at: 0x0001)
        mem.setByte(0x00, at: 0x0002)
        // Target data.
        mem.setByte(0xAA, at: 0x1234)
        mem.setByte(0xBB, at: 0xABCD)
        mem.setByte(0xCC, at: 0x4000)
        mem.setByte(0xDD, at: 0x4001)
        mem.setByte(0x12, at: 0xFFFE)
        mem.setByte(0x34, at: 0xFFFF)
        return mem
    }

    private func runViaSwitch(_ s: ProbeState, operand: UInt8, index: Z8016BitRegister) -> (CPUSnapshot, [MemAccess]) {
        let mem = makeMemory(operand: operand)
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
        cpu.opCodeDDFD(index: index)
        return (CPUSnapshot(cpu: cpu), mem.accessLog)
    }

    private func runViaTable(_ s: ProbeState, operand: UInt8, index: Z8016BitRegister) -> (CPUSnapshot, [MemAccess]) {
        let mem = makeMemory(operand: operand)
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
        cpu.opCodeDDFDViaTable(index: index)
        return (CPUSnapshot(cpu: cpu), mem.accessLog)
    }

    func testDDFDTableMatchesSwitchForAllOperandsAndStates() {
        for index in [Z8016BitRegister.IX, .IY] {
            for state in Self.states {
                for operand in 0..<256 {
                    let viaSwitch = runViaSwitch(state, operand: UInt8(operand), index: index)
                    let viaTable = runViaTable(state, operand: UInt8(operand), index: index)

                    let label = "\(index == .IX ? "DD" : "FD") 0x\(String(format: "%02X", operand)) in state \(state)"
                    XCTAssertEqual(viaSwitch.0, viaTable.0, "State mismatch for \(label)")
                    XCTAssertEqual(viaSwitch.1, viaTable.1, "Memory log mismatch for \(label)")
                }
            }
        }
    }
}
