//
//  HardwarePortsActor.swift
//
//
//  Created by Mike Hall on 19/07/2023.
//

import Foundation

 public actor HardwarePorts {
    private var activeHardwarePorts: [String : UInt8] = [:]
    
    func reset()  {
        activeHardwarePorts = [:]
    }
     
     func getPort(port: String) -> UInt8 {
         return activeHardwarePorts[port.lowercased()] ?? 0xFF
     }
    
    public func performIn(port: UInt8, map: UInt8? = nil)  -> UInt8 {
        let portID = "\(map?.hex() ?? "7f")\(port.hex())"
        if (portID == "00fe") {
            let p1 = getPort(port: "fefe")
            let p2 = getPort(port: "FDFE")
            let p3 = getPort(port: "FBFE")
            let p4 = getPort(port: "F7FE")
            let p5 = getPort(port: "EFFE")
            let p6 = getPort(port: "DFFE")
            let p7 = getPort(port: "BFFE")
            let p8 = getPort(port: "7FFE")
            let allp = p1 & p2 & p3 & p4 & p5 & p6 & p7 & p8
  //          print ("All ports: \(allp.hex())")
            return allp
        }
        let value = activeHardwarePorts[portID] ?? 0x00
        return value
    }
    
    func performSinglePortIn(port: UInt8)  -> UInt8 {
        do {
            let portID = "\(port.hex())"
            let value = activeHardwarePorts[portID] ?? 0x00
            return value } catch {
                print(error)
                return 0x00
            }
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
