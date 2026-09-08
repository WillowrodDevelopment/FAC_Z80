import Foundation

// MARK: - Main-table access patterns (per-M-cycle clock)

extension OpcodeTableSet {

    static func buildMainPatterns() -> [AccessPattern] {
        var p = [AccessPattern](repeating: .fetchOnly, count: 256)

        for op in [0x06, 0x0E, 0x16, 0x1E, 0x26, 0x2E, 0x3E] { // LD r,n (7T)
            p[op] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4)])
        }
        for op in [0x01, 0x11, 0x21, 0x31] { // LD rr,nn (10T)
            p[op] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4), .init(.read, 7)])
        }

        p[0x0A] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4)])   // LD A,(BC)
        p[0x1A] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4)])   // LD A,(DE)
        p[0x02] = AccessPattern(steps: [.init(.fetch, 0), .init(.write, 4)])  // LD (BC),A
        p[0x12] = AccessPattern(steps: [.init(.fetch, 0), .init(.write, 4)])  // LD (DE),A

        p[0x3A] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4), .init(.read, 7), .init(.read, 10)])    // LD A,(nn) 13T
        p[0x32] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4), .init(.read, 7), .init(.write, 10)])   // LD (nn),A 13T
        p[0x22] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4), .init(.read, 7), .init(.write, 10), .init(.write, 13)]) // LD (nn),HL 16T
        p[0x2A] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4), .init(.read, 7), .init(.read, 10), .init(.read, 13)])  // LD HL,(nn) 16T

        p[0x34] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4), .init(.write, 7)])  // INC (HL) 11T
        p[0x35] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4), .init(.write, 7)])  // DEC (HL) 11T
        p[0x36] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4), .init(.write, 7)])  // LD (HL),n 10T

        for op in 0x40...0x7F {
            if op == 0x76 { continue }
            let source = op & 0x07
            let target = (op >> 3) & 0x07
            if source == 6 {
                p[op] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4)])
            } else if target == 6 {
                p[op] = AccessPattern(steps: [.init(.fetch, 0), .init(.write, 4)])
            } else {
                p[op] = .fetchOnly
            }
        }

        for op in 0x80...0xBF {
            let source = op & 0x07
            if source == 6 {
                p[op] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4)])
            } else {
                p[op] = .fetchOnly
            }
        }

        for op in [0xC6, 0xCE, 0xD6, 0xDE, 0xE6, 0xEE, 0xF6, 0xFE] { // ALU n (7T)
            p[op] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4)])
        }

        for op in [0x10, 0x18, 0x20, 0x28, 0x30, 0x38] { // JR / DJNZ
            p[op] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4)])
        }

        for op in [0xC2, 0xC3, 0xCA, 0xD2, 0xDA, 0xE2, 0xEA, 0xF2, 0xFA] { // JP
            p[op] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4), .init(.read, 7)])
        }

        for op in [0xC4, 0xCC, 0xD4, 0xDC, 0xE4, 0xEC, 0xF4, 0xFC, 0xCD] { // CALL
            p[op] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4), .init(.read, 7), .init(.write, 10), .init(.write, 13)])
        }

        for op in [0xC0, 0xC8, 0xC9, 0xD0, 0xD8, 0xE0, 0xE8, 0xF0, 0xF8] { // RET
            p[op] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4), .init(.read, 7)])
        }

        for op in [0xC5, 0xD5, 0xE5, 0xF5] { // PUSH
            p[op] = AccessPattern(steps: [.init(.fetch, 0), .init(.write, 4), .init(.write, 7)])
        }
        for op in [0xC1, 0xD1, 0xE1, 0xF1] { // POP
            p[op] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4), .init(.read, 7)])
        }
        for op in [0xC7, 0xCF, 0xD7, 0xDF, 0xE7, 0xEF, 0xF7, 0xFF] { // RST
            p[op] = AccessPattern(steps: [.init(.fetch, 0), .init(.write, 4), .init(.write, 7)])
        }

        p[0xE3] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4), .init(.read, 7), .init(.write, 11), .init(.write, 15)]) // EX (SP),HL 19T

        p[0xD3] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4), .init(.io, 7)])   // OUT (n),A 11T
        p[0xDB] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4), .init(.io, 7)])   // IN A,(n) 11T

        return p
    }
}