//
//  Z80+OpCodes.swift
//  Fake-A-Chip
//
//  Created by Mike Hall on 20/05/2023.
//

import Foundation
import FAC_Common

extension Z80 {

    /// Executes a single instruction, dispatched through the migrated opcode
    /// tables. Each table entry performs the instruction body and returns its
    /// actual (M-cycle, t-state) cost, which is then accumulated and passed to
    /// the post-instruction hook — exactly matching the original switch-based
    /// decoder (proven byte-for-byte equivalent by the oracle/equivalence
    /// tests).
    public func fetchAndExecute() {
        if isInHaltState {
            instructionBaseTStates = tStates
            instructionDelay = 0
            instructionLastOffset = 0
            instructionAccessIndex = 0
            currentInstructionPattern = nil
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

        instructionBaseTStates = tStates
        instructionDelay = 0
        instructionLastOffset = 0
        instructionAccessIndex = 0
        currentInstructionPattern = nil
        let opCode = next()
        let info = opcodeTables.main[Int(opCode)]
        currentInstructionPattern = info.accessPattern
        instructionAccessIndex = info.accessPattern.steps.isEmpty ? 0 : 1
        let (m, t) = info.execute(self)
        if m != 0 || t != 0 {
            accumulate(m: m, t: t - instructionLastOffset)
        } else {
            // Prefix (CB/ED/DD/FD) already self-accumulated via per-M-cycle dispatch
            // Do not double-count; outer's lastOffset is from inner's pattern
        }
        postInstruction(t: t)
    }
}
