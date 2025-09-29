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
    
    public func performIn(port: UInt8, map: UInt8 = 0x00)  -> UInt8 {
        let portID = "\(map.hex())\(port.hex())"
//        if (portID == "00fe") {
//            let p1 = getPort(port: "fefe")
//            let p2 = getPort(port: "FDFE")
//            let p3 = getPort(port: "FBFE")
//            let p4 = getPort(port: "F7FE")
//            let p5 = getPort(port: "EFFE")
//            let p6 = getPort(port: "DFFE")
//            let p7 = getPort(port: "BFFE")
//            let p8 = getPort(port: "7FFE")
//            let allp = p1 & p2 & p3 & p4 & p5 & p6 & p7 & p8
//            return allp
//        }
        if (port.hex().lowercased() == "fe") {
            switch map {
            case 0xfe, 0xfd, 0xfb, 0xf7, 0xef, 0xdf, 0xbf, 0x7f:
                return getPort(port: portID)
            case 0x00:
                let p1 = getPort(port: "fefe")
                let p2 = getPort(port: "FDFE")
                let p3 = getPort(port: "FBFE")
                let p4 = getPort(port: "F7FE")
                let p5 = getPort(port: "EFFE")
                let p6 = getPort(port: "DFFE")
                let p7 = getPort(port: "BFFE")
                let p8 = getPort(port: "7FFE")
                let allp = p1 & p2 & p3 & p4 & p5 & p6 & p7 & p8
                return allp
                
            default:
                var selected: UInt8 = 0xFF
                if map & 0x01 == 0x0 { selected = selected & getPort(port: "FEFE")}
                if map & 0x02 == 0x0 { selected = selected & getPort(port: "FDFE")}
                if map & 0x04 == 0x0 { selected = selected & getPort(port: "FBFE")}
                if map & 0x08 == 0x0 { selected = selected & getPort(port: "F7FE")}
                if map & 0x10 == 0x0 { selected = selected & getPort(port: "EFFE")}
                if map & 0x20 == 0x0 { selected = selected & getPort(port: "DFFE")}
                if map & 0x40 == 0x0 { selected = selected & getPort(port: "BFFE")}
                if map & 0x80 == 0x0 { selected = selected & getPort(port: "7FFE")}
//                let p2 = (map & 0x02 == 0x0) ? 0xFF : getPort(port: "FDFE")//getPort(port: "FDFE")
//                let p3 = (map & 0x04 == 0x0) ? 0xFF : getPort(port: "FBFE")//getPort(port: "FBFE")
//                let p4 = (map & 0x08 == 0x0) ? 0xFF : getPort(port: "F7FE")//getPort(port: "F7FE")
//                let p5 = (map & 0x10 == 0x0) ? 0xFF : getPort(port: "EFFE")//getPort(port: "EFFE")
//                let p6 = (map & 0x20 == 0x0) ? 0xFF : getPort(port: "DFFE")//getPort(port: "DFFE")
//                let p7 = (map & 0x40 == 0x0) ? 0xFF : getPort(port: "BFFE")//getPort(port: "BFFE")
//                let p8 = (map & 0x80 == 0x0) ? 0xFF : getPort(port: "7FFE")//getPort(port: "7FFE")
//                let allp = p1 & p2 & p3 & p4 & p5 & p6 & p7 & p8
                return selected
            }
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
