//
//  Z80+IO.swift
//  Fake-A-Chip
//
//  Created by Mike Hall on 31/05/2023.
//

import Foundation

public extension Z80 {
    func performIn(port: UInt8, map: UInt8? = nil) async -> UInt8 {
        //preInPerform()
        return await hardwarePorts.performIn(port: port, map: map)
    }
    
    func performSinglePortIn(port: UInt8) async -> UInt8 {
        return await hardwarePorts.performSinglePortIn(port: port)
    }

    func performOut(port: UInt8, map: UInt8? = nil, value: UInt8) async {
        await hardwarePorts.performOut(port: port, map: map, value: value)
    }
    
    func updatePort(port: UInt8, bit: Int, set: Bool) async {
        await hardwarePorts.updatePort(port: port, bit: bit, set: set)
    }
    
    func flipBitOnPort(port: UInt8, bit: Int) async {
        await hardwarePorts.flipBitOnPort(port: port, bit: bit)
    }
    
    func updateSinglePort(port: UInt8, bit: Int, set: Bool) async {
        await hardwarePorts.updateSinglePort(port: port, bit: bit, set: set)
    }
    
    func writeSinglePort(port: UInt8, value: UInt8) async {
        await hardwarePorts.writeSinglePort(port: port, value: value)
    }
}
