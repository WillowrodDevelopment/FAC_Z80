//
//  Z80+IO.swift
//  Fake-A-Chip
//
//  Created by Mike Hall on 31/05/2023.
//

import Foundation

public extension Z80 {
    func performIn(port: UInt8, map: UInt8? = nil) -> UInt8 {
        return readPort(lower: port, upper: map ?? 0x00)
    }
    
    func performSinglePortIn(lower: UInt8) -> UInt8 {
        return hardwarePorts.performSinglePortIn(port: lower)
    }

    func performOut(port: UInt8, map: UInt8? = nil, value: UInt8) {
        writePort(lower: port, upper: map, value: value)
    }
    
    func updatePort(port: UInt8, bit: Int, set: Bool) {
        hardwarePorts.updatePort(lower: port, bit: bit, set: set)
    }
    
    func flipBitOnPort(port: UInt8, bit: Int) {
        hardwarePorts.flipBitOnPort(lower: port, bit: bit)
    }
    
    func updateSinglePort(port: UInt8, bit: Int, set: Bool) {
        hardwarePorts.updateSinglePort(lower: port, bit: bit, set: set)
    }
    
    func writeSinglePort(port: UInt8, value: UInt8) {
        hardwarePorts.writeSinglePort(lower: port, value: value)
    }
}