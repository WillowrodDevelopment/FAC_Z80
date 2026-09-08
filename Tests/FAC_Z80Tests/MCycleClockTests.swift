import XCTest
@testable import FAC_Z80

final class MCycleClockTests: XCTestCase {

    private func makeCPU(_ program: [UInt8]) -> (Z80, LoggingMemory) {
        let mem = LoggingMemory()
        mem.loadProgram(program, at: 0x0000)
        let cpu = Z80(memory: mem)
        cpu.PC = 0x0000
        return (cpu, mem)
    }

    private final class Recorder: MemoryAccessRecorder {
        var timestamps: [Int] = []
        var addresses: [UInt16] = []
        func record(_ access: RecordedMemoryAccess) {
            timestamps.append(access.tStateInFrame)
            addresses.append(access.address)
        }
    }

    func testLDAbsoluteTimestampsAccessAtCorrectOffsets() {
        let (cpu, mem) = makeCPU([0x3A, 0x34, 0x12])
        let rec = Recorder()
        cpu.accessRecorder = rec
        mem.setByte(0xAA, at: 0x1234)
        cpu.fetchAndExecute()
        XCTAssertEqual(rec.addresses, [0x0000, 0x0001, 0x0002, 0x1234])
        XCTAssertEqual(rec.timestamps, [0, 4, 7, 10])
        XCTAssertEqual(cpu.tStates, 13)
    }

    func testLDAbsoluteWithContentionShiftsSubsequentAccesses() {
        let (cpu, mem) = makeCPU([0x3A, 0x34, 0x12])
        let rec = Recorder()
        cpu.accessRecorder = rec
        let contention = AddressContention(delayedAddresses: [0x1234], delay: 4)
        cpu.contention = contention
        mem.setByte(0xAA, at: 0x1234)
        cpu.fetchAndExecute()
        XCTAssertEqual(rec.timestamps, [0, 4, 7, 14])
        XCTAssertEqual(cpu.tStates, 17)
    }

    func testCallInstructionTimestampsPushes() {
        let (cpu, _) = makeCPU([0xCD, 0x34, 0x12])
        let rec = Recorder()
        cpu.accessRecorder = rec
        cpu.SP = 0xFFFE
        cpu.fetchAndExecute()
        XCTAssertEqual(rec.timestamps, [0, 4, 7, 10, 13])
        XCTAssertEqual(cpu.tStates, 17)
        XCTAssertEqual(cpu.PC, 0x1234)
    }

    func testConditionalRetNotTakenHasNoReadAccesses() {
        let (cpu, _) = makeCPU([0xC0])
        let rec = Recorder()
        cpu.accessRecorder = rec
        cpu.F = 0x40 // Z set → not taken
        cpu.fetchAndExecute()
        XCTAssertEqual(rec.addresses.count, 1)
        XCTAssertEqual(cpu.tStates, 5)
    }

    func testBoundaryStraddlingInstructionWrapsContentionTState() {
        // LD A,(0x1234) with the read landing past the frame boundary must wrap
        // the t-state before the contention model sees it (the ULA preconditions
        // on a frame-relative position) — not precondition-crash.
        let (cpu, mem) = makeCPU([0x3A, 0x34, 0x12])
        cpu.tStates = 69_886 // near frame end; read@offset10 = 69896 crosses 69888
        let contention = FrameStrictContention(delay: 2)
        cpu.contention = contention
        mem.setByte(0xAA, at: 0x1234)
        cpu.fetchAndExecute()
        XCTAssertTrue(cpu.frameBoundaryHit)
    }
}

private final class AddressContention: BusContention {
    let delayedAddresses: Set<UInt16>
    let delay: Int
    init(delayedAddresses: Set<UInt16>, delay: Int) {
        self.delayedAddresses = delayedAddresses
        self.delay = delay
    }
    func delay(beginningAt tStateInFrame: Int, address: UInt16) -> Int {
        delayedAddresses.contains(address) ? delay : 0
    }
}

/// Mirrors the ULA's invariant: the frame t-state must be inside the frame.
/// Crashes (precondition) if the CPU ever passes an out-of-frame position.
private final class FrameStrictContention: BusContention {
    let delay: Int
    init(delay: Int) { self.delay = delay }
    func delay(beginningAt tStateInFrame: Int, address: UInt16) -> Int {
        precondition(tStateInFrame >= 0 && tStateInFrame < 69_888,
                     "contention t-state \(tStateInFrame) outside frame")
        return delay
    }
}