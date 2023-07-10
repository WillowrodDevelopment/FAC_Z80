//
//  Z80ControlDelegate.swift
//  
//
//  Created by Mike Hall on 07/07/2023.
//

import Foundation

public protocol Z80ControlDelegate {
    func updateStack(_ stack: [UInt16])
}
