import Foundation

// MARK: - Table-driven single-instruction dispatch
//
// A faithful table equivalent of `fetchAndExecute()`: reads the opcode, looks
// it up in the (migrated) main table, executes the handler, then runs the same
// epilogue. Prefix opcodes self-accumulate inside their sub-decoder and return
// (0, 0), so this epilogue mirrors the switch exactly.
//
// This is the validation path used by the oracle/equivalence tests. Once every
// family is migrated and proven byte-identical, `fetchAndExecute()` can be
// replaced by this method.

extension Z80 {

    /// Table-driven equivalent of `opCodeED()`: reads the ED operand, executes
    /// the migrated ED table handler, then accumulates. Used for validation and
    /// as the eventual production path.
    func opCodeEDViaTable() {
        let opCode = next()
        let info = opcodeTables.ed[Int(opCode)]
        let (m, t) = info.execute(self)
        accumulate(m: m, t: t)
    }

    /// Table-driven equivalent of `opCodeDDFD(index:)`: reads the DD/FD operand,
    /// executes the migrated DD/FD table handler, then accumulates.
    func opCodeDDFDViaTable(index: Z8016BitRegister) {
        let opCode = next()
        let table = index == .IX ? opcodeTables.dd : opcodeTables.fd
        let info = table[Int(opCode)]
        let (m, t) = info.execute(self)
        accumulate(m: m, t: t)
    }

    /// Table-driven equivalent of `opCodeDDFDCB(index:)`: resolves the
    /// displaced address (displacement precedes the CB operand), executes the
    /// migrated DDFDCB table handler, then accumulates.
    func opCodeDDFDCBViaTable(index: Z8016BitRegister) {
        let disIndex = displacedIndex(index, displacement: next())
        let opCode = next()
        let info = opcodeTables.ddfdcb[Int(opCode)]
        let (m, t) = info.execute(self, disIndex)
        accumulate(m: m, t: t)
    }

    func fetchAndExecuteViaTable() {
        if isInHaltState {
            accumulate(m: 1, t: 4)
            postInstruction(t: 4)
            return
        }
        lastFetchPC = PC
        if controller.breakpointsEnabled, !controller.isStepping, controller.containsBreakpoint(PC) {
            controller.breakpointHit = PC
            controller.processorSpeed = .paused
            return
        }

        let opCode = next()
        let info = opcodeTables.main[Int(opCode)]
        let (m, t) = info.execute(self)
        accumulate(m: m, t: t)
        postInstruction(t: t)
    }
}
