import CoreGraphics
import Foundation
import OSLog

protocol DDCServiceProtocol {
    func readValue(displayID: CGDirectDisplayID, code: VCPCode) async throws -> DDCReadResult
    func writeValue(displayID: CGDirectDisplayID, code: VCPCode, value: UInt16) async throws
    func isSupported(displayID: CGDirectDisplayID) -> Bool
}

final class DDCService {
    static func make() -> DDCServiceProtocol {
        if isAppleSilicon {
            return DDCServiceAppleSilicon()
        } else {
            return DDCServiceIntel()
        }
    }

    static var isAppleSilicon: Bool = {
        var val: Int = 0
        var size = MemoryLayout<Int>.size
        sysctlbyname("hw.optional.arm64", &val, &size, nil, 0)
        return val != 0
    }()
}

// DDC packet checksum per MCCS spec
// checksum = XOR of destination address (0x6E) with all packet bytes
func ddcChecksum(for bytes: [UInt8]) -> UInt8 {
    var checksum: UInt8 = 0x6E  // destination address
    for byte in bytes {
        checksum ^= byte
    }
    return checksum
}

// Build a DDC write packet for a VCP code
// Format: [0x51, 0x84, 0x03, vcpCode, valueHigh, valueLow, checksum]
func buildDDCWritePacket(code: VCPCode, value: UInt16) -> [UInt8] {
    let hi = UInt8((value >> 8) & 0xFF)
    let lo = UInt8(value & 0xFF)
    var packet: [UInt8] = [0x51, 0x84, 0x03, code.rawValue, hi, lo]
    packet.append(ddcChecksum(for: packet))
    return packet
}

// Build a DDC read request packet for a VCP code
// Format: [0x51, 0x82, 0x01, vcpCode, checksum]
func buildDDCReadPacket(code: VCPCode) -> [UInt8] {
    var packet: [UInt8] = [0x51, 0x82, 0x01, code.rawValue]
    packet.append(ddcChecksum(for: packet))
    return packet
}
