//
//  Z80+IO.swift
//  Fake-A-Chip
//
//  Created by Mike Hall on 31/05/2023.
//

import Foundation

extension Z80 {
    func performIn(port: UInt8) -> UInt8 {
       return activeHardwarePorts[String(port)] ?? 0x00
    }

    func performOut(port: UInt8, value: UInt8) {
        activeHardwarePorts[String(port)] = value
    }
}
