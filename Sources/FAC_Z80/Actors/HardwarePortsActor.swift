//
//  HardwarePortsActor.swift
//
//
//  Created by Mike Hall on 19/07/2023.
//

import Foundation

/// Port-mapped I/O with numeric keys. A lock-guarded class rather than an
/// actor: string-keyed lookups on every IN/OUT plus actor hops dominated I/O
/// cost. Two key spaces are kept separate to avoid collisions:
/// - 2-byte ports, key = (upper << 8) | lower  (e.g. 0xFEFE keyboard matrix)
/// - single-byte ports, key = lower            (e.g. 0xFE border/tape mirror)
public final class HardwarePorts: @unchecked Sendable {
    private let lock = NSLock()
    private var activeHardwarePorts: [UInt16 : UInt8] = [:]
    private var activeSinglePorts: [UInt8 : UInt8] = [:]
    
    func reset()  {
        lock.lock()
        activeHardwarePorts = [:]
        activeSinglePorts = [:]
        lock.unlock()
    }
     
     func getPort(port: UInt16, defaultValue: UInt8 = 0x00) -> UInt8 {
         lock.lock()
         let value = activeHardwarePorts[port] ?? defaultValue
         lock.unlock()
         return value
     }
    
    public func performIn(lower: UInt8, upper: UInt8 = 0x00)  -> UInt8 {
        let port = (UInt16(upper) << 8) | UInt16(lower)
        lock.lock()
        if let setValue = activeHardwarePorts[port] {
            lock.unlock()
            return setValue
        }
        let value: UInt8
        if lower == 0xfe {
            switch upper {
            case 0xfe, 0xfd, 0xfb, 0xf7, 0xef, 0xdf, 0xbf, 0x7f:
                value = activeHardwarePorts[port] ?? 0xFF
            case 0x00:
                let p1 = activeHardwarePorts[0xFEFE] ?? 0xFF
                let p2 = activeHardwarePorts[0xFDFE] ?? 0xFF
                let p3 = activeHardwarePorts[0xFBFE] ?? 0xFF
                let p4 = activeHardwarePorts[0xF7FE] ?? 0xFF
                let p5 = activeHardwarePorts[0xEFFE] ?? 0xFF
                let p6 = activeHardwarePorts[0xDFFE] ?? 0xFF
                let p7 = activeHardwarePorts[0xBFFE] ?? 0xFF
                let p8 = activeHardwarePorts[0x7FFE] ?? 0xFF
                value = p1 & p2 & p3 & p4 & p5 & p6 & p7 & p8
            default:
                var selected: UInt8 = 0xFF
                if upper & 0x01 == 0x0 { selected = selected & (activeHardwarePorts[0xFEFE] ?? 0xFF) }
                if upper & 0x02 == 0x0 { selected = selected & (activeHardwarePorts[0xFDFE] ?? 0xFF) }
                if upper & 0x04 == 0x0 { selected = selected & (activeHardwarePorts[0xFBFE] ?? 0xFF) }
                if upper & 0x08 == 0x0 { selected = selected & (activeHardwarePorts[0xF7FE] ?? 0xFF) }
                if upper & 0x10 == 0x0 { selected = selected & (activeHardwarePorts[0xEFFE] ?? 0xFF) }
                if upper & 0x20 == 0x0 { selected = selected & (activeHardwarePorts[0xDFFE] ?? 0xFF) }
                if upper & 0x40 == 0x0 { selected = selected & (activeHardwarePorts[0xBFFE] ?? 0xFF) }
                if upper & 0x80 == 0x0 { selected = selected & (activeHardwarePorts[0x7FFE] ?? 0xFF) }
                value = selected
            }
        } else if lower == 0x1F {
            value = activeHardwarePorts[0x001F] ?? 0x00
        } else {
            value = activeHardwarePorts[port] ?? 0x00
        }
        lock.unlock()
        return value
    }
    
    func performSinglePortIn(port: UInt8)  -> UInt8 {
        lock.lock()
        let value = activeSinglePorts[port] ?? 0x00
        lock.unlock()
        return value
    }

    public func performOut(lower: UInt8, upper: UInt8? = nil, value: UInt8)  {
        if let upper {
            let port = (UInt16(upper) << 8) | UInt16(lower)
            lock.lock()
            activeHardwarePorts[port] = value
            lock.unlock()
        } else {
            // A single-byte port write (e.g. OUT (0xFE),A for the border).
            // Mirrors the original string-keyed behaviour where a nil upper
            // addressed the single-byte port space.
            lock.lock()
            activeSinglePorts[lower] = value
            lock.unlock()
        }
    }
    
    public func updatePort(lower: UInt8, bit: Int, set: Bool)  {
        let port: UInt16 = (UInt16(lower) << 8) | 0xFE
        lock.lock()
        var value = activeHardwarePorts[port] ?? 0xFF
        value = set ? value.clear(bit: bit) : value.set(bit: bit)
        activeHardwarePorts[port] = value
        lock.unlock()
    }
    
    public func flipBitOnPort(lower: UInt8, bit: Int)  {
        let port: UInt16 = (UInt16(lower) << 8) | 0xFE
        lock.lock()
        var value = activeHardwarePorts[port] ?? 0xFF
        value = value.isSet(bit: bit) ? value.clear(bit: bit) : value.set(bit: bit)
        activeHardwarePorts[port] = value
        lock.unlock()
    }
    
    public func updateSinglePort(lower: UInt8, bit: Int, set: Bool)  {
        lock.lock()
        var value = activeSinglePorts[lower] ?? 0xFF
        value = set ? value.clear(bit: bit) : value.set(bit: bit)
        activeSinglePorts[lower] = value
        lock.unlock()
    }
    
    public func writeSinglePort(lower: UInt8, value: UInt8)  {
        lock.lock()
        activeSinglePorts[lower] = value
        lock.unlock()
    }
    
    public func writeSinglePort(port: UInt16, value: UInt8)  {
        lock.lock()
        activeHardwarePorts[port] = value
        lock.unlock()
    }
    
     public func writeSinglePort(port: String, value: UInt8)  {
        lock.lock()
        if let p = UInt16(port, radix: 16) {
            activeHardwarePorts[p] = value
        }
        lock.unlock()
     }
     
    
}