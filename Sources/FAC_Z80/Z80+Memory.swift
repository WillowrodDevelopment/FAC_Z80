//
//  Z80+Memory.swift
//  Fake-A-Chip
//
//  Created by Mike Hall on 23/05/2023.
//

import Foundation
import FAC_Common

extension Z80 {
    public func memoryWrite(to: UInt16, value: UInt8) {
        // Should protect ROM for Sinclair computers
        memory[Int(to)] = value
    }

    func memoryRead(from: UInt16) -> UInt8 {
        return memory[Int(from)]
    }

    func memoryWriteWord(to: UInt16, value: UInt16) {
        // Should protect ROM for Sinclair computers
        memory[Int(to)] = value.lowByte()
        memory[Int(to &+ 1)] = value.highByte()
    }

    func memoryReadWord(from: UInt16) -> UInt16 {
        let low = memory[Int(from)]
        let high = memory[Int(from &+ 1)]
        return (UInt16(high) * 256) + UInt16(low)
    }

}
