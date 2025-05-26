#if canImport(OSLog)
import OSLog
#else
import Foundation

// Fallback for platforms without OSLog

package struct Logger {
    let subsystem: String
    let category: String

    func log(_ message: String) {
        print("[\(subsystem).\(category)] \(message)")
    }

    func debug(_ message: String) {
        print("[DEBUG] [\(subsystem).\(category)] \(message)")
    }

    func info(_ message: String) {
        print("[INFO] [\(subsystem).\(category)] \(message)")
    }

    func warning(_ message: String) {
        print("[WARNING] [\(subsystem).\(category)] \(message)")
    }

    func fault(_ message: String) {
        print("[FAULT] [\(subsystem).\(category)] \(message)")
    }
}
#endif

