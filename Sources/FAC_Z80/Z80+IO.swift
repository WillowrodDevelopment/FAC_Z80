//
//  Z80+IO.swift
//  Fake-A-Chip
//
//  Created by Mike Hall on 31/05/2023.
//

import Foundation

public extension Z80 {
    func performIn(port: UInt8, map: UInt8? = nil) async -> UInt8 {
        return await hardwarePorts.performIn(lower: port, upper: map ?? 0x00)
    }
    
    func performSinglePortIn(lower: UInt8) async -> UInt8 {
        return await hardwarePorts.performSinglePortIn(port: lower)
    }

    func performOut(port: UInt8, map: UInt8? = nil, value: UInt8) async {
        await hardwarePorts.performOut(lower: port, upper: map, value: value)
    }
    
    func updatePort(port: UInt8, bit: Int, set: Bool) async {
        await hardwarePorts.updatePort(lower: port, bit: bit, set: set)
    }
    
    func flipBitOnPort(port: UInt8, bit: Int) async {
        await hardwarePorts.flipBitOnPort(lower: port, bit: bit)
    }
    
    func updateSinglePort(port: UInt8, bit: Int, set: Bool) async {
        await hardwarePorts.updateSinglePort(lower: port, bit: bit, set: set)
    }
    
    func writeSinglePort(port: UInt8, value: UInt8) async {
        await hardwarePorts.writeSinglePort(lower: port, value: value)
    }
}
