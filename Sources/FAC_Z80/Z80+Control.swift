//
//  Z80+Control.swift
//  Fake-A-Chip
//
//  Created by Mike Hall on 20/05/2023.
//

import Foundation

extension Z80 {
    // PC and SP Specific
    
    func next() -> UInt8 {
        let opcode = memoryRead(from: PC)
        PC = PC &+ 1
        return opcode
    }
    
    func nextWord() -> UInt16 {
        let low = next()
        let high = next()
        return (UInt16(high) * 256) + UInt16(low)
    }
    
    func mCyclesAndTStates(m: Int, t: Int) {
        tStates += t
        let bit7 = R & 0x80
        R = ((R &+ UInt8(m)) & 0x7F) | bit7
        if tStates >= tStatesPerFrame {
            tStates = 0
            render()
        }
    }
    
    func previous(value: UInt16 = 1) {
        PC -= value
    }
    
    func relativeJump(twos: UInt8) {
        let jump = PC &+ UInt16(twos & 0x7f) &- UInt16(twos & 0x80)
        PC = jump
        memptr = PC
    }
    
    func push(_ value: UInt16) {
        SP = SP &- 2
        memoryWriteWord(to: SP, value: value)
    }
    
    func pop() -> UInt16 {
        let rtn = memoryReadWord(from: SP)
        SP = SP &+ 2
        return rtn
    }
    
    func ret() {
        PC = pop()
        memptr = PC
    }
    
    func jump(_ target: UInt16) {
        PC = target
        memptr = PC
    }
    
    func resetProcessor() {
        A = 0x00
        // Register Pairs
        BC = 0x00
        DE = 0x00
        HL = 0x00
        // Shadow Register Pair
        AF2 = 0x0
        BC2 = 0x0
        DE2 = 0x0
        HL2 = 0x0
        // Control Registers
        PC = 0x00
        SP = 0x00
        // Index Registers
        IX = 0x00
        IY = 0x00
        // Special Registers
        I = 0x00
        R = 0x00
        // Spare Registers
        SPARE16 = 0x00
        SPARE8 = 0x00
        
        // **** Control ****
        tStates = 0
        interuptMode = 1
        iff1 = 0x00
        iff2 = 0x00

        activeHardwarePorts = [:]
    }
}
