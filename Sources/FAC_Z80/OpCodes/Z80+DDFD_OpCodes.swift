//
//  Z80+DD_OpCodes.swift
//  Fake-A-Chip
//
//  Created by Mike Hall on 23/05/2023.
//

import Foundation

extension Z80 {
    func opCodeDDFD(index: Z8016BitRegister) {
        var ts = 8
        var mCycles = 2
        let indexValue = valueOfIndex(index: index)
        let opCode = next()
        switch opCode {
        case 0x04: // inc B (UD)
            inc(.B)

        case 0x05: // dec B (UD)
            dec(.B)

        case 0x06: // ld b,n (UD)
            B = next()
            ts = 11

        case 0x09: // add index, bc
            let addtemp = halfCarryOverflowCalculationAdd16Bit(value: indexValue, amount: BC)
            let carryMask: UInt8 = indexValue > addtemp.value ? 0x01 : 0x00
            writeIndex(index, value: addtemp.value)
            F = preserve(sign, zero, parityOverflow) | addtemp.halfCarryMask | carryMask | bits53(addtemp.value.highByte())
            memptr = indexValue &+ 1
            ts = 15

        case 0x0C: // inc c
            inc(.C)

        case 0x0D: // dec c
            dec(.C)

        case 0x0E: // ld c, n
            C = next()
            ts = 11

        case 0x14:
            inc(.D)

        case 0x15:
            dec(.D)

        case 0x16: // ld d, n
            D = next()
            ts = 11

        case 0x19: // add index, de
            let addtemp = halfCarryOverflowCalculationAdd16Bit(value: indexValue, amount: DE)
            let carryMask: UInt8 = indexValue > addtemp.value ? 0x01 : 0x00
            writeIndex(index, value: addtemp.value)
            F = preserve(sign, zero, parityOverflow) | addtemp.halfCarryMask | carryMask | bits53(addtemp.value.highByte())
            memptr = indexValue &+ 1
            ts = 15

        case 0x1C: // inc e
            inc(.E)

        case 0x1D: // dec e
            dec(.E)

        case 0x1E: // ld e, n
            E = next()
            ts = 11

        case 0x21: // ld index, nn (UD)
            writeIndex(index, value: nextWord())
            ts = 14

        case 0x22: // ld (nn), index (UD)
            let target = nextWord()
            memoryWriteWord(to: target, value: indexValue)
            memptr = target &+ 1
            ts = 20

        case 0x23: // inc index
            writeIndex(index, value: indexValue &+ 1)
            ts = 10

        case 0x24: // inc index.H
            inc(.IX, isHigh: true)

        case 0x25: // dec index.H
            dec(.IX, isHigh: true)

        case 0x26: // ld index.h, n
            writeIndex(index, value: wordFrom(high: next(), low: indexValue.lowByte()))
            ts = 11
            

        case 0x29: // add index, ix
            let addtemp = halfCarryOverflowCalculationAdd16Bit(value: indexValue, amount: indexValue)
            let carryMask: UInt8 = indexValue > addtemp.value ? 0x01 : 0x00
            writeIndex(index, value: addtemp.value)
            F = preserve(sign, zero, parityOverflow) | addtemp.halfCarryMask | carryMask | bits53(addtemp.value.highByte())
            memptr = indexValue &+ 1
            ts = 15

        case 0x2A: // ld ix, (nn)
            let target = nextWord()
            writeIndex(index, value: memoryReadWord(from: target))
            memptr = target &+ 1
            ts += 20

        case 0x2B: // dec index
            writeIndex(index, value: indexValue &- 1)
            ts = 10

        case 0x2C: // inc index.l
            inc(.IX, isHigh: false)

        case 0x2D: // dec index.l
            dec(.IX, isHigh: false)

        case 0x2E: // ld index.l, n
            writeIndex(index, value: wordFrom(high: indexValue.highByte(), low: next()))
            ts = 11

        case 0x34: // inc (index + d)
            let displacedIndex = displacedIndex(index, displacement: next())
            let masks = halfCarryOverflowCalculationAdd(value: memoryRead(from: displacedIndex), amount: 0x01)
            memoryWrite(to: displacedIndex, value: masks.value)
            F = (F & carry) | masks.halfCarryMask | masks.overflowMask | sz53(masks.value)
            ts = 23

        case 0x35: // inc (index + d)
            let displacedIndex = displacedIndex(index, displacement: next())
            let masks = halfCarryOverflowCalculationSub(value: memoryRead(from: displacedIndex), amount: 0x01)
            memoryWrite(to: displacedIndex, value: masks.value)
            F = (F & carry) | masks.halfCarryMask | masks.overflowMask | sz53(masks.value) | negative
            ts = 23

        case 0x36:
            let displacedIndex = displacedIndex(index, displacement: next())
            memoryWrite(to: displacedIndex, value: next())
            ts = 11

        case 0x39:// add index, sp
            let addtemp = halfCarryOverflowCalculationAdd16Bit(value: indexValue, amount: SP)
            let carryMask: UInt8 = indexValue > addtemp.value ? 0x01 : 0x00
            writeIndex(index, value: addtemp.value)
            F = preserve(sign, zero, parityOverflow) | addtemp.halfCarryMask | carryMask | bits53(addtemp.value.highByte())
            memptr = indexValue &+ 1
            ts = 15

        case 0x3C: // inc a
            inc(.A)

        case 0x3D: // dec a
            dec(.A)

        case 0x3E: // ld a, n
            A = next()
            ts = 7

        case 0x40...0x5F, 0x66, 0x6E, 0x78...0x7F: // ld r,r
            let source = opCode & 0x07
            let target = (opCode >> 3) & 0x07
            let sourceValue = valueFromSource(source: source, index: index)
            switch target {
            case 0x00:
                B = sourceValue
            case 0x01:
                C = sourceValue
            case 0x02:
                D = sourceValue
            case 0x03:
                E = sourceValue
            case 0x04:
                H = sourceValue
            case 0x05:
                L = sourceValue
            case 0x06:
                memoryWrite(to: HL, value: sourceValue)
            case 0x07:
                A = sourceValue
            default:
                break
            }
            if sourceValue == 0x06 {
                ts = 7
            }

        case 0x60...0x65, 0x67:
            let source = opCode & 0x07
            let sourceValue = valueFromSource(source: source, index: index)
            writeIndex(index, value: wordFrom(high: sourceValue, low: indexValue.lowByte()))

        case 0x68...0x6D, 0x6F:
            let source = opCode & 0x07
            let sourceValue = valueFromSource(source: source, index: index)
            writeIndex(index, value: wordFrom(high: indexValue.highByte(), low: sourceValue))

        case 0x70...0x75, 0x77:
            let source = opCode & 0x07
            let sourceValue = valueFromSource(source: source)
            let displacedIndex = displacedIndex(index, displacement: next())
            memoryWrite(to: displacedIndex, value: sourceValue)


        case 0x80...0x87: // add a,r
            let sourceValue = valueFromSource(source: opCode & 0x07, index: index)
            let masks = carryHalfCarryOverflowCalculationAdd(value: A, amount: sourceValue)
            A = masks.value
            F = masks.halfCarryMask | masks.overflowMask | masks.carryMask | sz53(A)
            if sourceValue == 0x06 {
                ts = 7
            }

        case 0x88...0x8F: // adc a,r
            let sourceValue = valueFromSource(source: opCode & 0x07, index: index)
            let masks = carryHalfCarryOverflowCalculationAdd(value: A, amount: sourceValue, carryIn: F & carry)
            A = masks.value
            F = masks.halfCarryMask | masks.overflowMask | masks.carryMask | sz53(A)
            if sourceValue == 0x06 {
                ts = 7
            }

        case 0x90...0x97: // sub a,r
            let sourceValue = valueFromSource(source: opCode & 0x07, index: index)
            let masks = carryHalfCarryOverflowCalculationSub(value: A, amount: sourceValue)
            A = masks.value
            F = masks.halfCarryMask | masks.overflowMask | masks.carryMask | sz53(A) | negative
            if sourceValue == 0x06 {
                ts = 7
            }

        case 0x98...0x9f: // sbc a,r
            let sourceValue = valueFromSource(source: opCode & 0x07, index: index)
            let masks = carryHalfCarryOverflowCalculationSub(value: A, amount: sourceValue, carryIn: F & carry)
            A = masks.value
            F = masks.halfCarryMask | masks.overflowMask | masks.carryMask | sz53(A) | negative
            if sourceValue == 0x06 {
                ts = 7
            }

        case 0xA0...0xA7: // and r
            let sourceValue = valueFromSource(source: opCode & 0x07, index: index)
            A = A & sourceValue
            F = sz53pv(A) | halfCarry
            if sourceValue == 0x06 {
                ts = 7
            }

        case 0xA8...0xAF: // xor r
            let sourceValue = valueFromSource(source: opCode & 0x07, index: index)
            A = A ^ sourceValue
            F = sz53pv(A)
            if sourceValue == 0x06 {
                ts = 7
            }

        case 0xB0...0xB7: //or r
            let sourceValue = valueFromSource(source: opCode & 0x07, index: index)
            A = A | sourceValue
            F = sz53pv(A)
            if sourceValue == 0x06 {
                ts = 7
            }

        case 0xB8...0xBF: // cp r
            let sourceValue = valueFromSource(source: opCode & 0x07, index: index)
            let masks = carryHalfCarryOverflowCalculationSub(value: A, amount: sourceValue)
            F = masks.halfCarryMask | masks.overflowMask | masks.carryMask | (sz53(masks.value) & 0xC0) | negative | bits53(sourceValue)
            if sourceValue == 0x06 {
                ts = 7
            }

        case 0xCB: // Index Bit codes
            opCodeDDFDCB(index: index)
            ts = 0
            mCycles = 0

        case 0xE1: // pop hl
            writeIndex(index, value: pop())
            ts = 14

        case 0xE3: // ex (sp), index
            let temp = indexValue
            let value = memoryReadWord(from: SP)
            writeIndex(index, value: value)
            memoryWriteWord(to: SP, value: temp)
            memptr = value
            ts = 23

        case 0xE5: // push hl
            push(indexValue)
            ts = 15

        case 0xE9: // jp (hl)
            PC = indexValue

        case 0xF9: // ld sp, hl
            SP = indexValue
            ts = 10

        default:
            break
        }
        mCyclesAndTStates(m: mCycles, t: ts)
    }
}
