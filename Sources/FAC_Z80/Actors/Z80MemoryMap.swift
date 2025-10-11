//
//  Z80MemoryMap.swift
//  FAC_Z80
//
//  Created by mike on 30/09/2025.
//

import Foundation

public actor Z80MemoryMap {
    public var jumpMap: [UInt16: (MemoryLocationType, Int, TimeInterval)] = [:]//Set<MemoryLocation> = []
    public var dataMap8Bit: [UInt16: UInt8] = [:]
    public var dataMap16Bit: [UInt16: UInt16] = [:]
    public var ixyMap: Set<UInt16> = []
    public var stackMap: Set<UInt16> = []
    public var showingSettings = false
    
    
    public var pcTrace: [UInt16] = []
    
    public func recordPC(_ jump: UInt16) {
        //if jump > 0x5800 {
            pcTrace.append(jump)
            while pcTrace.count > 10000 {
                _ = pcTrace.removeFirst()
            }
        //}
    }
    
    public func recordJump(_ jump: UInt16, type: MemoryLocationType = .Jump) {
        if jump > 0x5800 {
            var counter: Int = jumpMap[jump]?.1 ?? 0
            
//            jumpMap.remove(where: {$0.location == jump})
            jumpMap[jump] = (type, counter + 1, Date.now.timeIntervalSince1970)  //.insert(MemoryLocation(location: jump, type: type))
        }
    }
    
    public func recordIxy(_ data: UInt16) {
        if data > 0x5800 {
            if ixyMap.contains(data) {
                return
            }
                ixyMap.insert(data)
        }
    }
    
    public func recordData(_ data: UInt16, value8Bit: UInt8? = nil, value16Bit: UInt16? = nil) {
        if data > 0x5800 {
            if let value8Bit {
                dataMap8Bit[data] = value8Bit
            }
            if let value16Bit {
                dataMap16Bit[data] = value16Bit
            }
        }
    }
    
    public func recordStack(_ data: UInt16) {
        if data > 0x5800 {
            if stackMap.contains(data) {
                return
            }
                stackMap.insert(data)
        }
    }
    
    public func fetch8BitData() -> [(UInt16, UInt8)] {
        return dataMap8Bit.map { ($0.key, $0.value) }.sorted(by: { $0.0 < $1.0 })
    }
    
    public func fetch16BitData() -> [(UInt16, UInt16)] {
        return dataMap16Bit.map { ($0.key, $0.value) }.sorted(by: { $0.0 < $1.0 })
    }
    
    public func fetchJumpMap() -> [MemoryLocation] {
        return jumpMap.sorted(by: { $0.value.2 > $1.value.2 }).map { MemoryLocation(location: $0.key, type: $0.value.0, accessed: $0.value.1, lastUsed: $0.value.2) }
    }
    
    public func clear8BitData() {
        dataMap8Bit.removeAll()
    }
    
    public func clear16BitData() {
        dataMap16Bit.removeAll()
    }
    
    public func clearJumpMap() {
        jumpMap.removeAll()
    }
}

public struct MemoryLocation: Hashable {
    public let location: UInt16
    public let byte: UInt8?
    public let word: UInt16?
    public let type: MemoryLocationType
    public let accessed: Int?
    public let lastUsed: TimeInterval
    
    init(location: UInt16, type: MemoryLocationType, accessed: Int, lastUsed: TimeInterval = 0) {
        self.location = location
        self.byte = nil
        self.word = nil
        self.type = type
        self.accessed = accessed
        self.lastUsed = lastUsed
    }
    
    init(location: UInt16, byte: UInt8, type: MemoryLocationType, lastUsed: TimeInterval = 0){
        self.location = location
        self.byte = byte
        self.word = nil
        self.type = type
        self.accessed = nil
        self.lastUsed = lastUsed
    }
    
    init(location: UInt16, word: UInt16, type: MemoryLocationType, lastUsed: TimeInterval = 0){
        self.location = location
        self.byte = nil
        self.word = word
        self.type = type
        self.accessed = nil
        self.lastUsed = lastUsed
    }
}

public enum MemoryLocationType: Hashable {
    case Data, Jump, IM2, Stack, DataStructure, Unknown
}
