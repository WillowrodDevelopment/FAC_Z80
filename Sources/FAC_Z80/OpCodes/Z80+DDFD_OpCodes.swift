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
            inc(index, isHigh: true)

        case 0x25: // dec index.H
            dec(index, isHigh: true)

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
            inc(index, isHigh: false)

        case 0x2D: // dec index.l
            dec(index, isHigh: false)

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
            
            
            
// Undocumented opcodes.....
            
            
        case 0x01: // ld BC, n  - Undocumented
            BC = nextWord()
            ts = 10

        case 0x02: // ld(bc), a  - Undocumented
            memoryWrite(to: BC, value: A)
            memptr = wordFrom(high: A, low: (BC.lowByte() &+ 1))
            ts = 7

        case 0x03: // inc BC  - Undocumented
            BC.inc()
            ts = 6
            
          
        case 0x07: // rlca
            let carryMask: UInt8 = (A & 0x80) > 0 ? 0x01 : 0x00
            A = A << 1 | carryMask
            F = preserve(sign, zero, parityOverflow) | carryMask | bits53

        case 0x08: // EX AF
            let spareAF = AF
            AF = AF2
            AF2 = spareAF
            
            
        case 0x0A: // ld a, (bc)
            A = memoryRead(from: BC)
            memptr = BC &+ 1
            ts = 7

        case 0x0B: // dec bc
            BC.dec()
            
        case 0x0F: // rrca
            let carryMask: UInt8 = A & 0x01
            A = A >> 1 | (carryMask > 0 ? 0x80 : 0x00)
            F = preserve(sign, zero, parityOverflow) | carryMask | bits53

        case 0x10: // djnz dis
            let dis = next()
            B = B &- 0x01
            if B == 0 {
                ts = 8
            } else {
                relativeJump(twos: dis)
                ts = 13
            }

        case 0x11: // ld de, nn
            DE = nextWord()
            ts = 10

        case 0x12:
            memoryWrite(to: DE, value: A)
            memptr = wordFrom(high: A, low: (DE.lowByte() &+ 1))
            ts = 7

        case 0x13:
            DE.inc()
            ts = 6
            
        case 0x17: // rla
            let carryMask: UInt8 = (A & 0x80) > 0 ? 0x01 : 0x00
            A = A << 1 | F & 0x01
            F = preserve(sign, zero, parityOverflow) | carryMask | bits53

        case 0x18: // jr dis
            let dis = next()
            relativeJump(twos: dis)
            ts = 12


        case 0x1A: // ld a, (de)
            A = memoryRead(from: DE)
            memptr = DE &+ 1
            ts = 7

        case 0x1B: // dec de
            DE.dec()
            ts = 6
            
        case 0x1F: // rra
            let carryMask: UInt8 = A & 0x01
            A = A >> 1 | (F & 0x01 > 0 ? 0x80 : 0x00)
            F = preserve(sign, zero, parityOverflow) | carryMask | bits53

        case 0x20: // jr nz, dis
            let dis = next()
            if F & zero > 0 {
                ts = 7
            } else {
                relativeJump(twos: dis)
                ts = 12
            }

        case 0x27: // daa

            var rmeml: UInt8 = 0
            var rmemh = F & 0x01

            if (F & 0x10 > 0) || (A & 0x0f > 9) {
                rmeml = 6
            }

            if (rmemh > 0) || (A > 0x99) {
                rmeml |= 0x60
            }

            if A > 0x99 {
                rmemh = 1
            }

            if F & 0x02 > 0 {
                if (F & 0x10 > 0) && ((A & 0x0f) < 6) {
                    rmemh |= 0x10
                }
                A = A &- rmeml
            } else {
                if ((A & 0x0f) > 9) {
                    rmemh |= 0x10
                }
                A = A &+ rmeml
            }

            F = preserve(negative) | sz53pvTable[A] | rmemh

        case 0x28: // jr z, dis
            let dis = next()
            if F & zero == 0 {
                ts += 3
            } else {
                relativeJump(twos: dis)
                ts += 8
            }
            
            
        case 0x2F: // cpl
            A = ~A
            F = preserve(sign, zero, parityOverflow, carry) | bits53 | halfCarry | negative

        case 0x30: // jr nc, dis
            let dis = next()
            if F & carry > 0 {
                ts += 3
            } else {
                relativeJump(twos: dis)
                ts += 8
            }

        case 0x31: // ld sp, nn
            SP = nextWord()
            ts += 6

        case 0x32: // ld (nn), a
            let target = nextWord()
            memoryWrite(to: target, value: A)
            memptr = wordFrom(high: A, low: (target.lowByte() &+ 1))
            ts += 9

        case 0x33: // inc SP
            SP.inc()
            ts = 6
            
        case 0x37: // scf
            let preserved = preserve(sign, zero, parityOverflow)
            let fiveThree = A & 0x28 //modified53 ? F & 0x28 :
            F = preserved | carry | fiveThree
            break

        case 0x38: // jr c, dis
            let dis = next()
            if F & carry == 0 {
                ts += 3
            } else {
                relativeJump(twos: dis)
                ts += 8
            }

        case 0x3A: // ld A, (nn)
            let target = nextWord()
            memptr = target &+ 1
            A = memoryRead(from: target)  //memory[target]
            ts = 11

        case 0x3B: // dec SP
            SP.dec()
            ts = 6
            
        case 0x3F: // ccf
            let preserved = preserve(sign, zero, parityOverflow)
            let fiveThree = modified53 ? F & 0x28 : A & 0x28
            let hFlag = (F & carry) << 4
            let cFlag = hFlag > 0 ? 0x00 : carry
            F = preserved | cFlag | hFlag | fiveThree
            
            
        case 0x76: // halt
            //PC = PC &- 0x01
            isInHaltState = true

            
        case 0xC0: // ret nz
            if (F & zero) == 0 {
                ret()
                ts = 11
            } else {
                ts = 5
            }

        case 0xC1: // pop bc
            BC = pop()
            ts = 10

        case 0xC2: // jp nz, nn
            let target = nextWord()
            if (F & zero) == 0 {
                jump(target)
            } else {
                memptr = target
            }
            ts = 10

        case 0xC3: // jp nn
            jump(nextWord())
            ts = 10

        case 0xC4: // call nz, nn
            let target = nextWord()
            if (F & zero) == 0 {
                push(PC)
                jump(target)
                ts = 17
            } else {
                ts = 10
                memptr = target
            }

        case 0xC5: // push bc
            push(BC)
            ts = 11

        case 0xC6:// add a,n
            let sourceValue = next()
            let masks = carryHalfCarryOverflowCalculationAdd(value: A, amount: sourceValue)
            A = masks.value
            F = masks.halfCarryMask | masks.overflowMask | masks.carryMask | sz53(A)
            ts = 7

        case 0xC7: // RST 0x00
            push(PC)
            jump(0x00)
            ts = 11

        case 0xC8:// ret z
            if (F & zero) > 0 {
                ret()
                ts = 11
            } else {
                ts = 5
            }

        case 0xC9: // ret
            ret()
            ts = 10

        case 0xCA:// jp z, nn
            let target = nextWord()
            if (F & zero) > 0 {
                jump(target)
            } else {
                memptr = target
            }
            ts = 10

        case 0xCC: // call z, nn
            let target = nextWord()
            if (F & zero) > 0 {
                push(PC)
                jump(target)
                ts = 17
            } else {
                ts = 10
                memptr = target
            }

        case 0xCD: // call nn
            let target = nextWord()
            push(PC)
            jump(target)
            ts = 17

        case 0xCE: // adc a,n
            let sourceValue = next()
            let masks = carryHalfCarryOverflowCalculationAdd(value: A, amount: sourceValue, carryIn: F & carry)
            A = masks.value
            F = masks.halfCarryMask | masks.overflowMask | masks.carryMask | sz53(A)
            ts = 7

        case 0xCF: // RST 0x08
            push(PC)
            jump(0x08)
            ts = 11

        case 0xD0:// ret nc
            if (F & carry) == 0 {
                ret()
                ts = 11
            } else {
                ts = 5
            }

        case 0xD1: // pop de
            DE = pop()
            ts = 10

        case 0xD2: // jp nc, nn
            let target = nextWord()
            if (F & carry) == 0 {
                jump(target)
            } else {
                memptr = target
            }
            ts = 10

        case 0xD3: // out (n) a
            let port = next()
            performOut(port: port, map: nil, value: A)
            ts = 11
            memptr = wordFrom(high: A, low: port &+ 1)

        case 0xD4: // call nc, nn
            let target = nextWord()
            if (F & carry) == 0 {
                push(PC)
                jump(target)
                ts = 17
            } else {
                ts = 10
                memptr = target
            }

        case 0xD5: // push de
            push(DE)
            ts = 11

        case 0xD6:// add a,n
            let sourceValue = next()
            let masks = carryHalfCarryOverflowCalculationSub(value: A, amount: sourceValue)
            A = masks.value
            F = masks.halfCarryMask | masks.overflowMask | masks.carryMask | sz53(A) | negative
            ts = 7

        case 0xD7: // RST 0x10
            push(PC)
            jump(0x10)
            ts = 11

        case 0xD8:// ret c
            if (F & carry) > 0 {
                ret()
                ts = 11
            } else {
                ts = 5
            }

        case 0xD9: // exx
            swapBC()
            swapDE()
            swapHL()
            ts = 4

        case 0xDA:// jp c, nn
            let target = nextWord()
            if (F & carry) > 0 {
                jump(target)
            } else {
                memptr = target
            }
            ts = 10

        case 0xDB: // in a, (n)
            let oldA = UInt16(A) << 8
            let port = next()
            A = performIn(port: port, map: A)
            memptr = oldA &+ UInt16(port) &+ 1

        case 0xDC: // call c, nn
            let target = nextWord()
            if (F & carry) > 0 {
                push(PC)
                jump(target)
                ts = 17
            } else {
                ts = 10
                memptr = target
            }

        case 0xDD: // IX opCodes
             opCodeDDFD(index: index)
            ts = 0
            mCycles = 0

        case 0xDE: // sbc a,n
            let sourceValue = next()
            let masks = carryHalfCarryOverflowCalculationSub(value: A, amount: sourceValue, carryIn: F & carry)
            A = masks.value
            F = masks.halfCarryMask | masks.overflowMask | masks.carryMask | sz53(A) | negative
            ts = 7

        case 0xDF: // RST 0x18
            push(PC)
            jump(0x18)
            ts = 11

        case 0xE0:// ret po
            if (F & parityOverflow) == 0 {
                ret()
                ts = 11
            } else {
                ts = 5
            }


        case 0xE2: // jp po, nn
            let target = nextWord()
            if (F & parityOverflow) == 0 {
                jump(target)
            } else {
                memptr = target
            }
            ts = 10


        case 0xE4: // call po, nn
            let target = nextWord()
            if (F & parityOverflow) == 0 {
                push(PC)
                jump(target)
                ts = 17
            } else {
                ts = 10
                memptr = target
            }

        case 0xE6:// and n
            let sourceValue = next()
            A = A & sourceValue
            F = sz53pv(A) | halfCarry
            ts = 7

        case 0xE7: // RST 0x20
            push(PC)
            jump(0x20)
            ts = 11

        case 0xE8:// ret pe
            if (F & parityOverflow) > 0 {
                ret()
                ts = 11
            } else {
                ts = 5
            }


        case 0xEA:// jp pe, nn
            let target = nextWord()
            if (F & parityOverflow) > 0 {
                jump(target)
            } else {
                memptr = target
            }
            ts = 10

        case 0xEB: // ex de, hl
            let temp = HL
            HL = DE
            DE = temp

        case 0xEC: // call pe, nn
            let target = nextWord()
            if (F & parityOverflow) > 0 {
                push(PC)
                jump(target)
                ts = 17
            } else {
                ts = 10
                memptr = target
            }

        case 0xED: // ED opCodes
             opCodeED()
            ts = 0
            mCycles = 0


        case 0xEE: // adc a,n
            let sourceValue = next()
            A = A ^ sourceValue
            F = sz53pv(A)
            ts = 7

        case 0xEF: // RST 0x28
            push(PC)
            jump(0x28)
            ts = 11

        case 0xF0:// ret p
            if (F & sign) == 0 {
                ret()
                ts = 11
            } else {
                ts = 5
            }

        case 0xF1: // pop af
            AF = pop()
            ts = 10

        case 0xF2: // jp p, nn
            let target = nextWord()
            if (F & sign) == 0 {
                jump(target)
            } else {
                memptr = target
            }
            ts = 10

        case 0xF3: // di
            iff1 = 0
            iff2 = 0

        case 0xF4: // call p, nn
            let target = nextWord()
            if (F & sign) == 0 {
                push(PC)
                jump(target)
                ts = 17
            } else {
                ts = 10
                memptr = target
            }

        case 0xF5: // push af
            push(AF)
            ts = 11

        case 0xF6: // or n
            let sourceValue = next()
            A = A | sourceValue
            F = sz53pv(A)
            ts = 7

        case 0xF7: // RST 0x30
            push(PC)
            jump(0x30)
            ts = 11

        case 0xF8: // ret m
            if (F & sign) > 0 {
                ret()
                ts = 11
            } else {
                ts = 5
            }

        case 0xFA:// jp m, nn
            let target = nextWord()
            if (F & sign) > 0 {
                jump(target)
            } else {
                memptr = target
            }
            ts = 10

        case 0xFB: // ei
            iff1 = 1
            iff2 = 1

        case 0xFC: // call m, nn
            let target = nextWord()
            if (F & sign) > 0 {
                push(PC)
                jump(target)
                ts = 17
            } else {
                ts = 10
                memptr = target
            }

        case 0xFD:  // IY opCodes
            opCodeDDFD(index: .IY)
            ts = 0
            mCycles = 0

        case 0xFE: // cp n
            let sourceValue = next()
            let masks = carryHalfCarryOverflowCalculationSub(value: A, amount: sourceValue)
            F = masks.halfCarryMask | masks.overflowMask | masks.carryMask | (sz53(masks.value) & 0xC0) | negative | bits53(sourceValue)
            ts = 7

        case 0xFF: // RST 0x38
            push(PC)
            jump(0x38)
            ts = 11
            
            
            
            
            
            
        default:
            break
        }
        mCyclesAndTStates(m: mCycles, t: ts)
    }
}
