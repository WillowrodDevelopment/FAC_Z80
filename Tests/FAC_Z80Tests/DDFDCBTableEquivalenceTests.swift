import XCTest
@testable import FAC_Z80

/// Proves the migrated DDFDCB table is byte-for-byte equivalent to the switch
/// implementation (opCodeDDFDCB) for every CB operand, for both IX and IY,
/// across varied register/flag states.
final class DDFDCBTableEquivalenceTests: XCTestCase {

    private struct ProbeState {
        let a: UInt8
        let bc: UInt16
        let de: UInt16
        let hl: UInt16
        let flags: UInt8
        let ix: UInt16
        let iy: UInt16
    }

    private static let states: [ProbeState] = [
        ProbeState(a: 0x00, bc: 0x1234, de: 0xABCD, hl: 0x4000, flags: 0x00, ix: 0x1111, iy: 0x2222),
        ProbeState(a: 0x55, bc: 0x0001, de: 0x8000, hl: 0x5555, flags: 0x47, ix: 0x3333, iy: 0x4444),
        ProbeState(a: 0xFF, bc: 0x8000, de: 0x0002, hl: 0xFFFF, flags: 0x80, ix: 0xAAAA, iy: 0xBBBB),
        ProbeState(a: 0x0F, bc: 0xFFFF, de: 0x4000, hl: 0x8000, flags: 0x01, ix: 0x0000, iy: 0xFFFF),
    ]

    private func makeMemory(opcode: UInt8) -> LoggingMemory {
        let mem = LoggingMemory()
        // Displacement at 0x0000 (read by next() first), then the CB operand at 0x0001.
        mem.setByte(0x00, at: 0x0000)
        mem.setByte(opcode, at: 0x0001)
        // A target cell at a range of plausible displaced addresses.
        for addr in [0x1111, 0x3333, 0xAAAA, 0xBBBB, 0x0000, 0x4444, 0x2222, 0xFFFF] {
            mem.setByte(0x55, at: UInt16(addr))
        }
        return mem
    }

    private func runViaSwitch(_ s: ProbeState, opcode: UInt8, index: Z8016BitRegister) -> (CPUSnapshot, [MemAccess]) {
        let mem = makeMemory(opcode: opcode)
        let cpu = Z80(memory: mem)
        cpu.PC = 0x0000
        cpu.A = s.a
        cpu.BC = s.bc
        cpu.DE = s.de
        cpu.HL = s.hl
        cpu.F = s.flags
        cpu.IX = s.ix
        cpu.IY = s.iy
        mem.resetLog()
        cpu.opCodeDDFDCB(index: index)
        return (CPUSnapshot(cpu: cpu), mem.accessLog)
    }

    private func runViaTable(_ s: ProbeState, opcode: UInt8, index: Z8016BitRegister) -> (CPUSnapshot, [MemAccess]) {
        let mem = makeMemory(opcode: opcode)
        let cpu = Z80(memory: mem)
        cpu.PC = 0x0000
        cpu.A = s.a
        cpu.BC = s.bc
        cpu.DE = s.de
        cpu.HL = s.hl
        cpu.F = s.flags
        cpu.IX = s.ix
        cpu.IY = s.iy
        mem.resetLog()
        cpu.opCodeDDFDCBViaTable(index: index)
        return (CPUSnapshot(cpu: cpu), mem.accessLog)
    }

    func testDDFDCBTableMatchesSwitchForAllOpcodesAndStates() {
        for index in [Z8016BitRegister.IX, .IY] {
            for state in Self.states {
                for opcode in 0..<256 {
                    let viaSwitch = runViaSwitch(state, opcode: UInt8(opcode), index: index)
                    let viaTable = runViaTable(state, opcode: UInt8(opcode), index: index)

                    let label = "\(index == .IX ? "DD" : "FD") CB 0x\(String(format: "%02X", opcode)) in state \(state)"
                    XCTAssertEqual(viaSwitch.0, viaTable.0, "State mismatch for \(label)")
                    XCTAssertEqual(viaSwitch.1, viaTable.1, "Memory log mismatch for \(label)")
                }
            }
        }
    }
}
