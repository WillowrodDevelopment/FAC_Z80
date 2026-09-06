//
//  Z80+ED_OpCodes.swift
//  Fake-A-Chip
//
//  Created by Mike Hall on 23/05/2023.
//

import Foundation

extension Z80 {
    func opCodeED() {
        var ts = 12
        var mCycles = 2
        let opCode = next()
        switch opCode {
        case 0x00...0x3f: // Z180 only
//            let code = opCode & 0x07
//            let target = opCode >> 3
//            switch code {
//            case 0:
//
//            case 1:
//
//            case 4:
//
//            default:
                break
//            }

        case 0x40:
            let port = C
            B = performIn(port: port, map: B)
            let old = UInt16(B) << 8
            memptr = old &+ UInt16(port) &+ 1
            F = preserve(carry) | sz53pv(B)

        case 0x41:
            let port = C
            performOut(port: port, map: B, value: B)
            let old = UInt16(B) << 8
            memptr = old &+ UInt16(port) &+ 1

        case 0x42: // SBC HL,BC
            memptr = HL &+ 1
            let masks = halfCarryOverflowCalculationSub16Bit(value: HL, amount: BC, carryIn: (F & carry))
            HL = masks.value
            F = masks.halfCarryMask | masks.overflowMask | masks.carryMask | (sz53(HL.highByte()) & 0xA8) | negative | (HL == 0 ? 0x40 : 0x00)
            ts = 15

        case 0x43: // LD (nn), BC
            let address = nextWord()
            memory.writeWord(to: address, value: BC)
            memptr = address &+ 1
            ts = 20

        case 0x44, 0x4C, 0x54, 0x5C, 0x64, 0x6c, 0x74, 0x7c: // NEG
            let masks = carryHalfCarryOverflowCalculationSub(value: 0x00, amount: A)
            A = masks.value
            F = negative | sz53(A) | masks.carryMask | masks.halfCarryMask | masks.overflowMask
            ts = 8

        case 0x45, 0x4D, 0x55, 0x5D, 0x65, 0x6D, 0x75, 0x7D: // RETN
            PC = pop()
            iff1 = iff2
            memptr = PC
            ts = 14

        case 0x4E, 0x6E: // IM 0
            interuptMode = 0
            ts = 8
            
        case 0x46, 0x66: // IM 0
            interuptMode = 0
            ts = 8

        case 0x47: // LD I, A
            I = A
            ts = 9


        case 0x48:
            let port = C
            C = performIn(port: port, map: B)
            let old = UInt16(B) << 8
            memptr = old &+ UInt16(C) &+ 1
            F = preserve(carry) | sz53pv(C)

        case 0x49:
            let port = C
            performOut(port: port, map: B, value: C)
            let old = UInt16(B) << 8
            memptr = old &+ UInt16(port) &+ 1

        case 0x4A: // ADC HL,BC
            memptr = HL &+ 1
            let masks = halfCarryOverflowCalculationAdd16Bit(value: HL, amount: BC, carryIn: (F & carry))
            HL = masks.value
            F = masks.halfCarryMask | masks.overflowMask | masks.carryMask | (sz53(HL.highByte()) & 0xA8) | (HL == 0 ? 0x40 : 0x00)
            ts = 15

        case 0x4B: // LD BC, (nn)
            let address = nextWord()
            BC = memory.readWord(from: address)
            memptr = address &+ 1
            ts = 20

        case 0x4F: // LD R, A
            R = A
            mCycles = 0
            ts = 9

        case 0x50:
            let port = C
            D = performIn(port: port, map: B)
            let old = UInt16(B) << 8
            memptr = old &+ UInt16(port) &+ 1
            F = preserve(carry) | sz53pv(D)

        case 0x51:
            let port = C
            performOut(port: port, map: B, value: D)
            let old = UInt16(B) << 8
            memptr = old &+ UInt16(port) &+ 1

        case 0x52: // SBC HL,DE
            memptr = HL &+ 1
            let masks = halfCarryOverflowCalculationSub16Bit(value: HL, amount: DE, carryIn: (F & carry))
            HL = masks.value
            F = masks.halfCarryMask | masks.overflowMask | masks.carryMask | (sz53(HL.highByte()) & 0xA8) | negative | (HL == 0 ? 0x50 : 0x00)
            ts = 15

        case 0x53: // LD (nn), DE
            let address = nextWord()
            memory.writeWord(to: address, value: DE)
            memptr = address &+ 1
            ts = 20

        case 0x56, 0x76: // IM 1
            interuptMode = 1
            ts = 8

        case 0x57: // LD A, I
            A = I
            F = preserve(carry) | sz53(A) | (iff2 << 2)
            ts = 9


        case 0x58:
            let port = C
            E = performIn(port: port, map: B)
            let old = UInt16(B) << 8
            memptr = old &+ UInt16(C) &+ 1
            F = preserve(carry) | sz53pv(E)

        case 0x59:
            let port = C
            performOut(port: port, map: B, value: E)
            let old = UInt16(B) << 8
            memptr = old &+ UInt16(port) &+ 1

        case 0x5A: // ADC HL,DE
            memptr = HL &+ 1
            let masks = halfCarryOverflowCalculationAdd16Bit(value: HL, amount: DE, carryIn: (F & carry))
            HL = masks.value
            F = masks.halfCarryMask | masks.overflowMask | masks.carryMask | (sz53(HL.highByte()) & 0xA8) | (HL == 0 ? 0x50 : 0x00)
            ts = 15

        case 0x5B: // LD DE, (nn)
            let address = nextWord()
            DE = memory.readWord(from: address)
            memptr = address &+ 1
            ts = 20

        case 0x5E, 0x7E: // IM 2

            interuptMode = 2
            ts = 8

        case 0x5F: // LD A, R
            let bit7 = R & 0x80
            R = ((R &+ UInt8(2)) & 0x7F) | bit7
            A = R
            F = preserve(carry) | sz53(A) | (iff2 << 2)
            mCycles = 0
            ts = 9

        case 0x60:
            let port = C
            H = performIn(port: port, map: B)
            let old = UInt16(B) << 8
            memptr = old &+ UInt16(port) &+ 1
            F = preserve(carry) | sz53pv(H)

        case 0x61:
            let port = C
            performOut(port: port, map: B, value: H)
            let old = UInt16(B) << 8
            memptr = old &+ UInt16(port) &+ 1

        case 0x62: // SBC HL,HL
            memptr = HL &+ 1
            let masks = halfCarryOverflowCalculationSub16Bit(value: HL, amount: HL, carryIn: (F & carry))
            HL = masks.value
            F = masks.halfCarryMask | masks.overflowMask | masks.carryMask | sz53(HL.highByte()) | negative
            ts = 15

        case 0x63: // LD (nn), HL
            let address = nextWord()
            memory.writeWord(to: address, value: HL)
            memptr = address &+ 1
            ts = 20

        case 0x67: // RRD

        let part1 = A & 0xF0
        let part2 = (A & 0x0F) << 4
        let hl = memory.read(from: HL)
        let part3 = (hl & 0xF0) >> 4
        let part4 = hl & 0x0F
        A = part1 | part4
        memory.write(to: HL, value: (part3 | part2))
            F = preserve(carry) | sz53pv(A)
            memptr = HL &+ 1
            ts = 18

        case 0x68:
            let port = C
            L = performIn(port: port, map: B)
            let old = UInt16(B) << 8
            memptr = old &+ UInt16(C) &+ 1
            F = preserve(carry) | sz53pv(L)

        case 0x69:
            let port = C
            performOut(port: port, map: B, value: L)
            let old = UInt16(B) << 8
            memptr = old &+ UInt16(port) &+ 1

        case 0x6A: // ADC HL,HL
            memptr = HL &+ 1
            let masks = halfCarryOverflowCalculationAdd16Bit(value: HL, amount: HL, carryIn: (F & carry))
            HL = masks.value
            F = masks.halfCarryMask | masks.overflowMask | masks.carryMask | (sz53(HL.highByte()) & 0xA8)
            ts = 15

        case 0x6B: // LD HL, (nn)
            let address = nextWord()
            HL = memory.readWord(from: address)
            memptr = address &+ 1
            ts = 20


        case 0x6F: // RLD

        let part1 = A & 0xF0
        let part2 = (A & 0x0F)
        let hl = memory.read(from: HL)
        let part3 = (hl & 0xF0) >> 4
        let part4 = (hl & 0x0F) << 4
        A = part1 | part3
        memory.write(to: HL, value: (part4 | part2))
            F = preserve(carry) | sz53pv(A)
            memptr = HL &+ 1
            ts = 18

        case 0x70: // IN (C)
            let port = C
            let value = performIn(port: port, map: B)
            let old = UInt16(B) << 8
            memptr = old &+ UInt16(port) &+ 1
            F = preserve(carry) | sz53pv(value)

        case 0x71: // OUT (C), 0
            let port = C
            performOut(port: port, map: B, value: 0x00)

        case 0x72: // SBC HL,SP
            memptr = HL &+ 1
            let masks = halfCarryOverflowCalculationSub16Bit(value: HL, amount: SP, carryIn: (F & carry))
            HL = masks.value
            F = masks.halfCarryMask | masks.overflowMask | masks.carryMask | (sz53(HL.highByte()) & 0xA8) | negative | (HL == 0 ? 0x70 : 0x00)
            ts = 15

        case 0x73: // LD (nn), SP
            let address = nextWord()
            memory.writeWord(to: address, value: SP)
            memptr = address &+ 1
            ts = 20

        case 0x78: // IN A, (C)
            let port = C
            A = performIn(port: port, map: B)
            let old = UInt16(B) << 8
            memptr = old &+ UInt16(port) &+ 1
            F = preserve(carry) | sz53pv(A)

        case 0x79: // OUT (C), A
            let port = C
            performOut(port: port, map: B, value: A)
            let old = UInt16(B) << 8
            memptr = old &+ UInt16(port) &+ 1

        case 0x7A: // ADC HL,SP
            memptr = HL &+ 1
            let masks = halfCarryOverflowCalculationAdd16Bit(value: HL, amount: SP, carryIn: (F & carry))
            HL = masks.value
            F = masks.halfCarryMask | masks.overflowMask | masks.carryMask | (sz53(HL.highByte()) & 0xA8)
            ts = 15

        case 0x7B: // LD SP, (nn)
            let address = nextWord()
            SP = memory.readWord(from: address)
            memptr = address &+ 1
            ts = 20

        case 0xA0: // LDI
            let transferedByte = memory.read(from: HL)
            if DE >= 0x4000 && DE <= 0x57FF {
                recordGraphicsSourceBanked(HL)
            }
            memory.write(to: DE, value: transferedByte)
            DE.inc()
            HL.inc()
            BC.dec()
            let byteFor53 = transferedByte &+ A
            F = preserve(sign, zero, carry) | bits53ForCopy(byteFor53)
            ts = 16


        case 0xA1: // CPI
            let transferedByte = memory.read(from: HL)
            HL.inc()
            BC.dec()
            let masks = carryHalfCarryOverflowCalculationSub(value: A, amount: transferedByte)
            let byteFor53 = A &- transferedByte &- (masks.halfCarryMask >> 4)
            F = preserve(carry) | masks.halfCarryMask | (sz53(masks.value) & 0xC0) | negative | bits53ForCopy(byteFor53)
            memptr = memptr &+ 1
            ts = 16
            

        case 0xA2: // INI
            let value = performIn(port: C, map: B)
            memory.write(to: HL, value: value)
            HL.inc()
            memptr = BC &+ 1
            dec(.B)
            let bit1: UInt8 = (value & 0x80) >> 6 // copy of bit 7 of transfered value
            let calculation: UInt8 = value &+ C &+ 1
            let bits0And4: UInt8 = (calculation >= value ? 0x00 : 0x11) // If overflows
            let parityCalculation: UInt8 = (calculation & 0x07) ^ B
            let bit2: UInt8 = parityBit[parityCalculation]
            F = sz53(B) | bits0And4 | bit1 | bit2
            ts = 16


        case 0xA3: // OUTI
            let value = memory.read(from: HL)
            performOut(port: C, map: B, value: value)
            HL.inc()
            dec(.B)
            let bit1: UInt8 = (value & 0x80) >> 6 // copy of bit 7 of transfered value
            let calculation: UInt8 = value &+ L
            let bits0And4: UInt8 = (calculation >= value ? 0x00 : 0x11) // If overflows
            let parityCalculation: UInt8 = (calculation & 0x07) ^ B
            let bit2: UInt8 = parityBit[parityCalculation]
            F = sz53(B) | bits0And4 | bit1 | bit2
            memptr = BC &+ 1
            ts = 16


        case 0xA8: // LDD
            let transferedByte = memory.read(from: HL)
            if DE >= 0x4000 && DE <= 0x57FF {
                recordGraphicsSourceBanked(HL)
            }
            memory.write(to: DE, value: transferedByte)
            DE.dec()
            HL.dec()
            BC.dec()
            let byteFor53 = transferedByte &+ A
            F = preserve(sign, zero, carry) | bits53ForCopy(byteFor53)
            ts = 16


        case 0xA9: // CPD
            let transferedByte = memory.read(from: HL)
            HL.dec()
            BC.dec()
            let masks = carryHalfCarryOverflowCalculationSub(value: A, amount: transferedByte)
            let byteFor53 = A &- transferedByte &- (masks.halfCarryMask >> 4)
            F = preserve(carry) | masks.halfCarryMask | (sz53(masks.value) & 0xC0) | negative | bits53ForCopy(byteFor53)
            memptr = memptr &- 1
            ts = 16


        case 0xAA: // IND
            let value = performIn(port: C, map: B)
            memory.write(to: HL, value: value)
            HL.dec()
            memptr = BC &- 1
            dec(.B)
            let bit1: UInt8 = (value & 0x80) >> 6 // copy of bit 7 of transfered value
            let calculation: UInt8 = value &+ C &- 1
            let bits0And4: UInt8 = (calculation >= value ? 0x00 : 0x11) // If overflows
            let parityCalculation: UInt8 = (calculation & 0x07) ^ B
            let bit2: UInt8 = parityBit[parityCalculation]
            F = sz53(B) | bits0And4 | bit1 | bit2
            ts = 16


        case 0xAB: // OUTD
            let value = memory.read(from: HL)
            performOut(port: C, map: B, value: value)
            HL.dec()
            dec(.B)
            let bit1: UInt8 = (value & 0x80) >> 6 // copy of bit 7 of transfered value
            let calculation: UInt8 = value &+ L
            let bits0And4: UInt8 = (calculation >= value ? 0x00 : 0x11) // If overflows
            let parityCalculation: UInt8 = (calculation & 0x07) ^ B
            let bit2: UInt8 = parityBit[parityCalculation]
            F = sz53(B) | bits0And4 | bit1 | bit2
            memptr = BC &- 1
            ts = 16

        case 0xB0: // LDIR
            let transferedByte = memory.read(from: HL)
            if DE >= 0x4000 && DE <= 0x57FF {
                recordGraphicsSourceBanked(HL)
            }
            memory.write(to: DE, value: transferedByte)
            BC.dec()
            let byteFor53 = transferedByte &+ A
            F = preserve(sign, zero, carry) | bits53ForCopy(byteFor53)
            DE.inc()
            HL.inc()
            if BC != 0 {
                PC = PC &- 2
                memptr = PC &+ 1
                F = (F & (sign | zero | carry | parityOverflow)) | bits35FromPC(PC)
                ts = 21
            } else {
                ts = 16
            }

        case 0xB1: // CPIR
            let transferedByte = memory.read(from: HL)
            HL.inc()
            BC.dec()
            let masks = carryHalfCarryOverflowCalculationSub(value: A, amount: transferedByte)
            let byteFor53 = A &- transferedByte &- (masks.halfCarryMask >> 4)
            F = preserve(carry) | masks.halfCarryMask | (sz53(masks.value) & 0xC0) | negative | bits53ForCopy(byteFor53)
            if BC != 0 && A != transferedByte {
                PC = PC &- 2
                memptr = PC &+ 1
                F = (F & (sign | zero | carry | parityOverflow | negative | halfCarry)) | bits35FromPC(PC)
                ts = 21
            } else {
                ts = 16
                memptr = memptr &+ 1
            }


        case 0xB2: // INIR
            let value = performIn(port: C, map: B)
            memory.write(to: HL, value: value)
            HL.inc()
            memptr = BC &+ 1
            dec(.B)
            let sum16 = UInt16(UInt8(C &+ 1)) &+ UInt16(value)
            let carryFlag: UInt8 = sum16 > 0xFF ? carry : 0
            let nFlag: UInt8 = (value & 0x80) >> 6
            let pvFlag: UInt8 = parityBit[UInt8(sum16 & 0x07) ^ B]
            if B != 0 {
                PC = PC &- 2
                let adj = blockRepeatFlagAdjustment(carryFlag: carryFlag, nFlag: nFlag, pvFlag: pvFlag, b: B, pc: PC)
                F = (sz53(B) & (sign | zero)) | adj.bits35 | adj.h | adj.pv | nFlag | carryFlag
                ts = 21
            } else {
                F = (sz53(B) & (sign | zero)) | (B & (three | five)) | (carryFlag << 4) | pvFlag | nFlag | carryFlag
                ts = 16
            }


        case 0xB3: // OTIR
            let value = memory.read(from: HL)
            performOut(port: C, map: B, value: value)
            HL.inc()
            dec(.B)
            let sum16 = UInt16(UInt8(L)) &+ UInt16(value)
            let carryFlag: UInt8 = sum16 > 0xFF ? carry : 0
            let nFlag: UInt8 = (value & 0x80) >> 6
            let pvFlag: UInt8 = parityBit[UInt8(sum16 & 0x07) ^ B]
            memptr = BC &+ 1
            if B != 0 {
                PC = PC &- 2
                let adj = blockRepeatFlagAdjustment(carryFlag: carryFlag, nFlag: nFlag, pvFlag: pvFlag, b: B, pc: PC)
                F = (sz53(B) & (sign | zero)) | adj.bits35 | adj.h | adj.pv | nFlag | carryFlag
                ts = 21
            } else {
                F = (sz53(B) & (sign | zero)) | (B & (three | five)) | (carryFlag << 4) | pvFlag | nFlag | carryFlag
                ts = 16
            }


        case 0xB8: // LDDR
            let transferedByte = memory.read(from: HL)
            if DE >= 0x4000 && DE <= 0x57FF {
                recordGraphicsSourceBanked(HL)
            }
            memory.write(to: DE, value: transferedByte)
            DE.dec()
            HL.dec()
            BC.dec()
            let byteFor53 = transferedByte &+ A
            F = preserve(sign, zero, carry) | bits53ForCopy(byteFor53)
            if BC != 0 {
                PC = PC &- 2
                memptr = PC &+ 1
                F = (F & (sign | zero | carry | parityOverflow)) | bits35FromPC(PC)
                ts = 21
            } else {
                ts = 16
            }


        case 0xB9: // CPDR
            let transferedByte = memory.read(from: HL)
            HL.dec()
            BC.dec()
            let masks = carryHalfCarryOverflowCalculationSub(value: A, amount: transferedByte)
            let byteFor53 = A &- transferedByte &- (masks.halfCarryMask >> 4)
            F = preserve(carry) | masks.halfCarryMask | (sz53(masks.value) & 0xC0) | negative | bits53ForCopy(byteFor53)
            if BC != 0 && A != transferedByte {
                PC = PC &- 2
                memptr = PC &+ 1
                F = (F & (sign | zero | carry | parityOverflow | negative | halfCarry)) | bits35FromPC(PC)
                ts = 21
            } else {
                memptr = memptr &+ 1
                ts = 16
            }


        case 0xBA: // INDR
            let value = performIn(port: C, map: B)
            memory.write(to: HL, value: value)
            HL.dec()
            memptr = BC &- 1
            dec(.B)
            let sum16 = UInt16(UInt8(C &- 1)) &+ UInt16(value)
            let carryFlag: UInt8 = sum16 > 0xFF ? carry : 0
            let nFlag: UInt8 = (value & 0x80) >> 6
            let pvFlag: UInt8 = parityBit[UInt8(sum16 & 0x07) ^ B]
            if B != 0 {
                PC = PC &- 2
                let adj = blockRepeatFlagAdjustment(carryFlag: carryFlag, nFlag: nFlag, pvFlag: pvFlag, b: B, pc: PC)
                F = (sz53(B) & (sign | zero)) | adj.bits35 | adj.h | adj.pv | nFlag | carryFlag
                ts = 21
            } else {
                F = (sz53(B) & (sign | zero)) | (B & (three | five)) | (carryFlag << 4) | pvFlag | nFlag | carryFlag
                ts = 16
            }


        case 0xBB: // OTDR
            let value = memory.read(from: HL)
            performOut(port: C, map: B, value: value)
            HL.dec()
            dec(.B)
            let sum16 = UInt16(UInt8(L)) &+ UInt16(value)
            let carryFlag: UInt8 = sum16 > 0xFF ? carry : 0
            let nFlag: UInt8 = (value & 0x80) >> 6
            let pvFlag: UInt8 = parityBit[UInt8(sum16 & 0x07) ^ B]
            memptr = BC &- 1
            if B != 0 {
                PC = PC &- 2
                let adj = blockRepeatFlagAdjustment(carryFlag: carryFlag, nFlag: nFlag, pvFlag: pvFlag, b: B, pc: PC)
                F = (sz53(B) & (sign | zero)) | adj.bits35 | adj.h | adj.pv | nFlag | carryFlag
                ts = 21
            } else {
                F = (sz53(B) & (sign | zero)) | (B & (three | five)) | (carryFlag << 4) | pvFlag | nFlag | carryFlag
                ts = 16
            }
            
        case 0x77, 0x7F: // Masks a NOP
            ts = 8

        default:
            break
            ts = 8
        }
        accumulate(m: mCycles, t: ts)
    }

    func blockRepeatFlagAdjustment(carryFlag: UInt8, nFlag: UInt8, pvFlag: UInt8, b: UInt8, pc: UInt16) -> (pv: UInt8, h: UInt8, bits35: UInt8) {
        var pv = pvFlag
        var h = carryFlag
        if carryFlag != 0 {
            if nFlag != 0 {
                pv = (pv == parityBit[(b &- 1) & 0x07]) ? parityOverflow : 0
                h = (b & 0x0F) == 0 ? halfCarry : 0
            } else {
                pv = (pv == parityBit[(b &+ 1) & 0x07]) ? parityOverflow : 0
                h = (b & 0x0F) == 0x0F ? halfCarry : 0
            }
        } else {
            pv = (pv == parityBit[b & 0x07]) ? parityOverflow : 0
        }
        return (pv, h, bits35FromPC(pc))
    }

    func bits35FromPC(_ pc: UInt16) -> UInt8 {
        UInt8(((pc >> 13) & 1) << 5) | UInt8(((pc >> 11) & 1) << 3)
    }
}
