//
//  Z80Flags.swift
//  Fake-A-Chip
//
//  Created by Mike Hall on 20/05/2023.
//

import Foundation

// **** Flag Masks ****
//
//let carry: UInt8 = 0x01
//let negative: UInt8 = 0x02
//let parityOverflow: UInt8 = 0x04
//let three: UInt8 = 0x08
//let halfCarry: UInt8 = 0x10
//let five: UInt8 = 0x20
//let zero: UInt8 = 0x40
//let sign: UInt8 = 0x80

public enum Z80FlagBitPosition: UInt8 {
    case carry = 0x01,
    negative = 0x02,
    parityOverflow = 0x04,
    three = 0x08,
    halfCarry = 0x10,
    five = 0x20,
    zero = 0x40,
    sign = 0x80
     func position() -> Int {
         switch self {

         case .carry:
             return 0
         case .negative:
             return 1
         case .parityOverflow:
             return 2
         case .three:
             return 3
         case .halfCarry:
             return 4
         case .five:
             return 5
         case .zero:
             return 6
         case .sign:
             return 7
         }
     }
}


public extension Z80 {

    var bits53: UInt8 {
        A & 0x28
    }

    var bits53OnH: UInt8 {
        H & 0x28
    }

    func bits53(_ value: UInt8) -> UInt8 {
       return value & 0x28
    }

    func bits53ForCopy(_ value: UInt8) -> UInt8 {
        let bit5 = (value & 0x02) << 4
        let bit3 = value & three
        let bit2 = (BC == 0x00 ? 0x00 : parityOverflow)
        return (bit5 | bit3 | bit2)
    }

    func read(_ bit: Z80FlagBitPosition) -> Bool {
        return F & bit.rawValue > 0
    }

    func sz53(_ value: UInt8) -> UInt8 {
        return sz53Table[Int(value)]
    }

    func sz53pv(_ value: UInt8) -> UInt8 {
        return sz53pvTable[Int(value)]
    }

    func halfCarryOverflowCalculationAdd(value: UInt8, amount: UInt8) -> (halfCarryMask: UInt8, overflowMask: UInt8, value: UInt8) {
        let addtemp = UInt16(value) &+ UInt16(amount)
let lookup = hcLookup(temp: addtemp, value: value, amount: amount)
        return (halfCarryMask: halfCarryAdd[Int(lookup & 0xff) & 0x07], overflowMask: overFlowAdd[Int(UInt8(lookup & 0xff)) >> 4], value: UInt8(addtemp & 0xff))
    }

    func halfCarryOverflowCalculationSub(value: UInt8, amount: UInt8) -> (halfCarryMask: UInt8, overflowMask: UInt8, value: UInt8) {
        let addtemp = UInt16(value) &- UInt16(amount)
let lookup = hcLookup(temp: addtemp, value: value, amount: amount)
        return (halfCarryMask: halfCarrySub[Int(lookup & 0xff) & 0x07], overflowMask: overFlowSub[Int(UInt8(lookup & 0xff)) >> 4], value: UInt8(addtemp & 0xff))
    }

    func carryHalfCarryOverflowCalculationAdd(value: UInt8, amount: UInt8, carryIn: UInt8 = 0x00) -> (carryMask: UInt8, halfCarryMask: UInt8, overflowMask: UInt8, value: UInt8) {
        let addtemp = UInt16(value) &+ UInt16(amount) &+ UInt16(carryIn)
        let steppedTemp: UInt16 = addtemp >> 8
        let carryMask = UInt8(steppedTemp) & carry
let lookup = hcLookup(temp: addtemp, value: value, amount: amount)
        return (carryMask: carryMask, halfCarryMask: halfCarryAdd[Int(lookup & 0xff) & 0x07], overflowMask: overFlowAdd[Int(UInt8(lookup & 0xff)) >> 4], value: UInt8(addtemp & 0xff))
    }

    func carryHalfCarryOverflowCalculationSub(value: UInt8, amount: UInt8, carryIn: UInt8 = 0x00) -> (carryMask: UInt8, halfCarryMask: UInt8, overflowMask: UInt8, value: UInt8) {
        let addtemp = UInt16(value) &- UInt16(amount) &- UInt16(carryIn)
        let steppedTemp: UInt16 = addtemp >> 8
        let carryMask = UInt8(steppedTemp) & carry
let lookup = hcLookup(temp: addtemp, value: value, amount: amount)
        return (carryMask: carryMask, halfCarryMask: halfCarrySub[Int(lookup & 0xff) & 0x07], overflowMask: overFlowSub[Int(UInt8(lookup & 0xff)) >> 4], value: UInt8(addtemp & 0xff))
    }

    func hcLookup(temp: UInt16, value: UInt8, amount: UInt8) -> UInt8 {
        let part1 = (value & 0x88) >> 3
        let part2 = (amount & 0x88) >> 2
        let part3 = UInt8(temp & 0x88) >> 1
        return part1 | part2 | part3
    }

    func halfCarryOverflowCalculationAdd16Bit(value: UInt16, amount: UInt16, carryIn: UInt8 = 0x00) -> (carryMask: UInt8, halfCarryMask: UInt8, overflowMask: UInt8, value: UInt16) {
        let addtemp = UInt32(value) &+ UInt32(amount) &+ UInt32(carryIn)
        let steppedTemp: UInt32 = addtemp >> 16
        let carryMask = UInt8(UInt16(steppedTemp) & 0x01)
let lookup = hcLookup16Bit(temp: addtemp, value: value, amount: amount)
        return (carryMask: carryMask, halfCarryMask: halfCarryAdd[Int(lookup & 0xff) & 0x07], overflowMask: overFlowAdd[Int(UInt8(lookup & 0xff)) >> 4], value: UInt16(addtemp & 0xffff))
    }

    func halfCarryOverflowCalculationSub16Bit(value: UInt16, amount: UInt16, carryIn: UInt8 = 0x00) -> (carryMask: UInt8, halfCarryMask: UInt8, overflowMask: UInt8, value: UInt16) {
        let addtemp = UInt32(value) &- UInt32(amount) &- UInt32(carryIn)
        let steppedTemp: UInt32 = addtemp >> 16
        let carryMask = UInt8(UInt16(steppedTemp) & 0x01)
let lookup = hcLookup16Bit(temp: addtemp, value: value, amount: amount)

        return (carryMask: carryMask, halfCarryMask: halfCarrySub[Int(lookup & 0xff) & 0x07], overflowMask: overFlowSub[Int(UInt8(lookup & 0xff)) >> 4], value: UInt16(addtemp & 0xffff))
    }

    func hcLookup16Bit(temp: UInt32, value: UInt16, amount: UInt16) -> UInt8 {
        let part1 = (value & 0x8800) >> 11
        let part2 = (amount & 0x8800) >> 10
        let part3 = (temp & 0x8800) >> 9
        return UInt8(part1) | UInt8(part2) | UInt8(part3)
    }

    func calculateTables() {
        for ii in 0...255 {
            sz53Table.append(UInt8(ii) & (three | five | sign))
            let j = UInt8(ii)
            var parity: Int = 0
            for bit in 0...7 {
                if j.isSet(bit: bit) {
                    parity += 1
                }
            }

            if parity % 2 == 0 {
                parityBit.append(0x04)
            } else {
                parityBit.append(0)
            }
            sz53pvTable.append(sz53Table[ii] | parityBit[ii])
        }

        sz53Table[0]   = sz53Table[0]   | zero
        sz53pvTable[0] = sz53pvTable[0] | zero
    }

    func preserve(_ masks: UInt8...) -> UInt8 {
        var mask: UInt8 = 0x00
        for m in masks {
            mask = mask | m
        }
        return F & mask
    }

    
}
