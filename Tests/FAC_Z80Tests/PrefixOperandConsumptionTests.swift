import XCTest
@testable import FAC_Z80

/// Regression tests for the per-M-cycle prefix dispatch (WithPattern).
/// These catch the operand-consumption bug: the WithPattern dispatchers must
/// advance PC past the prefix operand byte (like the switch / ViaTable paths
/// do), otherwise the next instruction re-fetches the operand as an opcode.
final class PrefixOperandConsumptionTests: XCTestCase {

    private func cpu(program: [UInt8], pc: UInt16) -> (Z80, LoggingMemory) {
        let mem = LoggingMemory()
        mem.loadProgram(program, at: 0x0000)
        let cpu = Z80(memory: mem)
        cpu.PC = pc
        cpu.tStates = 0
        return (cpu, mem)
    }

    /// Simulate the state fetchAndExecute leaves behind after fetching the
    /// ED/DD prefix byte: pattern = main prefix entry (fetchOnly), index = 1.
    private func primeForPrefix(_ cpu: Z80, prefix: UInt8) {
        cpu.currentInstructionPattern = cpu.opcodeTables.main[Int(prefix)].accessPattern
        cpu.instructionAccessIndex = 1
        cpu.instructionBaseTStates = 0
        cpu.instructionDelay = 0
        cpu.instructionLastOffset = 0
    }

    // MARK: ED

    func testEDLDALConsumesOperandAndAdvancesPC() {
        // ED 57 = LD A,I (no own operand read)
        let (cpu, _) = cpu(program: [0xED, 0x57, 0x00, 0x00], pc: 1) // PC at the 57 operand
        primeForPrefix(cpu, prefix: 0xED)
        cpu.opCodeEDWithPattern()
        XCTAssertEqual(cpu.PC, 2, "ED dispatcher must consume the A0 operand byte")
        XCTAssertEqual(cpu.A, cpu.I)
    }

    func testEDLDIAdvancesPCAndTimestampsAccesses() {
        // ED A0 = LDI — must consume operand, then read (HL) @8, write (DE) @12
        let (cpu, mem) = cpu(program: [0xED, 0xA0, 0x00, 0x00], pc: 1)
        mem.setByte(0xAA, at: 0x1000)
        cpu.HL = 0x1000
        cpu.DE = 0x2000
        let rec = Recorder()
        cpu.accessRecorder = rec
        primeForPrefix(cpu, prefix: 0xED)
        cpu.opCodeEDWithPattern()
        XCTAssertEqual(cpu.PC, 2, "ED A0 is a 2-byte instruction; PC must advance past operand")
        XCTAssertEqual(mem.peek(from: 0x2000), 0xAA, "LDI must transfer the byte")
        XCTAssertEqual(cpu.tStates, 16, "LDI is 16 T-states total")
        XCTAssertEqual(rec.timestamps, [4, 8, 12], "operand fetch @4, read (HL) @8, write (DE) @12")
    }

    func testEDLDIRAdvancesPC() {
        // ED B0 = LDIR, BC=1 → single iteration, exits; PC must advance past operand
        let (cpu, mem) = cpu(program: [0xED, 0xB0, 0x00, 0x00], pc: 1)
        mem.setByte(0x11, at: 0x1000)
        cpu.HL = 0x1000
        cpu.DE = 0x2000
        cpu.BC = 1
        primeForPrefix(cpu, prefix: 0xED)
        cpu.opCodeEDWithPattern()
        XCTAssertEqual(cpu.PC, 2, "LDIR is a 2-byte instruction; PC must advance past operand")
        XCTAssertEqual(mem.peek(from: 0x2000), 0x11)
        XCTAssertEqual(cpu.tStates, 16, "LDIR single iteration is 16 T-states when it exits")
    }

    // MARK: DD

    func testDDLDIXNNConsumesOperandAndAdvancesPC() {
        // DD 21 34 12 = LD IX,0x1234
        let (cpu, _) = cpu(program: [0xDD, 0x21, 0x34, 0x12], pc: 1)
        primeForPrefix(cpu, prefix: 0xDD)
        cpu.opCodeDDFDWithPattern(index: .IX)
        XCTAssertEqual(cpu.PC, 4, "DD 21 nn nn is 4 bytes; PC must advance past nn")
        XCTAssertEqual(cpu.IX, 0x1234)
        XCTAssertEqual(cpu.tStates, 14, "LD IX,nn is 14 T-states")
    }

    func testDDINCAdvancesPC() {
        // DD 23 = INC IX (no own operand read)
        let (cpu, _) = cpu(program: [0xDD, 0x23, 0x00], pc: 1)
        cpu.IX = 0x1000
        primeForPrefix(cpu, prefix: 0xDD)
        cpu.opCodeDDFDWithPattern(index: .IX)
        XCTAssertEqual(cpu.PC, 2, "INC IX is 2 bytes; PC must advance past operand")
        XCTAssertEqual(cpu.IX, 0x1001)
        XCTAssertEqual(cpu.tStates, 10, "INC IX is 10 T-states")
    }
}

/// Minimal recorder capturing access timestamps (mirrors MCycleClockTests).
private final class Recorder: MemoryAccessRecorder {
    private(set) var timestamps: [Int] = []
    private(set) var addresses: [UInt16] = []
    func record(_ access: RecordedMemoryAccess) {
        timestamps.append(access.tStateInFrame)
        addresses.append(access.address)
    }
}