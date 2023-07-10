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
        let oPC = PC
        let opcode = memoryRead(from: PC)
//        if stack.count >= 50 {
//            stack.removeFirst()
//        }
//        stack.append(oPC)
//        if oPC == 0x0008 {
//            stack.forEach{opcode in
//                print("\(opcode.hex())")
//            }
//            print("Error!")
//        }
        PC = PC &+ 1
        return opcode
    }
    
    func nextWord() -> UInt16 {
        let low = next()
        let high = next()
        return (UInt16(high) * 256) + UInt16(low)
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
//        stack.append(value)
//        controlDelegate?.updateStack(stack)
    }
    
    func pop() -> UInt16 {
//        if stackSize == 0 {
//            logDelegate?.logError("Stack overflow")
//        } else {
//            stack.removeLast()
//            controlDelegate?.updateStack(stack)
//        }
        let rtn = memoryReadWord(from: SP)
        SP = SP &+ 2
        stackSize -= 1
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
    
    public func resetProcessor() {
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
        updatePort(port: 0xfe, bit: 1, set: false)
        updatePort(port: 0xfd, bit: 1, set: false)
        updatePort(port: 0xfb, bit: 1, set: false)
        updatePort(port: 0xf7, bit: 1, set: false)
        updatePort(port: 0xef, bit: 1, set: false)
        updatePort(port: 0xdf, bit: 1, set: false)
        updatePort(port: 0xbf, bit: 1, set: false)
        updatePort(port: 0x7f, bit: 1, set: false)
    }
}
