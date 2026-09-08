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

    // MARK: - CB patterns (CB prefix + operand)

    static func buildCBPatterns() -> [AccessPattern] {
        var p = [AccessPattern](repeating: .fetchOnly, count: 256)
        for op in 0..<256 {
            let source = op & 0x07
            let target = op >> 3
            if target >= 0x08 && target <= 0x0F {
                // BIT b,r / BIT b,(HL)
                if source == 6 {
                    // BIT (HL) 12T: fetch CB, operand, read (HL)
                    p[op] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4), .init(.read, 8)])
                } else {
                    // BIT r 8T: fetch CB, operand
                    p[op] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4)])
                }
            } else if source == 6 {
                // (HL) RMW: 15T fetch CB, operand, read (HL), write (HL)
                p[op] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4), .init(.read, 7), .init(.write, 11)])
            } else {
                // r 8T: fetch CB, operand
                p[op] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4)])
            }
        }
        return p
    }

    // MARK: - ED patterns (ED prefix + operand)

    static func buildEDPatterns() -> [AccessPattern] {
        var p = [AccessPattern](repeating: AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4)]), count: 256)
        // Default ED NOP (0x00..0x3F, 0x77, 0x7F etc) is 8-12T but modelled as fetch+operand
        // Override specific groups:

        // IN r,(C) / OUT (C),r 12T: fetch ED, operand, IO
        let ioOps = [0x40, 0x48, 0x50, 0x58, 0x60, 0x68, 0x70, 0x78, 0x41, 0x49, 0x51, 0x59, 0x61, 0x69, 0x71, 0x79]
        for op in ioOps { p[op] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4), .init(.io, 8)]) }

        // SBC/ADC HL,rp 15T: fetch ED, operand
        for op in [0x42, 0x52, 0x62, 0x72, 0x4A, 0x5A, 0x6A, 0x7A] {
            p[op] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4)])
        }
        // LD (nn),rp / LD rp,(nn) 20T: fetch ED, operand, addr low/high, write/read low/high
        for op in [0x43, 0x53, 0x63, 0x73] { // LD (nn),rp
            p[op] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4), .init(.read, 7), .init(.read, 10), .init(.write, 13), .init(.write, 16)])
        }
        for op in [0x4B, 0x5B, 0x6B, 0x7B] { // LD rp,(nn)
            p[op] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4), .init(.read, 7), .init(.read, 10), .init(.read, 13), .init(.read, 16)])
        }
        // NEG, RETN, IM, LD I/A etc 8-9T
        for op in [0x44, 0x4C, 0x54, 0x5C, 0x64, 0x6C, 0x74, 0x7C, 0x45, 0x4D, 0x55, 0x5D, 0x65, 0x6D, 0x75, 0x7D, 0x46, 0x4E, 0x66, 0x6E, 0x56, 0x76, 0x5E, 0x7E, 0x47, 0x4F, 0x57, 0x5F, 0x77, 0x7F] {
            p[op] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4)])
        }
        // RRD/RLD 18T: fetch ED, operand, read (HL), write (HL)
        for op in [0x67, 0x6F] {
            p[op] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4), .init(.read, 7), .init(.write, 11)])
        }
        // LDI/LDD/CPI/CPD etc 16T: fetch ED, operand, read (HL), write (DE) or just read
        for op in [0xA0, 0xA8, 0xA1, 0xA9, 0xA2, 0xAA, 0xA3, 0xAB] {
            if op == 0xA0 || op == 0xA8 {
                p[op] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4), .init(.read, 7), .init(.write, 11)])
            } else if op == 0xA2 || op == 0xAA {
                p[op] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4), .init(.write, 7), .init(.io, 11)])
            } else if op == 0xA3 || op == 0xAB {
                p[op] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4), .init(.read, 7), .init(.io, 11)])
            } else {
                p[op] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4), .init(.read, 7)])
            }
        }
        // Block repeats 21T/16T: same as non-repeat plus loop, modelled as non-repeat length
        for op in [0xB0, 0xB8, 0xB1, 0xB9, 0xB2, 0xBA, 0xB3, 0xBB] {
            // Map to non-repeat counterpart for pattern
            let base = op & 0x07 // B0->A0 etc
            // reuse same pattern as 0xA0 etc (approx)
            if base == 0 {
                p[op] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4), .init(.read, 7), .init(.write, 11)])
            } else if base == 1 {
                p[op] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4), .init(.read, 7)])
            } else if base == 2 {
                p[op] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4), .init(.write, 7), .init(.io, 11)])
            } else {
                p[op] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4), .init(.read, 7), .init(.io, 11)])
            }
        }
        return p
    }

    // MARK: - DD/FD patterns (DD/FD prefix + operand [+ displacement/data])

    static func buildDDFDPatterns() -> [AccessPattern] {
        var p = [AccessPattern](repeating: AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4)]), count: 256)
        // LD IX,nn 14T: prefix, operand, imm low/high
        p[0x21] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4), .init(.read, 7), .init(.read, 10)])
        // LD (nn),IX 20T: prefix, operand, addr low/high, write low/high
        p[0x22] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4), .init(.read, 7), .init(.read, 10), .init(.write, 13), .init(.write, 16)])
        // INC IX / DEC IX 10T: prefix, operand
        p[0x23] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4)])
        p[0x2B] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4)])
        // IXH/IXL inc/dec 8T
        for op in [0x24, 0x25, 0x2C, 0x2D] { p[op] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4)]) }
        // LD IXH,n / IXL,n 11T: prefix, operand, imm
        for op in [0x26, 0x2E, 0x06, 0x0E, 0x16, 0x1E, 0x3E] { p[op] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4), .init(.read, 8)]) }
        // LD IX,(nn) 20T
        p[0x2A] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4), .init(.read, 7), .init(.read, 10), .init(.read, 13), .init(.read, 16)])
        // ADD IX,rp 15T: prefix, operand
        for op in [0x09, 0x19, 0x29, 0x39] { p[op] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4)]) }
        // INC/DEC (IX+d) 23T: prefix, operand, d, read, write
        for op in [0x34, 0x35] { p[op] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4), .init(.read, 7), .init(.read, 11), .init(.write, 15)]) }
        // LD (IX+d),n 19T: prefix, operand, d, imm, write
        p[0x36] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4), .init(.read, 7), .init(.read, 11), .init(.write, 15)])
        // LD r,(IX+d) / LD (IX+d),r and ALU (IX+d) patterns
        // 0x70..0x77 LD (IX+d),r 19T
        for op in [0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x77] {
            p[op] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4), .init(.read, 7), .init(.write, 11)])
        }
        // 0x46 etc LD r,(IX+d) 19T
        for op in [0x46, 0x4E, 0x56, 0x5E, 0x66, 0x6E, 0x7E] { p[op] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4), .init(.read, 7), .init(.read, 11)]) }
        // 0x86 etc ALU (IX+d) 19T
        for op in 0x86...0xBE where (op & 0x07) == 0x06 { p[op] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4), .init(.read, 7), .init(.read, 11)]) }
        // PUSH IX 15T, POP IX 14T, etc
        p[0xE1] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4), .init(.read, 7), .init(.read, 10)])
        p[0xE5] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4), .init(.write, 7), .init(.write, 10)])
        p[0xE3] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4), .init(.read, 7), .init(.read, 10), .init(.write, 14), .init(.write, 18)])
        p[0xE9] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4)])
        p[0xF9] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4)])
        // 0xCB prefix handled separately (DDFDCB) - mark as fetch only for now (real work is in DDFDCB table)
        p[0xCB] = .fetchOnly
        // Undocumented and remaining: default fetch+operand
        return p
    }

    // MARK: - DDFDCB patterns (DD CB d op / FD CB d op)

    static func buildDDFDCBPatterns() -> [AccessPattern] {
        var p = [AccessPattern](repeating: AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4), .init(.read, 7), .init(.read, 10), .init(.read, 13), .init(.write, 17)]), count: 256)
        // BIT is 20T, not 23T
        for op in 0..<256 {
            let target = op >> 3
            if target >= 0x08 && target <= 0x0F {
                p[op] = AccessPattern(steps: [.init(.fetch, 0), .init(.read, 4), .init(.read, 7), .init(.read, 10), .init(.read, 13)])
            }
        }
        return p
    }
}