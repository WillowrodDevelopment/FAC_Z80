import Foundation

// MARK: - Opcode dispatch table infrastructure
//
// This is the foundation of the switch→table refactor. Each decoded opcode
// becomes an `OpcodeInfo` whose handler performs the instruction body and
// reports the instruction's actual (M-cycle, t-state) cost, so the shared
// epilogue can accumulate cycles and run post-instruction hooks uniformly.
//
// The table also carries the instruction's memory-access *pattern* (ordered
// fetch/read/write M-cycles) which the future contention model consumes.

/// The kind of a single memory bus access performed by an instruction.
public enum MemAccessKind: Sendable, Equatable {
    /// Opcode / operand byte fetch (M1 or operand fetch).
    case fetch
    /// A memory read (byte or word).
    case read
    /// A memory write (byte or word).
    case write
    /// An I/O port access (IN or OUT).
    case io
}

/// One step of an instruction's memory-access pattern: what kind of access and
/// at what offset (in t-states) from the start of the instruction it occurs.
public struct MemAccessStep: Sendable, Equatable {
    public let kind: MemAccessKind
    public let tStateOffset: Int

    public init(_ kind: MemAccessKind, _ tStateOffset: Int) {
        self.kind = kind
        self.tStateOffset = tStateOffset
    }
}

/// The ordered memory-access pattern of an instruction, used by the contention
/// model to apply wait states at the correct points in the instruction.
public struct AccessPattern: Sendable, Equatable {
    public let steps: [MemAccessStep]

    public init(steps: [MemAccessStep]) {
        self.steps = steps
    }

    /// An instruction with no memory accesses (e.g. register-only ALU ops).
    public static let none = AccessPattern(steps: [])
    /// A single opcode fetch (all instructions start with one).
    public static let fetchOnly = AccessPattern(steps: [MemAccessStep(.fetch, 0)])
}

/// A single decoded instruction: how to execute it and what it costs.
public struct OpcodeInfo {
    /// Executes the instruction body and returns the actual cycle cost.
    /// Returning `(m, t)` (rather than a fixed field) lets handlers vary
    /// their cost by outcome — e.g. DJNZ (8 vs 13 t-states), conditional
    /// CALL/RET/JR, block-repeat ops — exactly as the switch does today.
    public let execute: (Z80) -> (m: Int, t: Int)
    /// The ordered memory-access pattern of this instruction.
    public var accessPattern: AccessPattern

    public init(execute: @escaping (Z80) -> (m: Int, t: Int), accessPattern: AccessPattern = .fetchOnly) {
        self.execute = execute
        self.accessPattern = accessPattern
    }
}

/// A DDFDCB instruction handler: executes against `(index+d)`, which the
/// dispatcher has already resolved (the displacement precedes the CB operand
/// in the byte stream, so it cannot be re-read inside the handler).
public struct DDFDCBOpcodeInfo {
    public let execute: (Z80, UInt16) -> (m: Int, t: Int)
    public var accessPattern: AccessPattern

    public init(execute: @escaping (Z80, UInt16) -> (m: Int, t: Int), accessPattern: AccessPattern = .fetchOnly) {
        self.execute = execute
        self.accessPattern = accessPattern
    }
}

/// Builds and holds the 256-entry dispatch tables for a Z80 instance.
///
/// Each table is indexed by an opcode byte (0…255). Prefix decoders (CB, ED,
/// DD/FD, DDFDCB) have their own tables; the main table dispatches to them.
public final class OpcodeTableSet {
    public let main: [OpcodeInfo]
    public let cb: [OpcodeInfo]
    public let ed: [OpcodeInfo]
    public let dd: [OpcodeInfo]
    public let fd: [OpcodeInfo]
    public let ddfdcb: [DDFDCBOpcodeInfo]

    public init(main: [OpcodeInfo], cb: [OpcodeInfo], ed: [OpcodeInfo], dd: [OpcodeInfo], fd: [OpcodeInfo], ddfdcb: [DDFDCBOpcodeInfo]) {
        precondition(main.count == 256, "Main opcode table must have 256 entries")
        precondition(cb.count == 256, "CB opcode table must have 256 entries")
        precondition(ed.count == 256, "ED opcode table must have 256 entries")
        precondition(dd.count == 256, "DD opcode table must have 256 entries")
        precondition(fd.count == 256, "FD opcode table must have 256 entries")
        precondition(ddfdcb.count == 256, "DDFDCB opcode table must have 256 entries")
        self.main = main
        self.cb = cb
        self.ed = ed
        self.dd = dd
        self.fd = fd
        self.ddfdcb = ddfdcb
    }

    /// The default, switch-equivalent tables. This is the reference the oracle
    /// validates against; migrated families are swapped in as they land.
    public static func defaultTables() -> OpcodeTableSet {
        OpcodeTableSet(
            main: buildMainTable(),
            cb: buildCBTable(),
            ed: buildEDTable(),
            dd: buildDDFDTable(index: .IX),
            fd: buildDDFDTable(index: .IY),
            ddfdcb: buildDDFDCBTable()
        )
    }
}
