import XCTest
@testable import FAC_Z80

/// A recorder that collects accesses for assertions.
private final class CollectingRecorder: MemoryAccessRecorder {
    var accesses: [RecordedMemoryAccess] = []
    func record(_ access: RecordedMemoryAccess) {
        accesses.append(access)
    }
}

/// Verifies the access-pattern reporting: the recorder receives the ordered
/// memory/I/O accesses each instruction performs, tagged with the frame
/// t-state at which they occur.
final class AccessRecordingTests: XCTestCase {

    private func makeCPU(_ program: [UInt8]) -> (Z80, CollectingRecorder) {
        let mem = LoggingMemory()
        mem.loadProgram(program, at: 0x0000)
        let cpu = Z80(memory: mem)
        cpu.PC = 0x0000
        let recorder = CollectingRecorder()
        cpu.accessRecorder = recorder
        return (cpu, recorder)
    }

    func testSingleByteOpcodeRecordsOneRead() {
        let (cpu, recorder) = makeCPU([0x00]) // NOP
        cpu.fetchAndExecute()
        XCTAssertEqual(recorder.accesses.count, 1)
        XCTAssertEqual(recorder.accesses[0].kind, .read)
        XCTAssertEqual(recorder.accesses[0].address, 0x0000)
        XCTAssertEqual(recorder.accesses[0].tStateInFrame, 0)
    }

    func testImmediateInstructionRecordsOperandReads() {
        let (cpu, recorder) = makeCPU([0x3E, 0x55]) // LD A,0x55
        cpu.fetchAndExecute()
        XCTAssertEqual(recorder.accesses.count, 2)
        XCTAssertEqual(recorder.accesses[0].kind, .read)
        XCTAssertEqual(recorder.accesses[0].address, 0x0000)
        XCTAssertEqual(recorder.accesses[1].kind, .read)
        XCTAssertEqual(recorder.accesses[1].address, 0x0001)
    }

    func testMemoryReadWriteIsRecorded() {
        let (cpu, recorder) = makeCPU([0x3E, 0xAA, 0x32, 0x00, 0x40]) // LD A,0xAA; LD (0x4000),A
        cpu.fetchAndExecute() // LD A,0xAA
        recorder.accesses.removeAll()
        cpu.fetchAndExecute() // LD (0x4000),A
        // fetches: opcode 0x32, low 0x00, high 0x40, then write to 0x4000
        XCTAssertEqual(recorder.accesses.count, 4)
        XCTAssertTrue(recorder.accesses.contains { $0.kind == .write && $0.address == 0x4000 })
    }

    func testPortIOIsRecordedAsIO() {
        let (cpu, recorder) = makeCPU([0xD3, 0xFE]) // OUT (0xFE),A
        cpu.fetchAndExecute()
        XCTAssertTrue(recorder.accesses.contains { $0.kind == .io })
    }

    func testTStatesAdvanceAcrossInstructions() {
        let (cpu, recorder) = makeCPU([0x00, 0x00]) // NOP, NOP
        cpu.fetchAndExecute() // 4 t-states
        recorder.accesses.removeAll()
        cpu.fetchAndExecute()
        XCTAssertEqual(recorder.accesses[0].tStateInFrame, 4)
    }
}
