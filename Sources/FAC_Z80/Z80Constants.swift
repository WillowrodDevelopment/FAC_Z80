//
//  Z80Constants.swift
//  Fake-A-Chip
//
//  Created by Mike Hall on 20/05/2023.
//

import Foundation

enum Z808BitRegister: Int {
case A = 0x07,
     B = 0x00,
     C = 0x01,
     D = 0x02,
     E = 0x03,
     L = 0x04,
     H = 0x05,
     SPARE = 0x06,
     I = 0x08,
     R = 0x09,
     F = 0xFF
}

enum Z8016BitRegister: Int {
case PC = 0x00,
     SP = 0x01,
     IX = 0x02,
     IY = 0x03,
     SPARE = 0x04
}

enum Z80RegisterPair: Int {
case BC = 0,
     DE = 1,
     HL = 2,
     AF = 3
}

enum Z80FlagMask: UInt8 {
    case carry = 0x01,
    negative = 0x02,
    parityOverflow = 0x04,
    three = 0x08,
    halfCarry = 0x10,
    five = 0x20,
    zero = 0x40,
    sign = 0x80
}

public enum Z80ProcessorSpeed {
    case standard, paused, turbo, unrestricted
}
