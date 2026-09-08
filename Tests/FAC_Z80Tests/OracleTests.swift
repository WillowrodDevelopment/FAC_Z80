import XCTest
@testable import FAC_Z80

final class OracleTests: XCTestCase {

    /// A broad instruction mix exercising representative opcodes from the
    /// main set, the CB prefix, the ED prefix and the DD/FD prefixes, plus
    /// 8-bit/16-bit ALU, block ops, and control flow.
    ///
    /// The program is deliberately crafted to execute a wide range of
    /// behaviours while staying straight-line (no unbounded loops) so the
    /// oracle can run a fixed number of instructions deterministically.
    private static let probeProgram: [UInt8] = [
        // LD BC, 0x1234
        0x01, 0x34, 0x12,
        // LD DE, 0xABCD
        0x11, 0xCD, 0xAB,
        // LD HL, 0x4000
        0x21, 0x00, 0x40,
        // LD (HL), A   (A=0 after reset) -> memory write to 0x4000
        0x77,
        // INC HL
        0x23,
        // LD A, 0x55
        0x3E, 0x55,
        // LD (0x4000), A -> absolute write
        0x32, 0x00, 0x40,
        // LD A, (0x4000) -> absolute read
        0x3A, 0x00, 0x40,
        // CB 0x07  RLC A
        0xCB, 0x07,
        // CB 0x06  RLC (HL)  (HL now 0x4001)
        0xCB, 0x06,
        // CB 0x80  RES 0, B
        0xCB, 0x80,
        // ED 0x5E  LD A,R
        0xED, 0x5F,
        // ED 0xA0  LDI
        0xED, 0xA0,
        // ADD HL, BC
        0x09,
        // JR 0x04 (skip 4 bytes forward - relative)
        0x18, 0x04,
        // 4 bytes to skip:
        0x00, 0x00, 0x00, 0x00,
        // NOP
        0x00,
        // DD 0x21, 0x78, 0x56  LD IX, 0x5678
        0xDD, 0x21, 0x78, 0x56,
        // FD 0x21, 0x34, 0x12  LD IY, 0x1234
        0xFD, 0x21, 0x34, 0x12,
        // PUSH BC
        0xC5,
        // POP DE
        0xD1,
        // XOR A
        0xAF,
        // HALT
        0x76,
    ]

    private func makeCPU(_ program: [UInt8]) -> (Z80, LoggingMemory) {
        let mem = LoggingMemory()
        mem.loadProgram(program, at: 0x0000)
        let cpu = Z80(memory: mem)
        cpu.PC = 0x0000
        return (cpu, mem)
    }

    func testOracleIsDeterministic() {
        let (cpu1, mem1) = makeCPU(Self.probeProgram)
        let (cpu2, mem2) = makeCPU(Self.probeProgram)

        let trace1 = Oracle.run(cpu1, memory: mem1, instructions: 40)
        let trace2 = Oracle.run(cpu2, memory: mem2, instructions: 40)

        XCTAssertEqual(trace1.count, trace2.count)
        for (i, (a, b)) in zip(trace1, trace2).enumerated() {
            XCTAssertEqual(a, b, "Trace diverged at step \(i)")
        }
    }

    func testOracleCapturesStateChanges() {
        let (cpu, mem) = makeCPU(Self.probeProgram)
        let trace = Oracle.run(cpu, memory: mem, instructions: 40)

        XCTAssertFalse(trace.isEmpty)
        // The first instruction (LD BC,0x1234) must have loaded BC.
        XCTAssertEqual(trace[0].post.bc, 0x1234)
        // PC must advance past the 3-byte instruction.
        XCTAssertEqual(trace[0].post.pc, 0x0003)
        // Some instruction must have performed a memory write to 0x4000.
        XCTAssertTrue(trace.contains { step in
            step.memory.contains { access in
                if case .write(let addr, _) = access, addr == 0x4000 { return true }
                return false
            }
        }, "Expected a write to 0x4000 in the trace")
    }

    func testHALTProducesStableIdleState() {
        // Program that runs straight to a HALT then idles.
        let (cpu, mem) = makeCPU([0x00, 0x76])
        let trace = Oracle.run(cpu, memory: mem, instructions: 6)
        XCTAssertGreaterThanOrEqual(trace.count, 2)
        // Once halted, the CPU stays put (PC unchanged, state stable).
        let halted = trace.last!
        XCTAssertEqual(halted.post.pc, 0x0002)
        XCTAssertTrue(cpu.isInHaltState)
    }
}
