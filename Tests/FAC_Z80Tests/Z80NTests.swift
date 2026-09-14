import XCTest
@testable import FAC_Z80

/// A Z80 that captures NEXTREG writes (Z80N ED 91/92).
private final class NextRegRecordingZ80: Z80 {
    var nextRegWrites: [(reg: UInt8, value: UInt8)] = []
    override func nextRegWrite(_ reg: UInt8, value: UInt8) {
        nextRegWrites.append((reg, value))
    }
}

final class Z80NTests: XCTestCase {

    private func makeCPU(program: [UInt8]) -> (NextRegRecordingZ80, LoggingMemory) {
        let mem = LoggingMemory()
        mem.loadProgram(program, at: 0x0000)
        let cpu = NextRegRecordingZ80(memory: mem)
        cpu.PC = 0x0000
        cpu.z80nEnabled = true
        cpu.tStates = 0
        return (cpu, mem)
    }

    // MARK: - Simple register ops

    func testSwapNib() {
        let (cpu, _) = makeCPU(program: [0xED, 0x23])
        cpu.A = 0x3C
        cpu.fetchAndExecute()
        XCTAssertEqual(cpu.A, 0xC3)
        XCTAssertEqual(cpu.PC, 2)
    }

    func testMirror() {
        let (cpu, _) = makeCPU(program: [0xED, 0x24])
        cpu.A = 0x80 // 1000_0000 -> 0000_0001
        cpu.fetchAndExecute()
        XCTAssertEqual(cpu.A, 0x01)
        cpu.PC = 0
        cpu.A = 0x55
        cpu.fetchAndExecute()
        XCTAssertEqual(cpu.A, 0xAA)
    }

    func testMulDE() {
        let (cpu, _) = makeCPU(program: [0xED, 0x30])
        cpu.DE = 0x0408 // D=0x04, E=0x08
        cpu.fetchAndExecute()
        XCTAssertEqual(cpu.DE, 0x0020) // 4 * 8
        XCTAssertEqual(cpu.PC, 2)
    }

    func testAddRRA() {
        let (cpu, _) = makeCPU(program: [0xED, 0x31, 0xED, 0x32, 0xED, 0x33])
        cpu.HL = 0x1000
        cpu.DE = 0x2000
        cpu.BC = 0x3000
        cpu.A = 0x0A
        cpu.fetchAndExecute() // ADD HL,A
        XCTAssertEqual(cpu.HL, 0x100A)
        cpu.fetchAndExecute() // ADD DE,A
        XCTAssertEqual(cpu.DE, 0x200A)
        cpu.fetchAndExecute() // ADD BC,A
        XCTAssertEqual(cpu.BC, 0x300A)
    }

    func testAddRRNN() {
        let (cpu, _) = makeCPU(program: [0xED, 0x34, 0xFF, 0x7F]) // ADD HL,0x7FFF (LE)
        cpu.HL = 1
        cpu.fetchAndExecute()
        XCTAssertEqual(cpu.HL, 0x8000)
        XCTAssertEqual(cpu.PC, 4)
    }

    func testPushNN() {
        let (cpu, mem) = makeCPU(program: [0xED, 0x8A, 0x7F, 0xFF]) // PUSH 0x7FFF (BE)
        cpu.SP = 0xFFFE
        cpu.fetchAndExecute()
        XCTAssertEqual(mem.peek(from: 0xFFFC), 0xFF, "low byte at SP-2 (Z80 stack order)")
        XCTAssertEqual(mem.peek(from: 0xFFFD), 0x7F, "high byte at SP-1 (Z80 stack order)")
        XCTAssertEqual(cpu.SP, 0xFFFC)
        XCTAssertEqual(cpu.PC, 4)
    }

    func testTestN() {
        let (cpu, _) = makeCPU(program: [0xED, 0x27, 0x0F])
        cpu.A = 0xFF
        cpu.F = 0x00
        cpu.fetchAndExecute()
        XCTAssertEqual(cpu.A, 0xFF, "TEST n must not modify A")
        XCTAssertEqual(cpu.F & cpu.zero, 0, "TEST 0x0F of 0xFF is non-zero, so Z is clear")
        XCTAssertNotEqual(cpu.F & cpu.halfCarry, 0, "TEST n sets H like AND")
    }

    // MARK: - Barrel shifts

    func testBSLA() {
        let (cpu, _) = makeCPU(program: [0xED, 0x28])
        cpu.DE = 0x0001
        cpu.B = 4
        cpu.fetchAndExecute()
        XCTAssertEqual(cpu.DE, 0x0010)
    }

    func testBSRA() {
        let (cpu, _) = makeCPU(program: [0xED, 0x29])
        cpu.DE = 0x8001
        cpu.B = 4
        cpu.fetchAndExecute()
        XCTAssertEqual(cpu.DE, 0xF800) // arithmetic fill
    }

    func testBSRL() {
        let (cpu, _) = makeCPU(program: [0xED, 0x2A])
        cpu.DE = 0x8001
        cpu.B = 4
        cpu.fetchAndExecute()
        XCTAssertEqual(cpu.DE, 0x0800)
    }

    func testBRLC() {
        let (cpu, _) = makeCPU(program: [0xED, 0x2C])
        cpu.DE = 0x8001
        cpu.B = 4
        cpu.fetchAndExecute()
        XCTAssertEqual(cpu.DE, 0x0018) // rotate left 4
    }

    // MARK: - NEXTREG

    func testNEXTREGWriteImmediate() {
        let (cpu, _) = makeCPU(program: [0xED, 0x91, 0x50, 0x1F])
        cpu.fetchAndExecute()
        XCTAssertEqual(cpu.nextRegWrites.count, 1)
        XCTAssertEqual(cpu.nextRegWrites[0].reg, 0x50)
        XCTAssertEqual(cpu.nextRegWrites[0].value, 0x1F)
        XCTAssertEqual(cpu.PC, 4)
    }

    func testNEXTREGWriteA() {
        let (cpu, _) = makeCPU(program: [0xED, 0x92, 0x12])
        cpu.A = 0xAB
        cpu.fetchAndExecute()
        XCTAssertEqual(cpu.nextRegWrites.count, 1)
        XCTAssertEqual(cpu.nextRegWrites[0].reg, 0x12)
        XCTAssertEqual(cpu.nextRegWrites[0].value, 0xAB)
        XCTAssertEqual(cpu.PC, 3)
    }

    // MARK: - Block ops

    func testLDIXTransparentCopy() {
        let (cpu, mem) = makeCPU(program: [0xED, 0xA4])
        mem.setByte(0xAA, at: 0x1000)
        mem.setByte(0xBB, at: 0x1001)
        cpu.HL = 0x1000
        cpu.DE = 0x2000
        cpu.BC = 3
        cpu.A = 0xAA // transparent key
        cpu.fetchAndExecute()
        XCTAssertEqual(mem.peek(from: 0x2000), 0x00, "source == key (0xAA) must be skipped")
        XCTAssertEqual(cpu.BC, 2)
        XCTAssertEqual(cpu.HL, 0x1001)
        XCTAssertEqual(cpu.DE, 0x2001)
    }

    func testLDIRXLoops() {
        let (cpu, mem) = makeCPU(program: [0xED, 0xB4])
        mem.setByte(0x11, at: 0x1000)
        mem.setByte(0x22, at: 0x1001)
        cpu.HL = 0x1000
        cpu.DE = 0x2000
        cpu.BC = 2
        cpu.A = 0xFF
        cpu.fetchAndExecute() // iter 1: BC 2->1, loops (PC -= 2 -> 0, re-point at ED B4)
        XCTAssertEqual(cpu.BC, 1)
        XCTAssertEqual(mem.peek(from: 0x2000), 0x11)
        XCTAssertEqual(cpu.PC, 0, "LDIRX repeats: PC re-points at the ED B4")
        cpu.fetchAndExecute() // iter 2: BC 1->0, exits (PC stays 2)
        XCTAssertEqual(cpu.BC, 0)
        XCTAssertEqual(mem.peek(from: 0x2001), 0x22)
        XCTAssertEqual(cpu.PC, 2, "LDIRX exits: PC advances past ED B4")
    }

    func testLDPIRXPattern() {
        let (cpu, mem) = makeCPU(program: [0xED, 0xB7])
        mem.setByte(0x10, at: 0x1000)
        cpu.HL = 0x1000
        cpu.DE = 0x2000
        cpu.BC = 3
        cpu.A = 0x00
        cpu.fetchAndExecute()
        XCTAssertEqual(mem.peek(from: 0x2000), 0x10, "pattern byte from (HL&FFF8)|(DE&7)")
        XCTAssertEqual(cpu.BC, 2)
    }

    func testOutinb() {
        let (cpu, mem) = makeCPU(program: [0xED, 0x90])
        mem.setByte(0x42, at: 0x1000)
        cpu.HL = 0x1000
        cpu.BC = 0xFE03 // port 0x03FE
        cpu.fetchAndExecute()
        XCTAssertEqual(cpu.HL, 0x1001)
        XCTAssertEqual(cpu.nextRegWrites.isEmpty, true)
    }

    // MARK: - Classic NOP when disabled

    func testZ80NDisabledIsNOP() {
        let (cpu, _) = makeCPU(program: [0xED, 0x23, 0xED, 0x91, 0x50, 0x1F])
        cpu.z80nEnabled = false
        cpu.A = 0x3C
        cpu.fetchAndExecute() // SWAPNIB as NOP (2,12)
        XCTAssertEqual(cpu.A, 0x3C, "A unchanged when Z80N disabled")
        XCTAssertEqual(cpu.PC, 2)
        cpu.fetchAndExecute() // NEXTREG as NOP: operands must NOT be consumed
        XCTAssertEqual(cpu.nextRegWrites.count, 0)
        XCTAssertEqual(cpu.PC, 4, "NOP consumes only the 2 opcode bytes")
    }
}