//
//  Z80+CB_OpCodes.swift
//  Fake-A-Chip
//
//  Created by Mike Hall on 23/05/2023.
//

import Foundation
import FAC_Common

extension Z80 {



    func opCodeCB() async {
        let opCode = next()
        let source = opCode & 0x07
        let target = opCode >> 3
        let sourceValue = valueFromSource(source: source)
        var ts = 4
        var mCycles = 2
        switch target {
        case 0x00: // rlc
            let carryMask: UInt8 = (sourceValue & 0x80) > 0 ? 0x01 : 0x00
            let value = (sourceValue << 1) | carryMask
            writeRegister(source, value: value)
            F = sz53pv(value) | carryMask


            case 0x01: // rrc
                let carryMask: UInt8 = sourceValue & 0x01
            let value = (sourceValue >> 1) | (carryMask > 0 ? 0x80 : 0x00)
            writeRegister(source, value: value)
            F = sz53pv(value) | carryMask

            case 0x02: // rl
                let carryMask: UInt8 = (sourceValue & 0x80) > 0 ? 0x01 : 0x00
                let value = (sourceValue << 1) | (F & carry)
                writeRegister(source, value: value)
                F = sz53pv(value) | carryMask

        case 0x03: // rr
            let carryMask: UInt8 = sourceValue & 0x01
        let value = (sourceValue >> 1) | ((F & carry) > 0 ? 0x80 : 0x00)
        writeRegister(source, value: value)
        F = sz53pv(value) | carryMask

        case 0x04: // sla
            let carryMask: UInt8 = (sourceValue & 0x81)
            let value = (sourceValue << 1) // | (carryMask & carry)
            writeRegister(source, value: value)
            F = sz53pv(value) | (carryMask > 1 ? 0x01 : 0x00)

        case 0x05: // sra
            let carryMask: UInt8 = sourceValue & 0x81
            let value = (sourceValue >> 1) | (carryMask & sign)
        writeRegister(source, value: value)
        F = sz53pv(value) | (carryMask & carry)

        case 0x06: // sll (UD)
            let carryMask: UInt8 = (sourceValue & 0x81)
            let value = (sourceValue << 1) | carry
            writeRegister(source, value: value)
            F = sz53pv(value) | (carryMask > 1 ? 0x01 : 0x00)

        case 0x07: // srr
            let carryMask: UInt8 = sourceValue & 0x81
            let value = (sourceValue >> 1)// | (carryMask & sign)
        writeRegister(source, value: value)
        F = sz53pv(value) | (carryMask & carry)

        case 0x08...0x0F: // Bit 0-7
            let bit = Int(target) - 8
            var carryMask: UInt8 = sourceValue.isSet(bit: bit) ? 0x00 : (zero | parityOverflow)
            if bit == 0x07 {
                carryMask = carryMask | (sourceValue & sign)
            }
            carryMask = carryMask | (F & carry)
            if source == 6 {
                carryMask = carryMask | bits53(memptr.highByte())
            } else {
                carryMask = carryMask | bits53(sourceValue)
            }
            F = halfCarry | carryMask

        case 0x10...0x17:  // Res 0-7
            let bit = Int(target) - 0x10
            writeRegister(source, value: sourceValue & ~(1 << bit))

        case 0x18...0x1F:  // Res 0-7
            let bit = Int(target) - 0x18
            writeRegister(source, value: sourceValue | (1 << bit))

        default:
            break
        }
        await mCyclesAndTStates(m: mCycles, t: ts)
    }
}
