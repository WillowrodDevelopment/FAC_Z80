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
