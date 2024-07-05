//
//  Z80+DDFDCB_OpCodes.swift
//  Fake-A-Chip
//
//  Created by Mike Hall on 01/06/2023.
//

import Foundation
import FAC_Common

extension Z80 {
    func opCodeDDFDCB(index: Z8016BitRegister) {
        let disIndex = displacedIndex(index, displacement: next())
        let opCode = next()
        let source = opCode & 0x07
        let target = opCode >> 3
        let sourceValue = memoryRead(from: disIndex)
        var ts = 23
        var mCycles = 2
        switch target {
        case 0x00: // rlc
            let carryMask: UInt8 = (sourceValue & 0x80) > 0 ? 0x01 : 0x00
            let value = (sourceValue << 1) | carryMask
            memoryWrite(to: disIndex, value: value)
            if source != 0x06 {
                writeRegister(source, value: value)
            }
            F = sz53pv(value) | carryMask


            case 0x01: // rrc
                let carryMask: UInt8 = sourceValue & 0x01
            let value = (sourceValue >> 1) | (carryMask > 0 ? 0x80 : 0x00)
            memoryWrite(to: disIndex, value: value)
            if source != 0x06 {
                writeRegister(source, value: value)
            }
            F = sz53pv(value) | carryMask

            case 0x02: // rl
                let carryMask: UInt8 = (sourceValue & 0x80) > 0 ? 0x01 : 0x00
                let value = (sourceValue << 1) | (F & carry)
            memoryWrite(to: disIndex, value: value)
            if source != 0x06 {
                writeRegister(source, value: value)
            }
                F = sz53pv(value) | carryMask

        case 0x03: // rr
            let carryMask: UInt8 = sourceValue & 0x01
        let value = (sourceValue >> 1) | ((F & carry) > 0 ? 0x80 : 0x00)
            memoryWrite(to: disIndex, value: value)
            if source != 0x06 {
                writeRegister(source, value: value)
            }
        F = sz53pv(value) | carryMask

        case 0x04: // sla
            let carryMask: UInt8 = (sourceValue & 0x81)
            let value = (sourceValue << 1) // | (carryMask & carry)
            memoryWrite(to: disIndex, value: value)
            if source != 0x06 {
                writeRegister(source, value: value)
            }
            F = sz53pv(value) | (carryMask > 1 ? 0x01 : 0x00)

        case 0x05: // sra
            let carryMask: UInt8 = sourceValue & 0x81
            let value = (sourceValue >> 1) | (carryMask & sign)
            memoryWrite(to: disIndex, value: value)
            if source != 0x06 {
                writeRegister(source, value: value)
            }
        F = sz53pv(value) | (carryMask & carry)

        case 0x06: // sll (UD)
            let carryMask: UInt8 = (sourceValue & 0x81)
            let value = (sourceValue << 1) | carry
            memoryWrite(to: disIndex, value: value)
            if source != 0x06 {
                writeRegister(source, value: value)
            }
            F = sz53pv(value) | (carryMask > 1 ? 0x01 : 0x00)

        case 0x07: // srr
            let carryMask: UInt8 = sourceValue & 0x81
            let value = (sourceValue >> 1)// | (carryMask & sign)
            memoryWrite(to: disIndex, value: value)
            if source != 0x06 {
                writeRegister(source, value: value)
            }
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
                carryMask = carryMask | bits53(disIndex.highByte())
            }
            F = halfCarry | carryMask
ts = 20

        case 0x10...0x17:  // Res 0-7
            let bit = Int(target) - 0x10
            let value = sourceValue & ~(1 << bit)
            memoryWrite(to: disIndex, value: value)
            if source != 0x06 {
                writeRegister(source, value: value)
            }

        case 0x18...0x1F:  // Res 0-7
            let bit = Int(target) - 0x18
            let value = sourceValue | (1 << bit)
            memoryWrite(to: disIndex, value: value)
            if source != 0x06 {
                writeRegister(source, value: value)
            }

        default:
            break
        }
        mCyclesAndTStates(m: mCycles, t: ts)
    }
    }
