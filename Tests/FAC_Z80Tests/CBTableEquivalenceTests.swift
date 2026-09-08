import XCTest
@testable import FAC_Z80

/// Proves the migrated CB table is byte-for-byte equivalent to the switch
/// implementation (opCodeCB) for every CB operand across varied register
/// states, by running identical pre-state through both paths and comparing
/// the resulting CPU state and memory log.
final class CBTableEquivalenceTests: XCTestCase {

    /// A representative spread of starting register/memory states so both
    /// paths are exercised with differing inputs.
    private static let probeStates: [(registers: [String: UInt8], hl: UInt16, hlMem: UInt8, carry: Bool)] = [
        (registers: [:], hl: 0x4000, hlMem: 0x00, carry: false),
        (registers: ["A": 0xFF, "B": 0x01, "C": 0x80, "D": 0x55, "E": 0xAA, "H": 0x10, "L": 0x20], hl: 0x4000, hlMem: 0xFF, carry: true),
        (registers: ["A": 0x00, "B": 0x00, "C": 0x7F, "D": 0xFE, "E": 0x01, "H": 0x00, "L": 0x00], hl: 0x8000, hlMem: 0x80, carry: false),
        (registers: ["A": 0x5A, "B": 0xA5, "C": 0x0F, "D": 0xF0, "E": 0x33, "H": 0x12, "L": 0x34], hl: 0xFFFF, hlMem: 0x0F, carry: true),
    ]

    private func makeCPU(
        _ registers: [String: UInt8],
        hl: UInt16,
        hlMem: UInt8,
        carry: Bool
    ) -> (Z80, LoggingMemory) {
        let mem = LoggingMemory()
        // Place a dummy CB operand at 0x0000 so next() has something to read.
        mem.loadProgram([0x00, 0x00, 0x00, 0x00], at: 0x0000)
        let cpu = Z80(memory: mem)
        cpu.PC = 0x0000
        if let a = registers["A"] { cpu.A = a }
        if let b = registers["B"] { cpu.B = b }
        if let c = registers["C"] { cpu.C = c }
        if let d = registers["D"] { cpu.D = d }
        if let e = registers["E"] { cpu.E = e }
        if let h = registers["H"] { cpu.H = h }
        if let l = registers["L"] { cpu.L = l }
        cpu.HL = hl
        cpu.F = carry ? cpu.carry : 0x00
        mem.setByte(hlMem, at: hl)
        mem.setByte(hlMem &+ 1, at: hl &+ 1)
        return (cpu, mem)
    }

    /// Run one CB operand through the switch (opCodeCB) and capture state+log.
    private func runViaSwitch(operand: UInt8, _ s: (registers: [String: UInt8], hl: UInt16, hlMem: UInt8, carry: Bool))
        -> (snapshot: CPUSnapshot, memlog: [MemAccess]) {
        let (cpu, mem) = makeCPU(s.registers, hl: s.hl, hlMem: s.hlMem, carry: s.carry)
        mem.loadProgram([operand], at: 0x0000)
        cpu.PC = 0x0000
        mem.resetLog()
        cpu.opCodeCB()
        return (CPUSnapshot(cpu: cpu), mem.accessLog)
    }

    /// Run one CB operand through the table and capture state+log.
    private func runViaTable(operand: UInt8, _ s: (registers: [String: UInt8], hl: UInt16, hlMem: UInt8, carry: Bool))
        -> (snapshot: CPUSnapshot, memlog: [MemAccess]) {
        let (cpu, mem) = makeCPU(s.registers, hl: s.hl, hlMem: s.hlMem, carry: s.carry)
        mem.loadProgram([operand], at: 0x0000)
        cpu.PC = 0x0000
        mem.resetLog()
        let info = cpu.opcodeTables.cb[Int(operand)]
        let (m, t) = info.execute(cpu)
        cpu.accumulate(m: m, t: t)
        return (CPUSnapshot(cpu: cpu), mem.accessLog)
    }

    func testCBTableMatchesSwitchForAllOperandsAndStates() {
        for state in Self.probeStates {
            for operand in 0..<256 {
                let viaSwitch = runViaSwitch(operand: UInt8(operand), state)
                let viaTable = runViaTable(operand: UInt8(operand), state)

                XCTAssertEqual(viaSwitch.snapshot, viaTable.snapshot,
                               "State mismatch for CB 0x\(String(format: "%02X", operand)) in state \(state.registers)")
                XCTAssertEqual(viaSwitch.memlog, viaTable.memlog,
                               "Memory log mismatch for CB 0x\(String(format: "%02X", operand)) in state \(state.registers)")
            }
        }
    }
}
