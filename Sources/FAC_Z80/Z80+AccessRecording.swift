import Foundation

// MARK: - Memory access recording (contention hook)
//
// To apply ULA contention, the machine needs to know the ordered memory
// accesses each instruction performs *and* the frame t-state at which each
// occurs. This file defines the recorder surface and a wrapper delegate that
// intercepts every memory read/write so the CPU can report them.
//
// The recorder is a pluggable hook on `Z80` (see `Z80.accessRecorder`). When
// set, opcode fetches, operand reads, data reads/writes and I/O accesses are
// reported with the CPU's current frame t-state. A machine wires its
// `MemoryContentionModel` (from FAC_ULA) into a recorder to insert wait
// states at the correct points.

/// Receives each memory bus access with the frame t-state at which it begins.
public protocol MemoryAccessRecorder: AnyObject {
    /// Called for every memory/I/O access. `tStateInFrame` is the absolute
    /// frame t-state at which the access's memory cycle begins.
    func record(_ access: RecordedMemoryAccess)
}

/// Supplies ULA bus-contention wait states for a machine.
///
/// FAC_Z80 deliberately does NOT depend on FAC_ULA (the ULA is Spectrum-only),
/// so the contention model is injected through this protocol. A machine (e.g.
/// the app's ZXSpectrum) supplies a conformer backed by FAC_ULA's
/// `MemoryContentionModel`.
public protocol BusContention: AnyObject {
    /// Wait states the ULA inserts for a memory access to `address` whose
    /// memory cycle begins at absolute frame t-state `tStateInFrame`.
    func delay(beginningAt tStateInFrame: Int, address: UInt16) -> Int
}

/// A single recorded access.
public struct RecordedMemoryAccess: Sendable {
    public let kind: MemAccessKind
    public let address: UInt16
    public let tStateInFrame: Int

    public init(kind: MemAccessKind, address: UInt16, tStateInFrame: Int) {
        self.kind = kind
        self.address = address
        self.tStateInFrame = tStateInFrame
    }
}

/// Wraps a `MemoryDelegate` and reports every access to a recorder, forwarding
/// the actual read/write to the wrapped delegate. The CPU reference is weak and
/// assigned after the Z80 finishes initialising (to avoid a self-reference
/// during init).
final class RecordingMemoryDelegate: MemoryDelegate {
    private let wrapped: MemoryDelegate
    private weak var cpu: Z80?

    init(wrapping wrapped: MemoryDelegate) {
        self.wrapped = wrapped
    }

    func attach(cpu: Z80) {
        self.cpu = cpu
    }

    func write(to address: UInt16, value: UInt8) {
        if cpu?.needsAccessRecording == true {
            cpu?.recordAccess(.write, address: address)
        }
        wrapped.write(to: address, value: value)
    }

    func read(from address: UInt16) -> UInt8 {
        if cpu?.needsAccessRecording == true {
            cpu?.recordAccess(.read, address: address)
        }
        return wrapped.read(from: address)
    }

    func writeWord(to address: UInt16, value: UInt16) {
        if cpu?.needsAccessRecording == true {
            cpu?.recordAccess(.write, address: address)
            cpu?.recordAccess(.write, address: address &+ 1)
        }
        wrapped.writeWord(to: address, value: value)
    }

    func readWord(from address: UInt16) -> UInt16 {
        if cpu?.needsAccessRecording == true {
            cpu?.recordAccess(.read, address: address)
            cpu?.recordAccess(.read, address: address &+ 1)
        }
        return wrapped.readWord(from: address)
    }

    func fetchBatch(from address: Int, size: Int) -> [UInt8] {
        wrapped.fetchBatch(from: address, size: size)
    }

    func peek(from address: UInt16) -> UInt8 {
        wrapped.peek(from: address)
    }
}
