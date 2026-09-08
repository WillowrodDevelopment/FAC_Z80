import Foundation

// MARK: - CB prefix table (rotate/shift/bit/res/set)
//
// The CB prefix is fully matrix-structured: bits 5–3 select the operation
// (0–7 rotate/shift, 8–15 BIT, 16–23 RES, 24–31 SET) and bits 2–0 select the
// source register (6 = (HL)). It is the smallest, most self-contained decoder,
// so it is the pilot for the switch→table refactor.
//
// This port is logic-identical to the switch implementation in
// Z80+CB_OpCodes.swift so the oracle can prove byte-for-byte equivalence.

extension OpcodeTableSet {

    /// Builds the 256-entry CB table. Indexed by the CB operand byte.
    static func buildCBTable() -> [OpcodeInfo] {
        var table = [OpcodeInfo](repeating: OpcodeInfo { _ in (0, 0) }, count: 256)

        for opcode in 0..<256 {
            let source = opcode & 0x07
            let target = opcode >> 3

            table[opcode] = OpcodeInfo { cpu in
                // Read the CB operand the same way opCodeCB does (via next()):
                // this advances PC and records the fetch in the access log,
                // keeping the table byte-identical to the switch.
                _ = cpu.next()
                let sourceValue = cpu.valueFromSource(source: UInt8(source))
                var ts = source == 0x06 ? 15 : 8
                let mCycles = 2

                switch target {
                case 0x00: // rlc
                    let carryMask: UInt8 = (sourceValue & 0x80) > 0 ? 0x01 : 0x00
                    let value = (sourceValue << 1) | carryMask
                    cpu.writeRegister(UInt8(source), value: value)
                    cpu.F = cpu.sz53pv(value) | carryMask

                case 0x01: // rrc
                    let carryMask: UInt8 = sourceValue & 0x01
                    let value = (sourceValue >> 1) | (carryMask > 0 ? 0x80 : 0x00)
                    cpu.writeRegister(UInt8(source), value: value)
                    cpu.F = cpu.sz53pv(value) | carryMask

                case 0x02: // rl
                    let carryMask: UInt8 = (sourceValue & 0x80) > 0 ? 0x01 : 0x00
                    let value = (sourceValue << 1) | (cpu.F & cpu.carry)
                    cpu.writeRegister(UInt8(source), value: value)
                    cpu.F = cpu.sz53pv(value) | carryMask

                case 0x03: // rr
                    let carryMask: UInt8 = sourceValue & 0x01
                    let value = (sourceValue >> 1) | ((cpu.F & cpu.carry) > 0 ? 0x80 : 0x00)
                    cpu.writeRegister(UInt8(source), value: value)
                    cpu.F = cpu.sz53pv(value) | carryMask

                case 0x04: // sla
                    let carryMask: UInt8 = (sourceValue & 0x81)
                    let value = (sourceValue << 1)
                    cpu.writeRegister(UInt8(source), value: value)
                    cpu.F = cpu.sz53pv(value) | (carryMask > 1 ? 0x01 : 0x00)

                case 0x05: // sra
                    let carryMask: UInt8 = sourceValue & 0x81
                    let value = (sourceValue >> 1) | (carryMask & cpu.sign)
                    cpu.writeRegister(UInt8(source), value: value)
                    cpu.F = cpu.sz53pv(value) | (carryMask & cpu.carry)

                case 0x06: // sll (undocumented)
                    let carryMask: UInt8 = (sourceValue & 0x81)
                    let value = (sourceValue << 1) | cpu.carry
                    cpu.writeRegister(UInt8(source), value: value)
                    cpu.F = cpu.sz53pv(value) | (carryMask > 1 ? 0x01 : 0x00)

                case 0x07: // srl
                    let carryMask: UInt8 = sourceValue & 0x81
                    let value = (sourceValue >> 1)
                    cpu.writeRegister(UInt8(source), value: value)
                    cpu.F = cpu.sz53pv(value) | (carryMask & cpu.carry)

                case 0x08...0x0F: // BIT 0–7
                    let bit = target - 8
                    var carryMask: UInt8 = sourceValue.isSet(bit: bit) ? 0x00 : (cpu.zero | cpu.parityOverflow)
                    if bit == 0x07 {
                        carryMask = carryMask | (sourceValue & cpu.sign)
                    }
                    carryMask = carryMask | (cpu.F & cpu.carry)
                    if source == 6 {
                        ts = 12
                        carryMask = carryMask | cpu.bits53(cpu.memptr.highByte())
                    } else {
                        carryMask = carryMask | cpu.bits53(sourceValue)
                    }
                    cpu.F = cpu.halfCarry | carryMask

                case 0x10...0x17: // RES 0–7
                    let bit = target - 0x10
                    cpu.writeRegister(UInt8(source), value: sourceValue & ~(1 << bit))

                case 0x18...0x1F: // SET 0–7
                    let bit = target - 0x18
                    cpu.writeRegister(UInt8(source), value: sourceValue | (1 << bit))

                default:
                    break
                }

                return (mCycles, ts)
            }
        }

        let patterns = buildCBPatterns()
        for op in 0..<256 { table[op].accessPattern = patterns[op] }

        return table
    }
}
