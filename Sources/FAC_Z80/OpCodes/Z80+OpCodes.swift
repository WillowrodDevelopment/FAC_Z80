//
//  Z80+OpCodes.swift
//  Fake-A-Chip
//
//  Created by Mike Hall on 20/05/2023.
//

// TODO: 0x76 - Halt command not implemented

import Foundation
import FAC_Common

extension Z80 {

    public func fetchAndExecute() async {
        if isInHaltState {
            await mCyclesAndTStates(m: 1, t: 10)
            return
        }
        let oldPC = PC
//        if loggingService.isLoggingProcessor {
//            lastPCValues.append(oldPC)
//        }

        let opCode = await next()
        var ts = 4
        var mCycles = 1
        switch opCode {
        case 0x00:
           // print("NOP")
            break

        case 0x01: // ld BC, n
            BC = await nextWord()
            ts = 10

        case 0x02: // ld(bc), a
            await memory.write(to: BC, value: A)
            memptr = await wordFrom(high: A, low: (BC.lowByte() &+ 1))
            ts = 7

        case 0x03: // inc BC
            BC.inc()
            ts = 6

        case 0x04: // inc B
           await inc(.B)

        case 0x05: // dec B
           await dec(.B)

        case 0x06: // ld b,n
            B = await next()
            ts = 7

        case 0x07: // rlca
            let carryMask: UInt8 = (A & 0x80) > 0 ? 0x01 : 0x00
            A = A << 1 | carryMask
            F = preserve(sign, zero, parityOverflow) | carryMask | bits53

        case 0x08: // EX AF
            let spareAF = AF
            AF = AF2
            AF2 = spareAF

        case 0x09: // add hl, bc
            let addtemp = halfCarryOverflowCalculationAdd16Bit(value: HL, amount: BC)
            let carryMask: UInt8 = HL > addtemp.value ? 0x01 : 0x00
            memptr = HL &+ 1
            HL = addtemp.value //UInt16(addtemp & 0xffff)
            F = preserve(sign, zero, parityOverflow) | addtemp.halfCarryMask | carryMask | bits53OnH
            ts = 11

        case 0x0A: // ld a, (bc)
            A = await memory.read(from: BC)
            memptr = BC &+ 1
            ts = 7

        case 0x0B: // dec bc
            BC.dec()

        case 0x0C: // inc c
           await inc(.C)

        case 0x0D: // dec c
           await dec(.C)

        case 0x0E: // ld c, n
            C = await next()
            ts = 7

        case 0x0F: // rrca
            let carryMask: UInt8 = A & 0x01
            A = A >> 1 | (carryMask > 0 ? 0x80 : 0x00)
            F = preserve(sign, zero, parityOverflow) | carryMask | bits53

        case 0x10: // djnz dis
            let dis = await next()
            B = B &- 0x01
            if B == 0 {
                ts = 8
            } else {
                await relativeJump(twos: dis)
                ts = 13
            }

        case 0x11: // ld de, nn
            DE = await nextWord()
            ts = 10

        case 0x12:
            await memory.write(to: DE, value: A)
            memptr = await wordFrom(high: A, low: (DE.lowByte() &+ 1))
            ts = 7

        case 0x13:
            DE.inc()
            ts = 6

        case 0x14:
           await inc(.D)

        case 0x15:
           await dec(.D)

        case 0x16: // ld d, n
            D = await next()
            ts = 7
            
        case 0x17: // rla
            let carryMask: UInt8 = (A & 0x80) > 0 ? 0x01 : 0x00
            A = A << 1 | F & 0x01
            F = preserve(sign, zero, parityOverflow) | carryMask | bits53

        case 0x18: // jr dis
            let dis = await next()
            await relativeJump(twos: dis)
            ts = 12

        case 0x19: // add hl, de
            let addtemp = halfCarryOverflowCalculationAdd16Bit(value: HL, amount: DE)
            let carryMask: UInt8 = HL > addtemp.value ? 0x01 : 0x00
            memptr = HL &+ 1
            HL = addtemp.value //UInt16(addtemp & 0xffff)
            F = preserve(sign, zero, parityOverflow) | addtemp.halfCarryMask | carryMask | bits53OnH
            ts = 11

        case 0x1A: // ld a, (de)
            A = await memory.read(from: DE)
            memptr = DE &+ 1
            ts = 7

        case 0x1B: // dec de
            DE.dec()
            ts = 6

        case 0x1C: // inc e
           await inc(.E)

        case 0x1D: // dec e
           await dec(.E)

        case 0x1E: // ld e, n
            E = await next()
            ts = 7

        case 0x1F: // rra
            let carryMask: UInt8 = A & 0x01
            A = A >> 1 | (F & 0x01 > 0 ? 0x80 : 0x00)
            F = preserve(sign, zero, parityOverflow) | carryMask | bits53

        case 0x20: // jr nz, dis
            let dis = await next()
            if F & zero > 0 {
                ts = 7
            } else {
                await relativeJump(twos: dis)
                ts = 12
            }

        case 0x21: // ld hl, nn
            HL = await nextWord()
            ts = 7

        case 0x22: // ld (nn), hl
            let target = await nextWord()
            await memory.writeWord(to: target, value: HL)
            memptr = target &+ 1
            ts = 16
            await controller.memoryMap?.recordData(target, value16Bit: HL)

        case 0x23: // inc hl
            HL.inc()
            ts = 6

        case 0x24:
           await inc(.H)
            break

        case 0x25:
           await dec(.H)
            break

        case 0x26: // ld h, n
            H = await next()

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
                ts += 3
            } else {
                await relativeJump(twos: dis)
                ts += 8
            }


        case 0x29: // add hl, hl
            let addtemp = halfCarryOverflowCalculationAdd16Bit(value: HL, amount: HL)
            let carryMask: UInt8 = HL > addtemp.value ? 0x01 : 0x00
            memptr = HL &+ 1
            HL = addtemp.value //UInt16(addtemp & 0xffff)
            F = preserve(sign, zero, parityOverflow) | addtemp.halfCarryMask | carryMask | bits53OnH
            ts += 7

        case 0x2A: // ld hl, (nn)
            let address = await nextWord()
            HL = await memory.readWord(from: address)
            memptr = address &+ 1
            ts += 16
            //controller.memoryMap?.recordData(address)

        case 0x2B: // dec hl
            HL.dec()
            ts += 2

        case 0x2C:
           await inc(.L)

        case 0x2D:
           await dec(.L)

        case 0x2E: // ld l, n
            L = await next()
            ts += 3

        case 0x2F: // cpl
            A = ~A
            F = preserve(sign, zero, parityOverflow, carry) | bits53 | halfCarry | negative

        case 0x30: // jr nc, dis
            let dis = await next()
            if F & carry > 0 {
                ts += 3
            } else {
                await relativeJump(twos: dis)
                ts += 8
            }

        case 0x31: // ld sp, nn
            SP = await nextWord()
            ts += 6

        case 0x32: // ld (nn), a
            let target = await nextWord()
            await memory.write(to: target, value: A)
            await controller.memoryMap?.recordData(target, value8Bit: A)
            memptr = await wordFrom(high: A, low: (target.lowByte() &+ 1))
            ts += 9

        case 0x33: // inc SP
            SP.inc()
            ts = 6

        case 0x34: // inc (HL)
            let masks = halfCarryOverflowCalculationAdd(value: await memory.read(from: HL), amount: 0x01)
            // memory[Int(HL)] = masks.value
            await memory.write(to: HL, value: masks.value)
            await controller.memoryMap?.recordData(HL, value8Bit: masks.value)
            F = (F & carry) | masks.halfCarryMask | masks.overflowMask | sz53(masks.value)
            ts = 11

        case 0x35:
            let masks = halfCarryOverflowCalculationSub(value: await memory.read(from: HL), amount: 0x01)
            await memory.write(to: HL, value: masks.value)
            await controller.memoryMap?.recordData(HL, value8Bit: masks.value)
            F = (F & carry) | masks.halfCarryMask | masks.overflowMask | sz53(masks.value) | negative
            ts = 11

        case 0x36:
            let nxt = await next()
            await memory.write(to: HL, value: nxt)
            await controller.memoryMap?.recordData(HL, value8Bit: nxt)
            ts = 11

        case 0x37: // scf
            let preserved = preserve(sign, zero, parityOverflow)
            let fiveThree = A & 0x28 //modified53 ? F & 0x28 :
            F = preserved | carry | fiveThree
            break

        case 0x38: // jr c, dis
            let dis = await next()
            if F & carry == 0 {
                ts += 3
            } else {
                await relativeJump(twos: dis)
                ts += 8
            }

        case 0x39:// add hl, sp
            let addtemp = halfCarryOverflowCalculationAdd16Bit(value: HL, amount: SP)
            let carryMask: UInt8 = HL > addtemp.value ? 0x01 : 0x00
            memptr = HL &+ 1
            HL = addtemp.value //UInt16(addtemp & 0xffff)
            F = preserve(sign, zero, parityOverflow) | addtemp.halfCarryMask | carryMask | bits53OnH
            ts += 7

        case 0x3A: // ld A, (nn)
            let target = await nextWord()
            memptr = target &+ 1
            A = await memory.read(from: target)  //memory[target]
            ts = 11
            await controller.memoryMap?.recordData(target, value8Bit: A)

        case 0x3B: // dec SP
            SP.dec()
            ts = 6

        case 0x3C: // inc a
           await inc(.A)

        case 0x3D: // dec a
           await dec(.A)

        case 0x3E: // ld a, n
            A = await next()
            ts = 7

        case 0x3F: // ccf
            let preserved = preserve(sign, zero, parityOverflow)
            let fiveThree = modified53 ? F & 0x28 : A & 0x28
            let hFlag = (F & carry) << 4
            let cFlag = hFlag > 0 ? 0x00 : carry
            F = preserved | cFlag | hFlag | fiveThree


        case 0x40...0x75, 0x77...0x7F: // ld r,r
            let source = opCode & 0x07
            let target = (opCode >> 3) & 0x07
            let sourceValue = await valueFromSource(source: source)
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
            if sourceValue == 0x06 {
                ts = 7
            }

        case 0x76: // halt
            //PC = PC &- 0x01
            isInHaltState = true

        case 0x80...0x87: // add a,r
            let sourceValue = await valueFromSource(source: opCode & 0x07)
            let masks = carryHalfCarryOverflowCalculationAdd(value: A, amount: sourceValue)
            A = masks.value
            F = masks.halfCarryMask | masks.overflowMask | masks.carryMask | sz53(A)
            if sourceValue == 0x06 {
                ts = 7
            }

        case 0x88...0x8F: // adc a,r
            let sourceValue = await valueFromSource(source: opCode & 0x07)
            let masks = carryHalfCarryOverflowCalculationAdd(value: A, amount: sourceValue, carryIn: F & carry)
            A = masks.value
            F = masks.halfCarryMask | masks.overflowMask | masks.carryMask | sz53(A)
            if sourceValue == 0x06 {
                ts = 7
            }

        case 0x90...0x97: // sub a,r
            let sourceValue = await valueFromSource(source: opCode & 0x07)
            let masks = carryHalfCarryOverflowCalculationSub(value: A, amount: sourceValue)
            A = masks.value
            F = masks.halfCarryMask | masks.overflowMask | masks.carryMask | sz53(A) | negative
            if sourceValue == 0x06 {
                ts = 7
            }

        case 0x98...0x9f: // sbc a,r
            let sourceValue = await valueFromSource(source: opCode & 0x07)
            let masks = carryHalfCarryOverflowCalculationSub(value: A, amount: sourceValue, carryIn: F & carry)
            A = masks.value
            F = masks.halfCarryMask | masks.overflowMask | masks.carryMask | sz53(A) | negative
            if sourceValue == 0x06 {
                ts = 7
            }

        case 0xA0...0xA7: // and r
            let sourceValue = await valueFromSource(source: opCode & 0x07)
            A = A & sourceValue
            F = sz53pv(A) | halfCarry
            if sourceValue == 0x06 {
                ts = 7
            }

        case 0xA8...0xAF: // xor r
            let sourceValue = await valueFromSource(source: opCode & 0x07)
            A = A ^ sourceValue
            F = sz53pv(A)
            if sourceValue == 0x06 {
                ts = 7
            }

        case 0xB0...0xB7: //or r
            let sourceValue = await valueFromSource(source: opCode & 0x07)
            A = A | sourceValue
            F = sz53pv(A)
            if sourceValue == 0x06 {
                ts = 7
            }

        case 0xB8...0xBF: // cp r
            let sourceValue = await valueFromSource(source: opCode & 0x07)
            let masks = carryHalfCarryOverflowCalculationSub(value: A, amount: sourceValue)
            F = masks.halfCarryMask | masks.overflowMask | masks.carryMask | (sz53(masks.value) & 0xC0) | negative | bits53(sourceValue)
            if sourceValue == 0x06 {
                ts = 7
            }

        case 0xC0: // ret nz
            if (F & zero) == 0 {
                await ret()
                ts = 11
            } else {
                ts = 5
            }

        case 0xC1: // pop bc
            BC = await pop()
            ts = 10

        case 0xC2: // jp nz, nn
            let target = await nextWord()
            if (F & zero) == 0 {
                await jump(target)
            } else {
                memptr = target
            }
            ts = 10

        case 0xC3: // jp nn
            await jump(await nextWord())
            ts = 10

        case 0xC4: // call nz, nn
            let target = await nextWord()
            if (F & zero) == 0 {
                await push(PC)
                await jump(target)
                ts = 17
            } else {
                ts = 10
                memptr = target
            }

        case 0xC5: // push bc
            await push(BC)
            ts = 11

        case 0xC6:// add a,n
            let sourceValue = await next()
            let masks = carryHalfCarryOverflowCalculationAdd(value: A, amount: sourceValue)
            A = masks.value
            F = masks.halfCarryMask | masks.overflowMask | masks.carryMask | sz53(A)
            ts = 7

        case 0xC7: // RST 0x00
            await push(PC)
            await jump(0x00)
            ts = 11

        case 0xC8:// ret z
            if (F & zero) > 0 {
                await ret()
                ts = 11
            } else {
                ts = 5
            }

        case 0xC9: // ret
            await ret()
            ts = 10

        case 0xCA:// jp z, nn
            let target = await nextWord()
            if (F & zero) > 0 {
                await jump(target)
            } else {
                memptr = target
            }
            ts = 10

        case 0xCB:
            await opCodeCB()
            ts = 0
            mCycles = 0

        case 0xCC: // call z, nn
            let target = await nextWord()
            if (F & zero) > 0 {
                await push(PC)
                await jump(target)
                ts = 17
            } else {
                ts = 10
                memptr = target
            }

        case 0xCD: // call nn
            let target = await nextWord()
            await push(PC)
            await jump(target)
            ts = 17

        case 0xCE: // adc a,n
            let sourceValue = await next()
            let masks = carryHalfCarryOverflowCalculationAdd(value: A, amount: sourceValue, carryIn: F & carry)
            A = masks.value
            F = masks.halfCarryMask | masks.overflowMask | masks.carryMask | sz53(A)
            ts = 7

        case 0xCF: // RST 0x08
            await push(PC)
            await jump(0x08)
            ts = 11

        case 0xD0:// ret nc
            if (F & carry) == 0 {
                await ret()
                ts = 11
            } else {
                ts = 5
            }

        case 0xD1: // pop de
            DE = await pop()
            ts = 10

        case 0xD2: // jp nc, nn
            let target = await nextWord()
            if (F & carry) == 0 {
                await jump(target)
            } else {
                memptr = target
            }
            ts = 10

        case 0xD3: // out (n) a
            let port = await next()
            await performOut(port: port, map: nil, value: A)
            ts = 11
            memptr = await wordFrom(high: A, low: port &+ 1)

        case 0xD4: // call nc, nn
            let target = await nextWord()
            if (F & carry) == 0 {
                await push(PC)
                await jump(target)
                ts = 17
            } else {
                ts = 10
                memptr = target
            }

        case 0xD5: // push de
            await push(DE)
            ts = 11

        case 0xD6:// add a,n
            let sourceValue = await next()
            let masks = carryHalfCarryOverflowCalculationSub(value: A, amount: sourceValue)
            A = masks.value
            F = masks.halfCarryMask | masks.overflowMask | masks.carryMask | sz53(A) | negative
            ts = 7

        case 0xD7: // RST 0x10
            await push(PC)
            await jump(0x10)
            ts = 11

        case 0xD8:// ret c
            if (F & carry) > 0 {
                await ret()
                ts = 11
            } else {
                ts = 5
            }

        case 0xD9: // exx
            await swapBC()
            await swapDE()
            await swapHL()
            ts = 4

        case 0xDA:// jp c, nn
            let target = await nextWord()
            if (F & carry) > 0 {
                await jump(target)
            } else {
                memptr = target
            }
            ts = 10

        case 0xDB: // in a, (n)
            let oldA = UInt16(A) << 8
            let port = await next()
            A = await performIn(port: port, map: A)
            memptr = oldA &+ UInt16(port) &+ 1

        case 0xDC: // call c, nn
            let target = await nextWord()
            if (F & carry) > 0 {
                await push(PC)
                await jump(target)
                ts = 17
            } else {
                ts = 10
                memptr = target
            }

        case 0xDD: // IX opCodes
            await opCodeDDFD(index: .IX)
            ts = 0
            mCycles = 0

        case 0xDE: // sbc a,n
            let sourceValue = await next()
            let masks = carryHalfCarryOverflowCalculationSub(value: A, amount: sourceValue, carryIn: F & carry)
            A = masks.value
            F = masks.halfCarryMask | masks.overflowMask | masks.carryMask | sz53(A) | negative
            ts = 7

        case 0xDF: // RST 0x18
            await push(PC)
            await jump(0x18)
            ts = 11

        case 0xE0:// ret po
            if (F & parityOverflow) == 0 {
                await ret()
                ts = 11
            } else {
                ts = 5
            }

        case 0xE1: // pop hl
            HL = await pop()
            ts = 10

        case 0xE2: // jp po, nn
            let target = await nextWord()
            if (F & parityOverflow) == 0 {
                await jump(target)
            } else {
                memptr = target
            }
            ts = 10

        case 0xE3: // ex (sp), hl
            let temp = HL
            HL = await memory.readWord(from: SP)
            await memory.writeWord(to: SP, value: temp)
            memptr = HL
            ts = 19

        case 0xE4: // call po, nn
            let target = await nextWord()
            if (F & parityOverflow) == 0 {
                await push(PC)
                await jump(target)
                ts = 17
            } else {
                ts = 10
                memptr = target
            }

        case 0xE5: // push hl
            await push(HL)
            ts = 11

        case 0xE6:// and n
            let sourceValue = await next()
            A = A & sourceValue
            F = sz53pv(A) | halfCarry
            ts = 7

        case 0xE7: // RST 0x20
            await push(PC)
            await jump(0x20)
            ts = 11

        case 0xE8:// ret pe
            if (F & parityOverflow) > 0 {
                await ret()
                ts = 11
            } else {
                ts = 5
            }

        case 0xE9: // jp (hl)
            PC = HL

        case 0xEA:// jp pe, nn
            let target = await nextWord()
            if (F & parityOverflow) > 0 {
                await jump(target)
            } else {
                memptr = target
            }
            ts = 10

        case 0xEB: // ex de, hl
            let temp = HL
            HL = DE
            DE = temp

        case 0xEC: // call pe, nn
            let target = await nextWord()
            if (F & parityOverflow) > 0 {
                await push(PC)
                await jump(target)
                ts = 17
            } else {
                ts = 10
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
            ts = 7

        case 0xEF: // RST 0x28
            await push(PC)
            await jump(0x28)
            ts = 11

        case 0xF0:// ret p
            if (F & sign) == 0 {
                await ret()
                ts = 11
            } else {
                ts = 5
            }

        case 0xF1: // pop af
            AF = await pop()
            ts = 10

        case 0xF2: // jp p, nn
            let target = await nextWord()
            if (F & sign) == 0 {
                await jump(target)
            } else {
                memptr = target
            }
            ts = 10

        case 0xF3: // di
            iff1 = 0
            iff2 = 0

        case 0xF4: // call p, nn
            let target = await nextWord()
            if (F & sign) == 0 {
                await push(PC)
                await jump(target)
                ts = 17
            } else {
                ts = 10
                memptr = target
            }

        case 0xF5: // push af
            await push(AF)
            ts = 11

        case 0xF6: // or n
            let sourceValue = await next()
            A = A | sourceValue
            F = sz53pv(A)
            ts = 7

        case 0xF7: // RST 0x30
            await push(PC)
            await jump(0x30)
            ts = 11

        case 0xF8: // ret m
            if (F & sign) > 0 {
                await ret()
                ts = 11
            } else {
                ts = 5
            }

        case 0xF9: // ld sp, hl
            SP = HL
            ts = 6

        case 0xFA:// jp m, nn
            let target = await nextWord()
            if (F & sign) > 0 {
                await jump(target)
            } else {
                memptr = target
            }
            ts = 10

        case 0xFB: // ei
            iff1 = 1
            iff2 = 1

        case 0xFC: // call m, nn
            let target = await nextWord()
            if (F & sign) > 0 {
                await push(PC)
                await jump(target)
                ts = 17
            } else {
                ts = 10
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
            ts = 7

        case 0xFF: // RST 0x38
            await push(PC)
            await jump(0x38)
            ts = 11

        default:
            break
        }
        await mCyclesAndTStates(m: mCycles, t: ts)
       // Task {
       //     LoggingService.shared.logProcessor(oldPC, opcode: opCode.hex(), message: nil)
      //  }
    }
}
