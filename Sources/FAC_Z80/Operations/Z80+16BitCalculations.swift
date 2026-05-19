//
//  Z80+16BitCalculations.swift
//  Fake-A-Chip
//
//  Created by Mike Hall on 23/05/2023.
//

import Foundation

extension Z80 {
    func inc(pair: Z80RegisterPair) {
        switch pair {
        case .BC:
            BC = BC &+ 1
        case .DE:
            DE = DE &+ 1
        case .HL:
            HL = HL &+ 1
        case .AF:
            break
        }
    }

    func add(pair: Z80RegisterPair, value: UInt16) {
        switch pair {
        case .BC:
            BC = BC &+ value
        case .DE:
            DE = DE &+ value
        case .HL:
            HL = HL &+ value
        case .AF:
            break
        }
    }

    func displacedIndex(_ index: Z8016BitRegister, displacement: UInt8) -> UInt16 {
        var indexValue: UInt16 = 0x00
        switch index {
        case .PC:
            indexValue = PC
        case .SP:
            indexValue = SP
        case .IX:
            indexValue = IX
        case .IY:
            indexValue = IY
        case .SPARE:
            indexValue = SPARE16
        }
        let displaced = indexValue &+ UInt16(displacement & 0x7f) &- UInt16(displacement & 0x80)
        memptr = displaced
        return displaced
    }
}
