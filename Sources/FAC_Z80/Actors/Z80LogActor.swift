//
//  File.swift
//  FAC_Z80
//
//  Created by mike on 30/09/2025.
//

import Foundation

public actor Z80Log {
    let cpu: Z80
    
    init(cpu: Z80) {
        self.cpu = cpu
    }
    
    public func pollRegisters() async -> Dictionary<String, String> {
        return await cpu.fetchRegisterData()
    }
    
    public func pollMemory(from: Int, size: Int) async -> [UInt8] {
        return await cpu.memory.fetchBatch(from: from, size: size)
    }
    
}
