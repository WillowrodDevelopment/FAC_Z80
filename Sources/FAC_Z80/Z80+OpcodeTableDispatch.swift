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

    // MARK: - Per-M-cycle prefix dispatch (M1)

    func opCodeCBWithPattern() {
        let opPeek = memory.peek(from: PC)
        let info = opcodeTables.cb[Int(opPeek)]
        currentInstructionPattern = info.accessPattern
        instructionAccessIndex = 1
        let (m, t) = info.execute(self)
        accumulate(m: m, t: t - instructionLastOffset)
    }

    func opCodeEDWithPattern() {
        let opPeek = memory.peek(from: PC)
        let info = opcodeTables.ed[Int(opPeek)]
        currentInstructionPattern = info.accessPattern
        instructionAccessIndex = 1
        let (m, t) = info.execute(self)
        accumulate(m: m, t: t - instructionLastOffset)
    }

    func opCodeDDFDWithPattern(index: Z8016BitRegister) {
        let opPeek = memory.peek(from: PC)
        if opPeek == 0xCB {
            // DDFDCB 4-byte: DD CB d op — PC at CB
            let ddfOpPeek = memory.peek(from: PC &+ 2)
            let ddfInfo = opcodeTables.ddfdcb[Int(ddfOpPeek)]
            currentInstructionPattern = ddfInfo.accessPattern
            instructionAccessIndex = 1 // next is CB at 4
            let _ = next() // CB
            let d = next() // d at 7
            let opCode = next() // op at 10
            let disIndex = displacedIndex(index, displacement: d)
            let info = opcodeTables.ddfdcb[Int(opCode)]
            let (m, t) = info.execute(self, disIndex)
            accumulate(m: m, t: t - instructionLastOffset)
            return
        }
        let table = index == .IX ? opcodeTables.dd : opcodeTables.fd
        let info = table[Int(opPeek)]
        currentInstructionPattern = info.accessPattern
        instructionAccessIndex = 1
        let (m, t) = info.execute(self)
        accumulate(m: m, t: t - instructionLastOffset)
    }

    func opCodeDDFDCBWithPattern(index: Z8016BitRegister) {
        // Called from DDFD table's CB entry — PC at d (CB already consumed as DD operand)
        let opPeek = memory.peek(from: PC &+ 1)
        let info = opcodeTables.ddfdcb[Int(opPeek)]
        currentInstructionPattern = info.accessPattern
        instructionAccessIndex = 2 // DD at 0 and CB at 4 already consumed, next is d at 7
        let d = next()
        let opCode = next()
        let disIndex = displacedIndex(index, displacement: d)
        let ddfInfo = opcodeTables.ddfdcb[Int(opCode)]
        let (m, t) = ddfInfo.execute(self, disIndex)
        accumulate(m: m, t: t - instructionLastOffset)
    }

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
