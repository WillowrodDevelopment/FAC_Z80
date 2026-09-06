//
//  Z80+8BitCalculations.swift
//  Fake-A-Chip
//
//  Created by Mike Hall on 24/05/2023.
//

import Foundation

extension Z80 {
    func inc(_ register: Z808BitRegister) {
        var masks = initialMasks
        switch register {
        case .A:
            masks = halfCarryOverflowCalculationAdd(value: A, amount: 0x01)
            A = masks.value
        case .B:
            masks = halfCarryOverflowCalculationAdd(value: B, amount: 0x01)
            B = masks.value
        case .C:
            masks = halfCarryOverflowCalculationAdd(value: C, amount: 0x01)
            C = masks.value
        case .D:
            masks = halfCarryOverflowCalculationAdd(value: D, amount: 0x01)
            D = masks.value
        case .E:
            masks = halfCarryOverflowCalculationAdd(value: E, amount: 0x01)
            E = masks.value
        case .L:
            masks = halfCarryOverflowCalculationAdd(value: L, amount: 0x01)
            L = masks.value
        case .H:
            masks = halfCarryOverflowCalculationAdd(value: H, amount: 0x01)
            H = masks.value
        case .SPARE:
            masks = halfCarryOverflowCalculationAdd(value: SPARE8, amount: 0x01)
            SPARE8 = masks.value
        case .I:
            masks = halfCarryOverflowCalculationAdd(value: I, amount: 0x01)
            I = masks.value
        case .R:
            masks = halfCarryOverflowCalculationAdd(value: R, amount: 0x01)
            R = masks.value
        case .F:
            break
        }
        F = (F & carry) | masks.halfCarryMask | masks.overflowMask | sz53(masks.value)
    }

    func dec(_ register: Z808BitRegister) {
        var masks = initialMasks
        switch register {
        case .A:
            masks = halfCarryOverflowCalculationSub(value: A, amount: 0x01)
            A = masks.value
        case .B:
            masks = halfCarryOverflowCalculationSub(value: B, amount: 0x01)
            B = masks.value
        case .C:
            masks = halfCarryOverflowCalculationSub(value: C, amount: 0x01)
            C = masks.value
        case .D:
            masks = halfCarryOverflowCalculationSub(value: D, amount: 0x01)
            D = masks.value
        case .E:
            masks = halfCarryOverflowCalculationSub(value: E, amount: 0x01)
            E = masks.value
        case .L:
            masks = halfCarryOverflowCalculationSub(value: L, amount: 0x01)
            L = masks.value
        case .H:
            masks = halfCarryOverflowCalculationSub(value: H, amount: 0x01)
            H = masks.value
        case .SPARE:
            masks = halfCarryOverflowCalculationSub(value: SPARE8, amount: 0x01)
            SPARE8 = masks.value
        case .I:
            masks = halfCarryOverflowCalculationSub(value: I, amount: 0x01)
            I = masks.value
        case .R:
            masks = halfCarryOverflowCalculationSub(value: R, amount: 0x01)
            R = masks.value
        case .F:
            break
        }
        F = (F & carry) | masks.halfCarryMask | masks.overflowMask | sz53(masks.value) | negative
    }

    func inc(_ index: Z8016BitRegister, isHigh: Bool) {
        var masks = initialMasks
        switch index {
        case .IX:
            if isHigh {
                masks = halfCarryOverflowCalculationAdd(value: IX.highByte(), amount: 0x01)
                writeIndex(index, value: wordFrom(high: masks.value, low: IX.lowByte()))
            } else {
                masks = halfCarryOverflowCalculationAdd(value: IX.lowByte(), amount: 0x01)
                writeIndex(index, value: wordFrom(high: IX.highByte(), low: masks.value))
            }
        case .IY:
            if isHigh {
                masks = halfCarryOverflowCalculationAdd(value: IY.highByte(), amount: 0x01)
                writeIndex(index, value: wordFrom(high: masks.value, low: IY.lowByte()))
            } else {
                masks = halfCarryOverflowCalculationAdd(value: IY.lowByte(), amount: 0x01)
                writeIndex(index, value: wordFrom(high: IY.highByte(), low: masks.value))
            }
        default:
            break
        }
        F = (F & carry) | masks.halfCarryMask | masks.overflowMask | sz53(masks.value)
    }

    func dec(_ index: Z8016BitRegister, isHigh: Bool) {
        var masks = initialMasks
        switch index {
        case .IX:
            if isHigh {
                masks = halfCarryOverflowCalculationSub(value: IX.highByte(), amount: 0x01)
                writeIndex(index, value: wordFrom(high: masks.value, low: IX.lowByte()))
            } else {
                masks = halfCarryOverflowCalculationSub(value: IX.lowByte(), amount: 0x01)
                writeIndex(index, value: wordFrom(high: IX.highByte(), low: masks.value))
            }
        case .IY:
            if isHigh {
                masks = halfCarryOverflowCalculationSub(value: IY.highByte(), amount: 0x01)
                writeIndex(index, value: wordFrom(high: masks.value, low: IY.lowByte()))
            } else {
                masks = halfCarryOverflowCalculationSub(value: IY.lowByte(), amount: 0x01)
                writeIndex(index, value: wordFrom(high: IY.highByte(), low: masks.value))
            }
        default:
            break
        }
       
        F = (F & carry) | masks.halfCarryMask | masks.overflowMask | sz53(masks.value) | negative
    }

    func rlc(_ register: Z808BitRegister) {
        var masks: (value: UInt8, carryMask: UInt8) = (value: 0x00, carryMask: 0x00)
        switch register {
        case .A:
            masks = A.rlc()
            A = masks.value
        case .B:
            masks = B.rlc()
            B = masks.value
        case .C:
            masks = C.rlc()
            C = masks.value
        case .D:
            masks = D.rlc()
            D = masks.value
        case .E:
            masks = E.rlc()
            E = masks.value
        case .L:
            masks = L.rlc()
            L = masks.value
        case .H:
            masks = H.rlc()
            H = masks.value
        case .SPARE:
            masks = SPARE8.rlc()
            SPARE8 = masks.value
        case .I:
            masks = I.rlc()
            I = masks.value
        case .R:
            masks = R.rlc()
            R = masks.value
        case .F:
            break
        }
        F = sz53pv(masks.value) | masks.carryMask
    }

    func rrc(_ register: Z808BitRegister) {
        var masks: (value: UInt8, carryMask: UInt8) = (value: 0x00, carryMask: 0x00)
        switch register {
        case .A:
            masks = A.rrc()
            A = masks.value
        case .B:
            masks = B.rrc()
            B = masks.value
        case .C:
            masks = C.rrc()
            C = masks.value
        case .D:
            masks = D.rrc()
            D = masks.value
        case .E:
            masks = E.rrc()
            E = masks.value
        case .L:
            masks = L.rrc()
            L = masks.value
        case .H:
            masks = H.rrc()
            H = masks.value
        case .SPARE:
            masks = SPARE8.rrc()
            SPARE8 = masks.value
        case .I:
            masks = I.rrc()
            I = masks.value
        case .R:
            masks = R.rrc()
            R = masks.value
        case .F:
            break
        }
        F = sz53pv(masks.value) | masks.carryMask
    }

    func rl(_ register: Z808BitRegister) {
        var masks: (value: UInt8, carryMask: UInt8) = (value: 0x00, carryMask: 0x00)
        switch register {
        case .A:
            masks = A.rl(F * 0x01)
            A = masks.value
        case .B:
            masks = B.rl(F * 0x01)
            B = masks.value
        case .C:
            masks = C.rl(F * 0x01)
            C = masks.value
        case .D:
            masks = D.rl(F * 0x01)
            D = masks.value
        case .E:
            masks = E.rl(F * 0x01)
            E = masks.value
        case .L:
            masks = L.rl(F * 0x01)
            L = masks.value
        case .H:
            masks = H.rl(F * 0x01)
            H = masks.value
        case .SPARE:
            masks = SPARE8.rl(F * 0x01)
            SPARE8 = masks.value
        case .I:
            masks = I.rl(F * 0x01)
            I = masks.value
        case .R:
            masks = R.rl(F * 0x01)
            R = masks.value
        case .F:
            break
        }
        F = sz53pv(masks.value) | masks.carryMask
    }

    func rr(_ register: Z808BitRegister) {
            var masks: (value: UInt8, carryMask: UInt8) = (value: 0x00, carryMask: 0x00)
            switch register {
            case .A:
                masks = A.rr(F * 0x80)
                A = masks.value
            case .B:
                masks = B.rr(F * 0x80)
                B = masks.value
            case .C:
                masks = C.rr(F * 0x80)
                C = masks.value
            case .D:
                masks = D.rr(F * 0x80)
                D = masks.value
            case .E:
                masks = E.rr(F * 0x80)
                E = masks.value
            case .L:
                masks = L.rr(F * 0x80)
                L = masks.value
            case .H:
                masks = H.rr(F * 0x80)
                H = masks.value
            case .SPARE:
                masks = SPARE8.rr(F * 0x80)
                SPARE8 = masks.value
            case .I:
                masks = I.rr(F * 0x80)
                I = masks.value
            case .R:
                masks = R.rr(F * 0x80)
                R = masks.value
            case .F:
                break
            }
            F = sz53pv(masks.value) | masks.carryMask
        }

    func wordFrom(high: UInt8, low: UInt8) -> UInt16 {
        return (UInt16(high) * 256) + UInt16(low)
    }
    
}
