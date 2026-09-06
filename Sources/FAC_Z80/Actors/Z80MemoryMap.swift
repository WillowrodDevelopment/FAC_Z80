//
//  Z80MemoryMap.swift
//  FAC_Z80
//
//  Created by mike on 30/09/2025.
//

import Foundation

/// Identifies a byte in the 128k memory space by its canonical RAM bank and
/// 16-bit address. Bank 5 lives at 0x4000-0x7FFF, bank 2 at 0x8000-0xBFFF and
/// all other banks (0,1,3,4,6,7) at 0xC000-0xFFFF. Bank 2/5 content paged into
/// 0xC000 is aliased back to its fixed home.
public struct BankedAddress: Hashable, Codable {
    public let bank: Int
    public let address: UInt16
    
    public init(bank: Int, address: UInt16) {
        self.bank = bank
        self.address = address
    }
}

public final class Z80MemoryMap: @unchecked Sendable {
    private let lock = NSLock()
    public var jumpMap: [BankedAddress: MemoryLocation] = [:]
    public var dataMap8Bit: [BankedAddress: [UInt8]] = [:]
    public var dataMap16Bit: [BankedAddress: [UInt16]] = [:]
    public var ixyMap: Set<UInt16> = []
    public var stackMap: Set<UInt16> = []
    public var graphicsSourceMap: Set<BankedAddress> = []
    public var showingSettings = false
    private let maxDataHistory = 100
    private var onNewJumpEntry: ((UInt16) -> Void)? = nil

    public func setOnNewJumpEntry(_ handler: ((UInt16) -> Void)?) {
        onNewJumpEntry = handler
    }
    
    
    public var pcTrace: [UInt16] = []
    
    public func recordPC(_ jump: UInt16) {
        //if jump > 0x5800 {
            pcTrace.append(jump)
            while pcTrace.count > 10000 {
                _ = pcTrace.removeFirst()
            }
        //}
    }
    
    public func recordJump(_ jump: BankedAddress, type: MemoryLocationType = .Jump, from: BankedAddress) {
        if jump.bank < 0 || jump.address > 0x5800 {
            if jumpMap[jump] == nil {
                jumpMap[jump] = MemoryLocation(banked: jump, from: from.address)
                onNewJumpEntry?(jump.address)
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
    
    public func recordData(_ data: BankedAddress, value8Bit: UInt8? = nil, value16Bit: UInt16? = nil) {
        if data.address > 0x5800 {
            if let value8Bit {
                var history = dataMap8Bit[data] ?? []
                if history.last != value8Bit {
                    history.append(value8Bit)
                    if history.count > maxDataHistory {
                        history.removeFirst(history.count - maxDataHistory)
                    }
                    dataMap8Bit[data] = history
                }
            }
            if let value16Bit {
                var history = dataMap16Bit[data] ?? []
                if history.last != value16Bit {
                    history.append(value16Bit)
                    if history.count > maxDataHistory {
                        history.removeFirst(history.count - maxDataHistory)
                    }
                    dataMap16Bit[data] = history
                }
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
    
    public func fetch8BitData() -> [(BankedAddress, UInt8)] {
        return dataMap8Bit.compactMap { key, value in value.last.map { (key, $0) } }.sorted(by: { $0.0.address < $1.0.address })
    }
    
    public func fetch16BitData() -> [(BankedAddress, UInt16)] {
        return dataMap16Bit.compactMap { key, value in value.last.map { (key, $0) } }.sorted(by: { $0.0.address < $1.0.address })
    }
    
    public func fetch8BitDataHistory() -> [(BankedAddress, [UInt8])] {
        return dataMap8Bit.map { ($0.key, $0.value) }.sorted(by: { $0.0.address < $1.0.address })
    }
    
    public func fetch16BitDataHistory() -> [(BankedAddress, [UInt16])] {
        return dataMap16Bit.map { ($0.key, $0.value) }.sorted(by: { $0.0.address < $1.0.address })
    }
    
    public func fetchPCTrace() -> [UInt16] {
        return pcTrace
    }
    
    public func recordGraphicsSource(_ addr: BankedAddress) {
        graphicsSourceMap.insert(addr)
    }
    
    public func fetchGraphicsSources() -> [BankedAddress] {
        graphicsSourceMap.sorted(by: { $0.address < $1.address })
    }
    
    public func clearGraphicsSources() {
        graphicsSourceMap.removeAll()
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
    public let bank: Int
    public let location: UInt16
    public let byte: UInt8?
    public let word: UInt16?
    public let type: MemoryLocationType
    public let accessed: Int
    public let lastUsed: TimeInterval
    public let calledFrom: Set<UInt16>
    
    private init(banked: BankedAddress, byte: UInt8?, word: UInt16?, type: MemoryLocationType, accessed: Int, lastUsed: TimeInterval = 0, from: Set<UInt16>) {
        self.bank = banked.bank
        self.location = banked.address
        self.byte = byte
        self.word = word
        self.type = type
        self.accessed = accessed
        self.lastUsed = Date.now.timeIntervalSince1970
        self.calledFrom = from
    }
    
    public init(banked: BankedAddress, type: MemoryLocationType, lastUsed: TimeInterval = 0, from: UInt16) {
        self.init(banked: banked, byte: nil, word: nil, type: type, accessed: 1, lastUsed: lastUsed, from: [from])
    }
    
    public init(banked: BankedAddress, byte: UInt8, type: MemoryLocationType, lastUsed: TimeInterval = 0, from: UInt16){
        self.init(banked: banked, byte: byte, word: nil, type: type, accessed: 1, lastUsed: lastUsed, from: [from])
    }
    
    public init(banked: BankedAddress, word: UInt16, type: MemoryLocationType, lastUsed: TimeInterval = 0, from: UInt16){
        self.init(banked: banked, byte: nil, word: word, type: type, accessed: 1, lastUsed: lastUsed, from: [from])
    }
    
    public init(banked: BankedAddress, from: UInt16){
        self.init(banked: banked, byte: nil, word: nil, type: .Jump, accessed: 1, lastUsed: 0, from: [from])
    }
    
    func update(lastUsed: TimeInterval = 0, from: BankedAddress) -> MemoryLocation {
        let internalAccessed = accessed + 1
        var internalCalledFrom: Set<UInt16> = calledFrom
        internalCalledFrom.insert(from.address)
        return .init(banked: BankedAddress(bank: bank, address: location), byte: nil, word: nil, type: type, accessed: internalAccessed, lastUsed: Date.now.timeIntervalSince1970, from: internalCalledFrom)
    }
    
    
}



public enum MemoryLocationType: Hashable {
    case Data, Jump, IM2, Stack, DataStructure, Unknown
}
