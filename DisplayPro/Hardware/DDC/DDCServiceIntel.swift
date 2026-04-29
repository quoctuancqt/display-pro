import CoreGraphics
import Foundation
import IOKit
import OSLog

// Intel DDC path uses IOI2C interfaces which were deprecated in macOS 10.9
// and largely removed in later SDK versions. On modern Apple Silicon Macs,
// DDCServiceAppleSilicon handles DDC via IOAVService instead.
// This stub is kept for completeness but returns unsupported for all operations.

final class DDCServiceIntel: DDCServiceProtocol, @unchecked Sendable {
    private let logger = Logger.ddc

    func isSupported(displayID: CGDirectDisplayID) -> Bool {
        // Intel I2C DDC is not supported on macOS 12+ with modern SDK
        return false
    }

    func readValue(displayID: CGDirectDisplayID, code: VCPCode) async throws -> DDCReadResult {
        throw DDCError.unsupported
    }

    func writeValue(displayID: CGDirectDisplayID, code: VCPCode, value: UInt16) async throws {
        throw DDCError.unsupported
    }
}
