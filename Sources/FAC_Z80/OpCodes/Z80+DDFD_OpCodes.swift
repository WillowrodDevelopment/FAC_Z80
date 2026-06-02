//
//  Z80+DD_OpCodes.swift
//  Fake-A-Chip
//
//  Created by Mike Hall on 23/05/2023.
//

import Foundation

extension Z80 {
    func opCodeDDFD(index: Z8016BitRegister) async {
        var ts = 8
        var mCycles = 2
        let indexValue = await valueOfIndex(index: index)
        let opCode = await next()
        switch opCode {
        case 0x04: // inc B (UD)
            await inc(.B)

        case 0x05: // dec B (UD)
            await dec(.B)

        case 0x06: // ld b,n (UD)
            B = await next()
            ts = 11

        case 0x09: // add index, bc
            let addtemp = halfCarryOverflowCalculationAdd16Bit(value: indexValue, amount: BC)
            let carryMask: UInt8 = indexValue > addtemp.value ? 0x01 : 0x00
            await writeIndex(index, value: addtemp.value)
            F = preserve(sign, zero, parityOverflow) | addtemp.halfCarryMask | carryMask | bits53(addtemp.value.highByte())
            memptr = indexValue &+ 1
            ts = 15

        case 0x0C: // inc c
            await inc(.C)

        case 0x0D: // dec c
            await dec(.C)

        case 0x0E: // ld c, n
            C = await next()
            ts = 11

        case 0x14:
            await inc(.D)

        case 0x15:
            await dec(.D)

        case 0x16: // ld d, n
            D = await next()
            ts = 11

        case 0x19: // add index, de
            let addtemp = halfCarryOverflowCalculationAdd16Bit(value: indexValue, amount: DE)
            let carryMask: UInt8 = indexValue > addtemp.value ? 0x01 : 0x00
            await writeIndex(index, value: addtemp.value)
            F = preserve(sign, zero, parityOverflow) | addtemp.halfCarryMask | carryMask | bits53(addtemp.value.highByte())
            memptr = indexValue &+ 1
            ts = 15

        case 0x1C: // inc e
            await inc(.E)

        case 0x1D: // dec e
            await dec(.E)

        case 0x1E: // ld e, n
            E = await next()
            ts = 11

        case 0x21: // ld index, nn (UD)
            await writeIndex(index, value: await nextWord())
            ts = 14

        case 0x22: // ld (nn), index (UD)
            let target = await nextWord()
            await memory.writeWord(to: target, value: indexValue)
            memptr = target &+ 1
            ts = 20

        case 0x23: // inc index
            await writeIndex(index, value: indexValue &+ 1)
            ts = 10

        case 0x24: // inc index.H
            await inc(index, isHigh: true)

        case 0x25: // dec index.H
            await dec(index, isHigh: true)

        case 0x26: // ld index.h, n
            await writeIndex(index, value: await wordFrom(high: await next(), low: indexValue.lowByte()))
            ts = 11
            

        case 0x29: // add index, ix
            let addtemp = halfCarryOverflowCalculationAdd16Bit(value: indexValue, amount: indexValue)
            let carryMask: UInt8 = indexValue > addtemp.value ? 0x01 : 0x00
            await writeIndex(index, value: addtemp.value)
            F = preserve(sign, zero, parityOverflow) | addtemp.halfCarryMask | carryMask | bits53(addtemp.value.highByte())
            memptr = indexValue &+ 1
            ts = 15

        case 0x2A: // ld ix, (nn)
            let target = await nextWord()
            await writeIndex(index, value: await memory.readWord(from: target))
            memptr = target &+ 1
            ts = 20

        case 0x2B: // dec index
            await writeIndex(index, value: indexValue &- 1)
            ts = 10

        case 0x2C: // inc index.l
            await inc(index, isHigh: false)

        case 0x2D: // dec index.l
            await dec(index, isHigh: false)

        case 0x2E: // ld index.l, n
            await writeIndex(index, value: await wordFrom(high: indexValue.highByte(), low: await next()))
            ts = 11

        case 0x34: // inc (index + d)
            let displacedIndex = displacedIndex(index, displacement: await next())
            let masks = halfCarryOverflowCalculationAdd(value: await memory.read(from: displacedIndex), amount: 0x01)
            await memory.write(to: displacedIndex, value: masks.value)
            F = (F & carry) | masks.halfCarryMask | masks.overflowMask | sz53(masks.value)
            ts = 23

        case 0x35: // inc (index + d)
            let displacedIndex = displacedIndex(index, displacement: await next())
            let masks = halfCarryOverflowCalculationSub(value: await memory.read(from: displacedIndex), amount: 0x01)
            await memory.write(to: displacedIndex, value: masks.value)
            F = (F & carry) | masks.halfCarryMask | masks.overflowMask | sz53(masks.value) | negative
            ts = 23

        case 0x36:
            let displacedIndex = displacedIndex(index, displacement: await next())
            await memory.write(to: displacedIndex, value: await next())
            ts = 19

        case 0x39:// add index, sp
            let addtemp = halfCarryOverflowCalculationAdd16Bit(value: indexValue, amount: SP)
            let carryMask: UInt8 = indexValue > addtemp.value ? 0x01 : 0x00
            await writeIndex(index, value: addtemp.value)
            F = preserve(sign, zero, parityOverflow) | addtemp.halfCarryMask | carryMask | bits53(addtemp.value.highByte())
            memptr = indexValue &+ 1
            ts = 15

        case 0x3C: // inc a
            await inc(.A)

        case 0x3D: // dec a
            await dec(.A)

        case 0x3E: // ld a, n
            A = await next()
            ts = 11

        case 0x40...0x5F, 0x66, 0x6E, 0x78...0x7F: // ld r,r
            let source = opCode & 0x07
            let target = (opCode >> 3) & 0x07
            let sourceValue = source == 0x06 ? await memory.read(from: displacedIndex(index, displacement: await next())) : indexRegisterValue(from: source, index: index)
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
                await memory.write(to: HL, value: sourceValue)
            case 0x07:
                A = sourceValue
            default:
                break
            }
            if source == 0x06 {
                ts = 19
            } else {
                ts = 8
            }

        case 0x60...0x65, 0x67:
            let source = opCode & 0x07
            let sourceValue = source == 0x06 ? await memory.read(from: displacedIndex(index, displacement: await next())) : indexRegisterValue(from: source, index: index)
            await writeIndex(index, value: await wordFrom(high: sourceValue, low: indexValue.lowByte()))
            ts = 8

        case 0x68...0x6D, 0x6F:
            let source = opCode & 0x07
            let sourceValue = source == 0x06 ? await memory.read(from: displacedIndex(index, displacement: await next())) : indexRegisterValue(from: source, index: index)
            await writeIndex(index, value: await wordFrom(high: indexValue.highByte(), low: sourceValue))
            ts = 8

        case 0x70...0x75, 0x77:
            let source = opCode & 0x07
            let sourceValue = registerValue(from: source)
            let displacedIndex = displacedIndex(index, displacement: await next())
            await memory.write(to: displacedIndex, value: sourceValue)
            ts = 19


        case 0x80...0x87: // add a,r
            let source = opCode & 0x07
            let sourceValue = source == 0x06 ? await memory.read(from: displacedIndex(index, displacement: await next())) : indexRegisterValue(from: source, index: index)
            let masks = carryHalfCarryOverflowCalculationAdd(value: A, amount: sourceValue)
            A = masks.value
            F = masks.halfCarryMask | masks.overflowMask | masks.carryMask | sz53(A)
            if source == 0x06 {
                ts = 19
            } else {
                ts = 8
            }

        case 0x88...0x8F: // adc a,r
            let source = opCode & 0x07
            let sourceValue = source == 0x06 ? await memory.read(from: displacedIndex(index, displacement: await next())) : indexRegisterValue(from: source, index: index)
            let masks = carryHalfCarryOverflowCalculationAdd(value: A, amount: sourceValue, carryIn: F & carry)
            A = masks.value
            F = masks.halfCarryMask | masks.overflowMask | masks.carryMask | sz53(A)
            if source == 0x06 {
                ts = 19
            } else {
                ts = 8
            }

        case 0x90...0x97: // sub a,r
            let source = opCode & 0x07
            let sourceValue = source == 0x06 ? await memory.read(from: displacedIndex(index, displacement: await next())) : indexRegisterValue(from: source, index: index)
            let masks = carryHalfCarryOverflowCalculationSub(value: A, amount: sourceValue)
            A = masks.value
            F = masks.halfCarryMask | masks.overflowMask | masks.carryMask | sz53(A) | negative
            if source == 0x06 {
                ts = 19
            } else {
                ts = 8
            }

        case 0x98...0x9f: // sbc a,r
            let source = opCode & 0x07
            let sourceValue = source == 0x06 ? await memory.read(from: displacedIndex(index, displacement: await next())) : indexRegisterValue(from: source, index: index)
            let masks = carryHalfCarryOverflowCalculationSub(value: A, amount: sourceValue, carryIn: F & carry)
            A = masks.value
            F = masks.halfCarryMask | masks.overflowMask | masks.carryMask | sz53(A) | negative
            if source == 0x06 {
                ts = 19
            } else {
                ts = 8
            }

        case 0xA0...0xA7: // and r
            let source = opCode & 0x07
            let sourceValue = source == 0x06 ? await memory.read(from: displacedIndex(index, displacement: await next())) : indexRegisterValue(from: source, index: index)
            A = A & sourceValue
            F = sz53pv(A) | halfCarry
            if source == 0x06 {
                ts = 19
            } else {
                ts = 8
            }

        case 0xA8...0xAF: // xor r
            let source = opCode & 0x07
            let sourceValue = source == 0x06 ? await memory.read(from: displacedIndex(index, displacement: await next())) : indexRegisterValue(from: source, index: index)
            A = A ^ sourceValue
            F = sz53pv(A)
            if source == 0x06 {
                ts = 19
            } else {
                ts = 8
            }

        case 0xB0...0xB7: //or r
            let source = opCode & 0x07
            let sourceValue = source == 0x06 ? await memory.read(from: displacedIndex(index, displacement: await next())) : indexRegisterValue(from: source, index: index)
            A = A | sourceValue
            F = sz53pv(A)
            if source == 0x06 {
                ts = 19
            } else {
                ts = 8
            }

        case 0xB8...0xBF: // cp r
            let source = opCode & 0x07
            let sourceValue = source == 0x06 ? await memory.read(from: displacedIndex(index, displacement: await next())) : indexRegisterValue(from: source, index: index)
            let masks = carryHalfCarryOverflowCalculationSub(value: A, amount: sourceValue)
            F = masks.halfCarryMask | masks.overflowMask | masks.carryMask | (sz53(masks.value) & 0xC0) | negative | bits53(sourceValue)
            if source == 0x06 {
                ts = 19
            } else {
                ts = 8
            }

        case 0xCB: // Index Bit codes
            await opCodeDDFDCB(index: index)
            ts = 0
            mCycles = 0

        case 0xE1: // pop hl
            await writeIndex(index, value: await pop())
            ts = 14

        case 0xE3: // ex (sp), index
            let temp = indexValue
            let value = await memory.readWord(from: SP)
            await writeIndex(index, value: value)
            await memory.writeWord(to: SP, value: temp)
            memptr = value
            ts = 23

        case 0xE5: // push hl
            await push(indexValue)
            ts = 15

        case 0xE9: // jp (hl)
            PC = indexValue

        case 0xF9: // ld sp, hl
            SP = indexValue
            ts = 10
            
            
            
// Undocumented opcodes.....
            
            
        case 0x01: // ld BC, n  - Undocumented
            BC = await nextWord()
            ts = 14

        case 0x02: // ld(bc), a  - Undocumented
            await memory.write(to: BC, value: A)
            memptr = await wordFrom(high: A, low: (BC.lowByte() &+ 1))
            ts = 11

        case 0x03: // inc BC  - Undocumented
            BC = BC &+ 1
            ts = 10
            
          
        case 0x07: // rlca
            let carryMask: UInt8 = (A & 0x80) > 0 ? 0x01 : 0x00
            A = A << 1 | carryMask
            F = preserve(sign, zero, parityOverflow) | carryMask | bits53

        case 0x08: // EX AF
            let spareAF = AF
            AF = AF2
            AF2 = spareAF
            
            
        case 0x0A: // ld a, (bc)
            A = await memory.read(from: BC)
            memptr = BC &+ 1
            ts = 11

        case 0x0B: // dec bc
            BC = BC &- 1
            ts = 10
            
        case 0x0F: // rrca
            let carryMask: UInt8 = A & 0x01
            A = A >> 1 | (carryMask > 0 ? 0x80 : 0x00)
            F = preserve(sign, zero, parityOverflow) | carryMask | bits53

        case 0x10: // djnz dis
            let dis = await next()
            B = B &- 0x01
            if B == 0 {
                ts = 12
            } else {
                await relativeJump(twos: dis)
                ts = 17
            }

        case 0x11: // ld de, nn
            DE = await nextWord()
            ts = 14

        case 0x12:
            await memory.write(to: DE, value: A)
            memptr = await wordFrom(high: A, low: (DE.lowByte() &+ 1))
            ts = 11

        case 0x13:
            DE = DE &+ 1
            ts = 10
            
        case 0x17: // rla
            let carryMask: UInt8 = (A & 0x80) > 0 ? 0x01 : 0x00
            A = A << 1 | F & 0x01
            F = preserve(sign, zero, parityOverflow) | carryMask | bits53

        case 0x18: // jr dis
            let dis = await next()
            await relativeJump(twos: dis)
            ts = 16


        case 0x1A: // ld a, (de)
            A = await memory.read(from: DE)
            memptr = DE &+ 1
            ts = 11

        case 0x1B: // dec de
            DE = DE &- 1
            ts = 10
            
        case 0x1F: // rra
            let carryMask: UInt8 = A & 0x01
            A = A >> 1 | (F & 0x01 > 0 ? 0x80 : 0x00)
            F = preserve(sign, zero, parityOverflow) | carryMask | bits53

        case 0x20: // jr nz, dis
            let dis = await next()
            if F & zero > 0 {
                ts = 11
            } else {
                await relativeJump(twos: dis)
                ts = 16
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
            let dis = await next()
            if F & zero == 0 {
                ts = 11
            } else {
                await relativeJump(twos: dis)
                ts = 16
            }
            
            
        case 0x2F: // cpl
            A = ~A
            F = preserve(sign, zero, parityOverflow, carry) | bits53 | halfCarry | negative

        case 0x30: // jr nc, dis
            let dis = await next()
            if F & carry > 0 {
                ts = 11
            } else {
                await relativeJump(twos: dis)
                ts = 16
            }

        case 0x31: // ld sp, nn
            SP = await nextWord()
            ts = 14

        case 0x32: // ld (nn), a
            let target = await nextWord()
            await memory.write(to: target, value: A)
            memptr = await wordFrom(high: A, low: (target.lowByte() &+ 1))
            ts = 17

        case 0x33: // inc SP
            SP.inc()
            ts = 10
            
        case 0x37: // scf
            let preserved = preserve(sign, zero, parityOverflow)
            let fiveThree = A & 0x28 //modified53 ? F & 0x28 :
            F = preserved | carry | fiveThree
            break

        case 0x38: // jr c, dis
            let dis = await next()
            if F & carry == 0 {
                ts = 11
            } else {
                await relativeJump(twos: dis)
                ts = 16
            }

        case 0x3A: // ld A, (nn)
            let target = await nextWord()
            memptr = target &+ 1
            A = await memory.read(from: target)  //memory[target]
            ts = 17

        case 0x3B: // dec SP
            SP.dec()
            ts = 10
            
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
                await ret()
                ts = 15
            } else {
                ts = 9
            }

        case 0xC1: // pop bc
            BC = await pop()
            ts = 14

        case 0xC2: // jp nz, nn
            let target = await nextWord()
            if (F & zero) == 0 {
                await jump(target)
            } else {
                memptr = target
            }
            ts = 14

        case 0xC3: // jp nn
            await jump(await nextWord())
            ts = 14

        case 0xC4: // call nz, nn
            let target = await nextWord()
            if (F & zero) == 0 {
                await push(PC)
                await jump(target)
                ts = 21
            } else {
                ts = 14
                memptr = target
            }

        case 0xC5: // push bc
            await push(BC)
            ts = 15

        case 0xC6:// add a,n
            let sourceValue = await next()
            let masks = carryHalfCarryOverflowCalculationAdd(value: A, amount: sourceValue)
            A = masks.value
            F = masks.halfCarryMask | masks.overflowMask | masks.carryMask | sz53(A)
            ts = 11

        case 0xC7: // RST 0x00
            await push(PC)
            await jump(0x00)
            ts = 15

        case 0xC8:// ret z
            if (F & zero) > 0 {
                await ret()
                ts = 15
            } else {
                ts = 9
            }

        case 0xC9: // ret
            await ret()
            ts = 14

        case 0xCA:// jp z, nn
            let target = await nextWord()
            if (F & zero) > 0 {
                await jump(target)
            } else {
                memptr = target
            }
            ts = 14

        case 0xCC: // call z, nn
            let target = await nextWord()
            if (F & zero) > 0 {
                await push(PC)
                await jump(target)
                ts = 21
            } else {
                ts = 14
                memptr = target
            }

        case 0xCD: // call nn
            let target = await nextWord()
            await push(PC)
            await jump(target)
            ts = 21

        case 0xCE: // adc a,n
            let sourceValue = await next()
            let masks = carryHalfCarryOverflowCalculationAdd(value: A, amount: sourceValue, carryIn: F & carry)
            A = masks.value
            F = masks.halfCarryMask | masks.overflowMask | masks.carryMask | sz53(A)
            ts = 11

        case 0xCF: // RST 0x08
            await push(PC)
            await jump(0x08)
            ts = 15

        case 0xD0:// ret nc
            if (F & carry) == 0 {
                await ret()
                ts = 15
            } else {
                ts = 9
            }

        case 0xD1: // pop de
            DE = await pop()
            ts = 14

        case 0xD2: // jp nc, nn
            let target = await nextWord()
            if (F & carry) == 0 {
                await jump(target)
            } else {
                memptr = target
            }
            ts = 14

        case 0xD3: // out (n) a
            let port = await next()
            await performOut(port: port, map: nil, value: A)
            ts = 15
            memptr = await wordFrom(high: A, low: port &+ 1)

        case 0xD4: // call nc, nn
            let target = await nextWord()
            if (F & carry) == 0 {
                await push(PC)
                await jump(target)
                ts = 21
            } else {
                ts = 14
                memptr = target
            }

        case 0xD5: // push de
            await push(DE)
            ts = 15

        case 0xD6:// add a,n
            let sourceValue = await next()
            let masks = carryHalfCarryOverflowCalculationSub(value: A, amount: sourceValue)
            A = masks.value
            F = masks.halfCarryMask | masks.overflowMask | masks.carryMask | sz53(A) | negative
            ts = 11

        case 0xD7: // RST 0x10
            await push(PC)
            await jump(0x10)
            ts = 15

        case 0xD8:// ret c
            if (F & carry) > 0 {
                await ret()
                ts = 15
            } else {
                ts = 9
            }

        case 0xD9: // exx
            await swapBC()
            await swapDE()
            await swapHL()
            ts = 8

        case 0xDA:// jp c, nn
            let target = await nextWord()
            if (F & carry) > 0 {
                await jump(target)
            } else {
                memptr = target
            }
            ts = 14

        case 0xDB: // in a, (n)
            let oldA = UInt16(A) << 8
            let port = await next()
            A = await performIn(port: port, map: A)
            memptr = oldA &+ UInt16(port) &+ 1
            ts = 15

        case 0xDC: // call c, nn
            let target = await nextWord()
            if (F & carry) > 0 {
                await push(PC)
                await jump(target)
                ts = 21
            } else {
                ts = 14
                memptr = target
            }

        case 0xDD: // IX opCodes
            await opCodeDDFD(index: index)
            ts = 0
            mCycles = 0

        case 0xDE: // sbc a,n
            let sourceValue = await next()
            let masks = carryHalfCarryOverflowCalculationSub(value: A, amount: sourceValue, carryIn: F & carry)
            A = masks.value
            F = masks.halfCarryMask | masks.overflowMask | masks.carryMask | sz53(A) | negative
            ts = 11

        case 0xDF: // RST 0x18
            await push(PC)
            await jump(0x18)
            ts = 15

        case 0xE0:// ret po
            if (F & parityOverflow) == 0 {
                await ret()
                ts = 15
            } else {
                ts = 9
            }


        case 0xE2: // jp po, nn
            let target = await nextWord()
            if (F & parityOverflow) == 0 {
                await jump(target)
            } else {
                memptr = target
            }
            ts = 14


        case 0xE4: // call po, nn
            let target = await nextWord()
            if (F & parityOverflow) == 0 {
                await push(PC)
                await jump(target)
                ts = 21
            } else {
                ts = 14
                memptr = target
            }

        case 0xE6:// and n
            let sourceValue = await next()
            A = A & sourceValue
            F = sz53pv(A) | halfCarry
            ts = 11

        case 0xE7: // RST 0x20
            await push(PC)
            await jump(0x20)
            ts = 15

        case 0xE8:// ret pe
            if (F & parityOverflow) > 0 {
                await ret()
                ts = 15
            } else {
                ts = 9
            }


        case 0xEA:// jp pe, nn
            let target = await nextWord()
            if (F & parityOverflow) > 0 {
                await jump(target)
            } else {
                memptr = target
            }
            ts = 14

        case 0xEB: // ex de, hl
            let temp = HL
            HL = DE
            DE = temp

        case 0xEC: // call pe, nn
            let target = await nextWord()
            if (F & parityOverflow) > 0 {
                await push(PC)
                await jump(target)
                ts = 21
            } else {
                ts = 14
                memptr = target
            }

        case 0xED: // ED opCodes
            await opCodeED()
            ts = 0
            mCycles = 0


        case 0xEE: // adc a,n
            let sourceValue = await next()
            A = A ^ sourceValue
            F = sz53pv(A)
            ts = 11

        case 0xEF: // RST 0x28
            await push(PC)
            await jump(0x28)
            ts = 15

        case 0xF0:// ret p
            if (F & sign) == 0 {
                await ret()
                ts = 15
            } else {
                ts = 9
            }

        case 0xF1: // pop af
            AF = await pop()
            ts = 14

        case 0xF2: // jp p, nn
            let target = await nextWord()
            if (F & sign) == 0 {
                await jump(target)
            } else {
                memptr = target
            }
            ts = 14

        case 0xF3: // di
            iff1 = 0
            iff2 = 0

        case 0xF4: // call p, nn
            let target = await nextWord()
            if (F & sign) == 0 {
                await push(PC)
                await jump(target)
                ts = 21
            } else {
                ts = 14
                memptr = target
            }

        case 0xF5: // push af
            await push(AF)
            ts = 15

        case 0xF6: // or n
            let sourceValue = await next()
            A = A | sourceValue
            F = sz53pv(A)
            ts = 11

        case 0xF7: // RST 0x30
            await push(PC)
            await jump(0x30)
            ts = 15

        case 0xF8: // ret m
            if (F & sign) > 0 {
                await ret()
                ts = 15
            } else {
                ts = 9
            }

        case 0xFA:// jp m, nn
            let target = await nextWord()
            if (F & sign) > 0 {
                await jump(target)
            } else {
                memptr = target
            }
            ts = 14

        case 0xFB: // ei
            iff1 = 1
            iff2 = 1

        case 0xFC: // call m, nn
            let target = await nextWord()
            if (F & sign) > 0 {
                await push(PC)
                await jump(target)
                ts = 21
            } else {
                ts = 14
                memptr = target
            }

        case 0xFD:  // IY opCodes
            await opCodeDDFD(index: .IY)
            ts = 0
            mCycles = 0

        case 0xFE: // cp n
            let sourceValue = await next()
            let masks = carryHalfCarryOverflowCalculationSub(value: A, amount: sourceValue)
            F = masks.halfCarryMask | masks.overflowMask | masks.carryMask | (sz53(masks.value) & 0xC0) | negative | bits53(sourceValue)
            ts = 11

        case 0xFF: // RST 0x38
            await push(PC)
            await jump(0x38)
            ts = 15
            
            
            
            
            
            
        default:
            break
        }
        await mCyclesAndTStates(m: mCycles, t: ts)
    }
}
