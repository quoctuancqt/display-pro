import Foundation

enum VCPCode: UInt8 {
    case brightness    = 0x10
    case contrast      = 0x12
    case colorPreset   = 0x14
    case volume        = 0x62
    case inputSource   = 0x60
    case powerMode     = 0xD6
    case osdLanguage   = 0xCC
    case sharpness     = 0x87
    case redGain       = 0x16
    case greenGain     = 0x18
    case blueGain      = 0x1A
}

// Common input source VCP values — manufacturer-specific, vary widely
enum InputSourceValue: UInt16, CaseIterable {
    case vga           = 0x01
    case dvi1          = 0x03
    case dvi2          = 0x04
    case compositeVideo = 0x05
    case sVideo        = 0x06
    case hdmi1         = 0x11
    case hdmi2         = 0x12
    case displayPort1  = 0x0F
    case displayPort2  = 0x10
    case usbTypeC      = 0x1B
    case thunderbolt   = 0x1C

    var displayName: String {
        switch self {
        case .vga: return "VGA"
        case .dvi1: return "DVI-1"
        case .dvi2: return "DVI-2"
        case .compositeVideo: return "Composite"
        case .sVideo: return "S-Video"
        case .hdmi1: return "HDMI 1"
        case .hdmi2: return "HDMI 2"
        case .displayPort1: return "DisplayPort 1"
        case .displayPort2: return "DisplayPort 2"
        case .usbTypeC: return "USB-C"
        case .thunderbolt: return "Thunderbolt"
        }
    }
}

struct DDCReadResult {
    let currentValue: UInt16
    let maximumValue: UInt16
}

enum DDCError: Error, LocalizedError {
    case serviceNotFound
    case writeFailed(Int32)
    case readFailed(Int32)
    case timeout
    case unsupported
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .serviceNotFound: return "No DDC service found for this display"
        case .writeFailed(let code): return "DDC write failed with code \(code)"
        case .readFailed(let code): return "DDC read failed with code \(code)"
        case .timeout: return "DDC operation timed out"
        case .unsupported: return "DDC not supported on this display"
        case .invalidResponse: return "Invalid DDC response"
        }
    }
}
