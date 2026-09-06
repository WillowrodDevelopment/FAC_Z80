//
//  Z80+MemoryMap.swift
//  FAC_Z80
//
//  Created by Mike Hall on 17/08/2026.
//

import Foundation

extension Z80 {
    /// Records a jump with bank-aware canonical addresses (128k) or plain addresses (48k).
    public func recordJumpBanked(_ target: UInt16, type: MemoryLocationType = .Jump, from: UInt16) {
        if let memoryMap = controller.memoryMap {
            let t = canonicalBankAddress(for: target)
            let f = canonicalBankAddress(for: from)
            memoryMap.recordJump(t, type: type, from: f)
        }
    }
    
    /// Records data access with bank-aware canonical addresses.
    public func recordDataBanked(_ addr: UInt16, value8Bit: UInt8? = nil, value16Bit: UInt16? = nil) {
        if let memoryMap = controller.memoryMap {
            let a = canonicalBankAddress(for: addr)
            memoryMap.recordData(a, value8Bit: value8Bit, value16Bit: value16Bit)
        }
    }
    
    /// Records a graphics source with bank-aware canonical addresses.
    public func recordGraphicsSourceBanked(_ addr: UInt16) {
        if let memoryMap = controller.memoryMap {
            let a = canonicalBankAddress(for: addr)
            memoryMap.recordGraphicsSource(a)
        }
    }
}