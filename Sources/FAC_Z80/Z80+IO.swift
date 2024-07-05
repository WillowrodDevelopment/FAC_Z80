//
//  Z80+IO.swift
//  Fake-A-Chip
//
//  Created by Mike Hall on 31/05/2023.
//

import Foundation

public extension Z80 {
    func performIn(port: UInt8, map: UInt8? = nil) -> UInt8 {
        //preInPerform()
        return hardwarePorts.performIn(port: port, map: map)
    }
    
    func performSinglePortIn(port: UInt8) -> UInt8 {
        return hardwarePorts.performSinglePortIn(port: port)
    }

    func performOut(port: UInt8, map: UInt8? = nil, value: UInt8) {
        hardwarePorts.performOut(port: port, map: map, value: value)
    }
    
    func updatePort(port: UInt8, bit: Int, set: Bool) {
        hardwarePorts.updatePort(port: port, bit: bit, set: set)
    }
    
    func flipBitOnPort(port: UInt8, bit: Int) {
        hardwarePorts.flipBitOnPort(port: port, bit: bit)
    }
    
    func updateSinglePort(port: UInt8, bit: Int, set: Bool) {
        hardwarePorts.updateSinglePort(port: port, bit: bit, set: set)
    }
    
    func writeSinglePort(port: UInt8, value: UInt8) {
        hardwarePorts.writeSinglePort(port: port, value: value)
    }
}
