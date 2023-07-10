//
//  TestModel.swift
//  FakeAChipTests
//
//  Created by Mike Hall on 28/05/2023.
//

import Foundation

struct TestModel: Codable {
    let name: String
        let initial: TestState
        let final: TestState
        let cycles: [[Cycle]]
        let ports: [[Port]]?
}

struct TestState: Codable {
    let pc: UInt16
    let sp: UInt16
    let a: UInt8
    let b: UInt8
    let c: UInt8
    let d: UInt8
    let e: UInt8
    let f: UInt8
    let h: UInt8
    let l: UInt8
    let i: UInt8
    let r: UInt8
    let ei: UInt8
    let wz: UInt16
    let ix: UInt16
    let iy: UInt16
    let af_: UInt16
    let bc_: UInt16
    let de_: UInt16
    let hl_: UInt16
    let im: UInt8
    let p: UInt8
    let q: UInt8
    let iff1: UInt8
    let iff2: UInt8
    let ram: [[Int]]
}

enum Cycle: Codable {
   case integer(Int)
   case string(String)
   case null

   init(from decoder: Decoder) throws {
       let container = try decoder.singleValueContainer()
       if let x = try? container.decode(Int.self) {
           self = .integer(x)
           return
       }
       if let x = try? container.decode(String.self) {
           self = .string(x)
           return
       }
       if container.decodeNil() {
           self = .null
           return
       }
       throw DecodingError.typeMismatch(Cycle.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Wrong type for Cycle"))
   }

   func encode(to encoder: Encoder) throws {
       var container = encoder.singleValueContainer()
       switch self {
       case .integer(let x):
           try container.encode(x)
       case .string(let x):
           try container.encode(x)
       case .null:
           try container.encodeNil()
       }
   }
}

enum Port: Codable {
    case integer(Int)
    case string(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let x = try? container.decode(Int.self) {
            self = .integer(x)
            return
        }
        if let x = try? container.decode(String.self) {
            self = .string(x)
            return
        }
        throw DecodingError.typeMismatch(Port.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Wrong type for Port"))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .integer(let x):
            try container.encode(x)
        case .string(let x):
            try container.encode(x)
        }
    }

    func fetchString() -> String {
        switch self {
        case .integer(let v):
            return String(v)
        case .string(let v):
            return v
        }
    }

    func fetchUInt8() -> UInt8 {
        switch self {
        case .integer(let v):
            return UInt8(v)
        case .string(_):
            return 0x00
        }
    }

    func fetchUInt16() -> UInt16 {
        switch self {
        case .integer(let v):
            return UInt16(v)
        case .string(_):
            return 0x00
        }
    }
}
