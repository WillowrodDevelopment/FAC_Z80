//
//  File.swift
//  FAC_Z80
//
//  Created by Mike Hall on 08/09/2025.
//

import Foundation

public protocol MemoryDelegate {
    func write(to: UInt16, value: UInt8)
    func read(from: UInt16) -> UInt8
    func writeWord(to: UInt16, value: UInt16)
    func readWord(from: UInt16) -> UInt16
    func fetchBatch(from: Int, size: Int) -> [UInt8]
}