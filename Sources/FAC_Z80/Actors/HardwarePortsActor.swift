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
     
     func getPort(port: String, defaultValue: UInt8 = 0x00) -> UInt8 {
         return activeHardwarePorts[port.lowercased()] ?? defaultValue
     }
    
    public func performIn(lower: UInt8, upper: UInt8 = 0x00)  -> UInt8 {
        let portID = "\(upper.hex())\(lower.hex())"
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
        if (lower.hex().lowercased() == "fe") {
            switch upper {
            case 0xfe, 0xfd, 0xfb, 0xf7, 0xef, 0xdf, 0xbf, 0x7f:
                return getPort(port: portID, defaultValue: 0xFF)
            case 0x00:
                let p1 = getPort(port: "fefe", defaultValue: 0xFF)
                let p2 = getPort(port: "FDFE", defaultValue: 0xFF)
                let p3 = getPort(port: "FBFE", defaultValue: 0xFF)
                let p4 = getPort(port: "F7FE", defaultValue: 0xFF)
                let p5 = getPort(port: "EFFE", defaultValue: 0xFF)
                let p6 = getPort(port: "DFFE", defaultValue: 0xFF)
                let p7 = getPort(port: "BFFE", defaultValue: 0xFF)
                let p8 = getPort(port: "7FFE", defaultValue: 0xFF)
                let allp = p1 & p2 & p3 & p4 & p5 & p6 & p7 & p8
                return allp
                
            default:
                var selected: UInt8 = 0xFF
                if upper & 0x01 == 0x0 { selected = selected & getPort(port: "FEFE", defaultValue: 0xFF)}
                if upper & 0x02 == 0x0 { selected = selected & getPort(port: "FDFE", defaultValue: 0xFF)}
                if upper & 0x04 == 0x0 { selected = selected & getPort(port: "FBFE", defaultValue: 0xFF)}
                if upper & 0x08 == 0x0 { selected = selected & getPort(port: "F7FE", defaultValue: 0xFF)}
                if upper & 0x10 == 0x0 { selected = selected & getPort(port: "EFFE", defaultValue: 0xFF)}
                if upper & 0x20 == 0x0 { selected = selected & getPort(port: "DFFE", defaultValue: 0xFF)}
                if upper & 0x40 == 0x0 { selected = selected & getPort(port: "BFFE", defaultValue: 0xFF)}
                if upper & 0x80 == 0x0 { selected = selected & getPort(port: "7FFE", defaultValue: 0xFF)}
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
        if lower == 0x1F {
            return getPort(port: "001F")
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

    public func performOut(lower: UInt8, upper: UInt8? = nil, value: UInt8)  {
        let portID = "\(upper?.hex() ?? "")\(lower.hex())"
        activeHardwarePorts[portID] = value
    }
    
    public func updatePort(lower: UInt8, bit: Int, set: Bool)  {
        let portID = "\(lower.hex())fe"
        var value = activeHardwarePorts[portID] ?? 0xFF
        value = set ? value.clear(bit: bit) : value.set(bit: bit)
        activeHardwarePorts[portID] = value
    }
    
    public func flipBitOnPort(lower: UInt8, bit: Int)  {
        let portID = "\(lower.hex())fe"
        var value = activeHardwarePorts[portID] ?? 0xFF
        value = value.isSet(bit: bit) ? value.clear(bit: bit) : value.set(bit: bit)
        activeHardwarePorts[portID] = value
    }
    
    public func updateSinglePort(lower: UInt8, bit: Int, set: Bool)  {
        let portID = "\(lower.hex())"
        var value = activeHardwarePorts[portID] ?? 0xFF
        value = set ? value.clear(bit: bit) : value.set(bit: bit)
        activeHardwarePorts[portID] = value
    }
    
    public func writeSinglePort(lower: UInt8, value: UInt8)  {
        let portID = "\(lower.hex())"
        activeHardwarePorts[portID] = value
    }
    
    public func writeSinglePort(port: UInt16, value: UInt8)  {
        let portID = "\(port.hex())"
        activeHardwarePorts[portID] = value
    }
     
     public func writeSinglePort(port: String, value: UInt8)  {
         activeHardwarePorts[port.lowercased()] = value
     }
     
    
}
