import Foundation

// MARK: - DDFDCB prefix table (rotate/shift/bit/res/set on (index+d))
//
// Faithful port of the switch in Z80+DDFDCB_OpCodes.swift. Indexed by the CB
// operand byte (0…255). Each handler operates on the displaced address
// `(index+d)` (resolved by the dispatcher, since the displacement precedes the
// CB operand in the byte stream) and returns the actual (M-cycle, t-state).
// Unhandled opcodes default to (2, 23); BIT (0x08…0x0F) is (2, 20).

extension OpcodeTableSet {

    static func buildDDFDCBTable() -> [DDFDCBOpcodeInfo] {
        var t = [DDFDCBOpcodeInfo](repeating: DDFDCBOpcodeInfo { _,_ in (2, 23) }, count: 256)

        for opcode in 0..<256 {
            let source = opcode & 0x07
            let target = opcode >> 3

            t[opcode] = DDFDCBOpcodeInfo { cpu, disIndex in
                let sourceValue = cpu.memory.read(from: disIndex)
                var ts = 23
                let mCycles = 2

                func writeBack(_ value: UInt8) {
                    cpu.memory.write(to: disIndex, value: value)
                    if source != 0x06 {
                        cpu.writeRegister(UInt8(source), value: value)
                    }
                }

                switch target {
                case 0x00: // rlc
                    let carryMask: UInt8 = (sourceValue & 0x80) > 0 ? 0x01 : 0x00
                    let value = (sourceValue << 1) | carryMask
                    writeBack(value)
                    cpu.F = cpu.sz53pv(value) | carryMask

                case 0x01: // rrc
                    let carryMask: UInt8 = sourceValue & 0x01
                    let value = (sourceValue >> 1) | (carryMask > 0 ? 0x80 : 0x00)
                    writeBack(value)
                    cpu.F = cpu.sz53pv(value) | carryMask

                case 0x02: // rl
                    let carryMask: UInt8 = (sourceValue & 0x80) > 0 ? 0x01 : 0x00
                    let value = (sourceValue << 1) | (cpu.F & cpu.carry)
                    writeBack(value)
                    cpu.F = cpu.sz53pv(value) | carryMask

                case 0x03: // rr
                    let carryMask: UInt8 = sourceValue & 0x01
                    let value = (sourceValue >> 1) | ((cpu.F & cpu.carry) > 0 ? 0x80 : 0x00)
                    writeBack(value)
                    cpu.F = cpu.sz53pv(value) | carryMask

                case 0x04: // sla
                    let carryMask: UInt8 = (sourceValue & 0x81)
                    let value = (sourceValue << 1)
                    writeBack(value)
                    cpu.F = cpu.sz53pv(value) | (carryMask > 1 ? 0x01 : 0x00)

                case 0x05: // sra
                    let carryMask: UInt8 = sourceValue & 0x81
                    let value = (sourceValue >> 1) | (carryMask & cpu.sign)
                    writeBack(value)
                    cpu.F = cpu.sz53pv(value) | (carryMask & cpu.carry)

                case 0x06: // sll (undocumented)
                    let carryMask: UInt8 = (sourceValue & 0x81)
                    let value = (sourceValue << 1) | cpu.carry
                    writeBack(value)
                    cpu.F = cpu.sz53pv(value) | (carryMask > 1 ? 0x01 : 0x00)

                case 0x07: // srl
                    let carryMask: UInt8 = sourceValue & 0x81
                    let value = (sourceValue >> 1)
                    writeBack(value)
                    cpu.F = cpu.sz53pv(value) | (carryMask & cpu.carry)

                case 0x08...0x0F: // BIT 0–7
                    let bit = target - 8
                    var carryMask: UInt8 = sourceValue.isSet(bit: bit) ? 0x00 : (cpu.zero | cpu.parityOverflow)
                    if bit == 0x07 {
                        carryMask = carryMask | (sourceValue & cpu.sign)
                    }
                    carryMask = carryMask | (cpu.F & cpu.carry)
                    if source == 6 {
                        carryMask = carryMask | cpu.bits53(cpu.memptr.highByte())
                    } else {
                        carryMask = carryMask | cpu.bits53(disIndex.highByte())
                    }
                    cpu.F = cpu.halfCarry | carryMask
                    ts = 20

                case 0x10...0x17: // RES 0–7
                    let bit = target - 0x10
                    let value = sourceValue & ~(1 << bit)
                    writeBack(value)

                default: // 0x18…0x1F SET 0–7
                    let bit = target - 0x18
                    let value = sourceValue | (1 << bit)
                    writeBack(value)
                }

                return (mCycles, ts)
            }
        }

        return t
    }
}
