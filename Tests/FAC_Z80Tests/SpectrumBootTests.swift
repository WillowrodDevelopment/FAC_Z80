import XCTest
@testable import FAC_Z80

/// Boot regression guard: loads the real 48K ROM and runs the CPU through the
/// boot sequence. Any future timing/dispatch change that traps on Spectrum boot
/// (e.g. a precondition failure, negative cycle count, or index crash) will
/// fail here before reaching games.
final class SpectrumBootTests: XCTestCase {

    private static let romURL = URL(
        fileURLWithPath: "../Fake-A-Chip/Fake-A-Chip/Computers/Sinclair/Spectrum/ROMs/ZX48k.rom"
    )

    private func loadROM() -> [UInt8]? {
        guard let data = try? Data(contentsOf: Self.romURL) else {
            return nil
        }
        return [UInt8](data)
    }

    /// Runs the 48K boot for a fixed number of instructions and asserts the
    /// CPU stays sane (no trap). Interrupts are not serviced here, so the ROM
    /// reaches its HALT wait loop; the test still exercises the whole boot init.
    func test48KBootRunsWithoutCrashing() throws {
        guard let rom = loadROM() else {
            throw XCTSkip("ZX48k.rom not found at \(Self.romURL.path)")
        }

        let mem = LoggingMemory()
        mem.loadProgram(rom, at: 0x0000)
        let cpu = Z80(memory: mem)
        cpu.PC = 0x0000
        cpu.SP = 0xFFFF

        for _ in 0..<50_000 {
            cpu.fetchAndExecute()
        }

        // The CPU must have executed a sane amount of work and stayed inside
        // the 64K space (PC wrapping to 0 is expected from the ROM's loop).
        XCTAssertGreaterThan(cpu.tStates, 0)
    }

    func test48KBootIsDeterministicAcrossRuns() throws {
        guard let rom = loadROM() else {
            throw XCTSkip("ZX48k.rom not found")
        }
        func run() -> (pc: UInt16, tStates: Int) {
            let mem = LoggingMemory()
            mem.loadProgram(rom, at: 0x0000)
            let cpu = Z80(memory: mem)
            cpu.PC = 0x0000
            cpu.SP = 0xFFFF
            for _ in 0..<20_000 {
                cpu.fetchAndExecute()
            }
            return (cpu.PC, cpu.tStates)
        }
        let a = run()
        let b = run()
        XCTAssertEqual(a.pc, b.pc)
        XCTAssertEqual(a.tStates, b.tStates)
    }
}