import Foundation
@testable import FAC_Z80

/// A memory image with an execution log, used by the oracle to capture every
/// memory read/write an instruction performs (in order). This is the "access
/// pattern" record that the table refactor must preserve and that the future
/// contention model will consume.
final class LoggingMemory: MemoryDelegate {
    private(set) var ram: [UInt8]
    /// Ordered list of memory accesses performed since the last reset.
    private(set) var accessLog: [MemAccess] = []

    init(size: Int = 0x10000, fill: UInt8 = 0x00) {
        self.ram = [UInt8](repeating: fill, count: size)
    }

    func write(to address: UInt16, value: UInt8) {
        ram[Int(address)] = value
        accessLog.append(.write(address, value))
    }
    func read(from address: UInt16) -> UInt8 {
        accessLog.append(.read(address))
        return ram[Int(address)]
    }
    func writeWord(to address: UInt16, value: UInt16) {
        write(to: address, value: value.lowByte())
        write(to: address &+ 1, value: value.highByte())
    }
    func readWord(from address: UInt16) -> UInt16 {
        let low = read(from: address)
        let high = read(from: address &+ 1)
        return (UInt16(high) << 8) | UInt16(low)
    }
    func fetchBatch(from address: Int, size: Int) -> [UInt8] {
        Array(ram[address..<(address + size)])
    }

    /// Load a program at the given address and reset the log.
    func loadProgram(_ bytes: [UInt8], at address: UInt16 = 0x0000) {
        for (i, byte) in bytes.enumerated() {
            ram[Int(address) + i] = byte
        }
        accessLog.removeAll()
    }

    /// Write a single byte without recording it in the access log (for setup).
    func setByte(_ value: UInt8, at address: UInt16) {
        ram[Int(address)] = value
    }

    /// Read a single byte without recording it in the access log (for setup).
    func peek(_ address: UInt16) -> UInt8 {
        ram[Int(address)]
    }

    func resetLog() {
        accessLog.removeAll()
    }
}

enum MemAccess: Equatable {
    case read(UInt16)
    case write(UInt16, UInt8)

    var address: UInt16 {
        switch self {
        case .read(let a), .write(let a, _): return a
        }
    }
}

/// A complete CPU state snapshot captured after one instruction.
struct CPUSnapshot: Equatable {
    var pc: UInt16
    var af: UInt16
    var bc: UInt16
    var de: UInt16
    var hl: UInt16
    var af2: UInt16
    var bc2: UInt16
    var de2: UInt16
    var hl2: UInt16
    var ix: UInt16
    var iy: UInt16
    var sp: UInt16
    var spare16: UInt16
    var i: UInt8
    var r: UInt8
    var iff1: UInt8
    var iff2: UInt8
    var im: UInt8
    var tStates: Int
    var memptr: UInt16
    var lastFetchPC: UInt16

    init(cpu: Z80) {
        pc = cpu.PC
        af = cpu.AF
        bc = cpu.BC
        de = cpu.DE
        hl = cpu.HL
        af2 = cpu.AF2
        bc2 = cpu.BC2
        de2 = cpu.DE2
        hl2 = cpu.HL2
        ix = cpu.IX
        iy = cpu.IY
        sp = cpu.SP
        spare16 = cpu.SPARE16
        i = cpu.I
        r = cpu.R
        iff1 = cpu.iff1
        iff2 = cpu.iff2
        im = UInt8(cpu.interuptMode)
        tStates = cpu.tStates
        memptr = cpu.memptr
        lastFetchPC = cpu.lastFetchPC
    }
}

/// The oracle: runs a program one instruction at a time on a bare Z80 and
/// captures a per-instruction trace of (pre-state, post-state, memory log).
/// The trace captured from the *current* switch implementation is the golden
/// reference the table refactor must reproduce byte-for-byte.
enum Oracle {
    /// Execute `cpu` for `instructions` instructions, capturing a snapshot
    /// after each. Memory accesses are accumulated per instruction and
    /// recorded as part of the trace.
    static func run(
        _ cpu: Z80,
        memory: LoggingMemory,
        instructions: Int
    ) -> [OracleStep] {
        var trace: [OracleStep] = []
        for _ in 0..<instructions {
            let pre = CPUSnapshot(cpu: cpu)
            memory.resetLog()
            cpu.fetchAndExecute()
            let accessLog = memory.accessLog
            let post = CPUSnapshot(cpu: cpu)
            trace.append(OracleStep(pre: pre, post: post, memory: accessLog))
            if cpu.isInHaltState && pre.pc == cpu.PC {
                // HALT idles; to avoid infinite identical steps, stop early
                // only if we've produced a HALT-step (the caller controls count).
                continue
            }
        }
        return trace
    }
}

struct OracleStep: Equatable {
    let pre: CPUSnapshot
    let post: CPUSnapshot
    let memory: [MemAccess]
}
