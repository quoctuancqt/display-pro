import CoreGraphics
import Foundation
import IOKit
import OSLog

// IOAVService functions — header not in public SDK, declared manually
// These are in IOKit.framework and work on Apple Silicon for DDC via USB-C/Thunderbolt
@_silgen_name("IOAVServiceCreate")
func IOAVServiceCreate(_ allocator: CFAllocator?, _ service: io_service_t, _ options: CFDictionary?) -> Unmanaged<AnyObject>?

@_silgen_name("IOAVServiceWriteI2C")
func IOAVServiceWriteI2C(
    _ service: io_service_t,
    _ chipAddress: UInt32,
    _ offset: UInt32,
    _ buffer: UnsafeMutableRawPointer,
    _ bufferSize: UInt32
) -> IOReturn

@_silgen_name("IOAVServiceReadI2C")
func IOAVServiceReadI2C(
    _ service: io_service_t,
    _ chipAddress: UInt32,
    _ offset: UInt32,
    _ buffer: UnsafeMutableRawPointer,
    _ bufferSize: UInt32
) -> IOReturn

final class DDCServiceAppleSilicon: DDCServiceProtocol, @unchecked Sendable {
    private let logger = Logger.ddc
    private let ddcQueue = DispatchQueue(label: "com.displaypro.ddc.applesilicon", qos: .userInitiated)

    func isSupported(displayID: CGDirectDisplayID) -> Bool {
        // Built-in displays and built-in HDMI on Apple Silicon don't support DDC
        if CGDisplayIsBuiltin(displayID) != 0 { return false }
        return findAVService(for: displayID) != nil
    }

    func readValue(displayID: CGDirectDisplayID, code: VCPCode) async throws -> DDCReadResult {
        return try await withCheckedThrowingContinuation { continuation in
            ddcQueue.async { [self] in
                do {
                    let result = try self.readSync(displayID: displayID, code: code)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func writeValue(displayID: CGDirectDisplayID, code: VCPCode, value: UInt16) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            ddcQueue.async { [self] in
                do {
                    try self.writeSync(displayID: displayID, code: code, value: value)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Private

    // Cache: displayID → service entry index (avoids repeated enumeration)
    private var serviceIndexCache: [CGDirectDisplayID: Int] = [:]

    private func findAVService(for displayID: CGDirectDisplayID) -> io_service_t? {
        // On Apple Silicon, IOAVService entries correspond to physical ports.
        // We match by testing I2C connectivity — the service that successfully
        // responds to a display corresponds to our target display.
        // For single-external-display setups this just returns the first entry.

        let services = enumerateAVServices()
        guard !services.isEmpty else { return nil }

        // Use cached index if available
        if let idx = serviceIndexCache[displayID], idx < services.count {
            return services[idx]
        }

        // For the first call, probe which service corresponds to this display.
        // Match via CGDisplayVendorNumber/ModelNumber read from IOKit service properties.
        let expectedVendor = CGDisplayVendorNumber(displayID)
        let expectedModel = CGDisplayModelNumber(displayID)

        for (idx, service) in services.enumerated() {
            if let vendor = IORegistryProperty(service, key: "DisplayVendorID") as? UInt32,
               let model = IORegistryProperty(service, key: "DisplayProductID") as? UInt32,
               vendor == expectedVendor && model == expectedModel {
                serviceIndexCache[displayID] = idx
                return service
            }
        }

        // If property matching fails, return first service for single-display setups
        if services.count == 1 {
            serviceIndexCache[displayID] = 0
            return services[0]
        }

        return nil
    }

    private func enumerateAVServices() -> [io_service_t] {
        var services: [io_service_t] = []

        // Try DCPAVServiceProxy first (Apple Silicon native service)
        for className in ["DCPAVServiceProxy", "IOAVService"] {
            var iter = io_iterator_t()
            guard IOServiceGetMatchingServices(
                kIOMainPortDefault,
                IOServiceMatching(className),
                &iter
            ) == kIOReturnSuccess else { continue }
            defer { IOObjectRelease(iter) }

            var service = IOIteratorNext(iter)
            while service != 0 {
                services.append(service)
                service = IOIteratorNext(iter)
            }
            if !services.isEmpty { break }
        }
        return services
    }

    private func IORegistryProperty(_ service: io_service_t, key: String) -> Any? {
        IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue()
    }

    private func writeSync(displayID: CGDirectDisplayID, code: VCPCode, value: UInt16) throws {
        guard let service = findAVService(for: displayID) else {
            throw DDCError.serviceNotFound
        }
        defer { IOObjectRelease(service) }

        var packet = buildDDCWritePacket(code: code, value: value)
        let result = IOAVServiceWriteI2C(service, 0x37, 0x51, &packet, UInt32(packet.count))
        guard result == kIOReturnSuccess else {
            throw DDCError.writeFailed(result)
        }
        // Allow monitor to process the command
        usleep(50_000)
    }

    private func readSync(displayID: CGDirectDisplayID, code: VCPCode, attempt: Int = 0) throws -> DDCReadResult {
        guard let service = findAVService(for: displayID) else {
            throw DDCError.serviceNotFound
        }
        defer { IOObjectRelease(service) }

        // Send read request
        var writePacket = buildDDCReadPacket(code: code)
        let writeResult = IOAVServiceWriteI2C(service, 0x37, 0x51, &writePacket, UInt32(writePacket.count))
        guard writeResult == kIOReturnSuccess else {
            throw DDCError.writeFailed(writeResult)
        }

        usleep(50_000)

        // Read response (11 bytes for VCP get reply)
        var replyBuffer = [UInt8](repeating: 0, count: 11)
        let readResult = IOAVServiceReadI2C(service, 0x37, 0x51, &replyBuffer, UInt32(replyBuffer.count))

        guard readResult == kIOReturnSuccess else {
            if attempt < 2 {
                usleep(50_000)
                return try readSync(displayID: displayID, code: code, attempt: attempt + 1)
            }
            throw DDCError.readFailed(readResult)
        }

        // Parse response: [0x6E, 0x88, 0x02, opcode, vcpCode, maxHi, maxLo, curHi, curLo, ...]
        guard replyBuffer[1] == 0x88, replyBuffer[2] == 0x02 else {
            throw DDCError.invalidResponse
        }

        let maxValue = (UInt16(replyBuffer[5]) << 8) | UInt16(replyBuffer[6])
        let currentValue = (UInt16(replyBuffer[7]) << 8) | UInt16(replyBuffer[8])
        return DDCReadResult(currentValue: currentValue, maximumValue: maxValue)
    }
}
