//
//  HardwarePortsActor.swift
//
//
//  Created by Mike Hall on 19/07/2023.
//

import Foundation

public class HardwarePorts {
    private var activeHardwarePorts: [String : UInt8] = [:]
    
    func reset()  {
        activeHardwarePorts = [:]
    }
    
    func performIn(port: UInt8, map: UInt8? = nil)  -> UInt8 {
        let portID = "\(map?.hex() ?? "7f")\(port.hex())"
        let value = activeHardwarePorts[portID] ?? 0x00
        return value
    }
    
    func performSinglePortIn(port: UInt8)  -> UInt8 {
        let portID = "\(port.hex())"
        let value = activeHardwarePorts[portID] ?? 0x00
        return value
    }

    public func performOut(port: UInt8, map: UInt8? = nil, value: UInt8)  {
        let portID = "\(port.hex())\(map?.hex() ?? "")"
        activeHardwarePorts[portID] = value
    }
    
    public func updatePort(port: UInt8, bit: Int, set: Bool)  {
        let portID = "\(port.hex())fe"
        var value = activeHardwarePorts[portID] ?? 0xFF
        value = set ? value.clear(bit: bit) : value.set(bit: bit)
        activeHardwarePorts[portID] = value
    }
    
    public func flipBitOnPort(port: UInt8, bit: Int)  {
        let portID = "\(port.hex())fe"
        var value = activeHardwarePorts[portID] ?? 0xFF
        value = value.isSet(bit: bit) ? value.clear(bit: bit) : value.set(bit: bit)
        activeHardwarePorts[portID] = value
    }
    
    public func updateSinglePort(port: UInt8, bit: Int, set: Bool)  {
        let portID = "\(port.hex())"
        var value = activeHardwarePorts[portID] ?? 0xFF
        value = set ? value.clear(bit: bit) : value.set(bit: bit)
        activeHardwarePorts[portID] = value
    }
    
    public func writeSinglePort(port: UInt8, value: UInt8)  {
        let portID = "\(port.hex())"
        activeHardwarePorts[portID] = value
    }
    
    public func writeSinglePort(port: UInt16, value: UInt8)  {
        let portID = "\(port.hex())"
        activeHardwarePorts[portID] = value
    }
    
}
