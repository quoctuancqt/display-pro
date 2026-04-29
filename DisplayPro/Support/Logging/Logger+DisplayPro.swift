import OSLog

extension Logger {
    static let hardware = Logger(subsystem: "com.displaypro.app", category: "hardware")
    static let ddc      = Logger(subsystem: "com.displaypro.app", category: "ddc")
    static let ui       = Logger(subsystem: "com.displaypro.app", category: "ui")
}
