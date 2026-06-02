//
//  Z80MemoryMap.swift
//  FAC_Z80
//
//  Created by mike on 30/09/2025.
//

import Foundation

public actor Z80MemoryMap {
    public var jumpMap: [UInt16: MemoryLocation] = [:]
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
    
    public func recordJump(_ jump: UInt16, type: MemoryLocationType = .Jump, from: UInt16) {
        if jump > 0x5800 {
            if jumpMap[jump] == nil {
                jumpMap[jump] = MemoryLocation(location: jump, from: from)
                return
            }
            jumpMap[jump] = jumpMap[jump]?.update(from: from)
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
        return jumpMap.map{$0.value}
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
    public let accessed: Int
    public let lastUsed: TimeInterval
    public let calledFrom: Set<UInt16>
    
    private init(location: UInt16, byte: UInt8?, word: UInt16?, type: MemoryLocationType, accessed: Int, lastUsed: TimeInterval = 0, from: Set<UInt16>) {
        self.location = location
        self.byte = byte
        self.word = word
        self.type = type
        self.accessed = accessed
        self.lastUsed = Date.now.timeIntervalSince1970
        self.calledFrom = from
    }
    
    public init(location: UInt16, type: MemoryLocationType, lastUsed: TimeInterval = 0, from: UInt16) {
        self.location = location
        self.byte = nil
        self.word = nil
        self.type = type
        self.accessed = 1
        self.lastUsed = Date.now.timeIntervalSince1970
        self.calledFrom = [from]
    }
    
    public init(location: UInt16, byte: UInt8, type: MemoryLocationType, lastUsed: TimeInterval = 0, from: UInt16){
        self.location = location
        self.byte = byte
        self.word = nil
        self.type = type
        self.accessed = 1
        self.lastUsed = Date.now.timeIntervalSince1970
        self.calledFrom = [from]
    }
    
    public init(location: UInt16, word: UInt16, type: MemoryLocationType, lastUsed: TimeInterval = 0, from: UInt16){
        self.location = location
        self.byte = nil
        self.word = word
        self.type = type
        self.accessed = 1
        self.lastUsed = Date.now.timeIntervalSince1970
        self.calledFrom = [from]
    }
    
    public init(location: UInt16, from: UInt16){
        self.location = location
        self.byte = nil
        self.word = nil
        self.type = .Jump
        self.accessed = 1
        self.lastUsed = Date.now.timeIntervalSince1970
        self.calledFrom = [from]
    }
    
    func update(lastUsed: TimeInterval = 0, from: UInt16) -> MemoryLocation {
        let internalAccessed = accessed + 1
        var internalCalledFrom: Set<UInt16> = calledFrom
        internalCalledFrom.insert(from)
        return .init(location: location, byte: nil, word: nil, type: type, accessed: internalAccessed, lastUsed: Date.now.timeIntervalSince1970, from: internalCalledFrom)
    }
    
    
}



public enum MemoryLocationType: Hashable {
    case Data, Jump, IM2, Stack, DataStructure, Unknown
}
