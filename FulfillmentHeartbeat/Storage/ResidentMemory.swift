import Foundation
#if canImport(Darwin)
import Darwin
import os
#endif

/// Debug footprint log. Release builds keep the call and do not sample.
enum ResidentMemory {
    /// Same 400 MB ceiling as `PulseLaunch.residentMemoryBudgetBytes`.
    static let budgetBytes: UInt64 = 400 * 1024 * 1024

    static func note(_ screen: String) {
        #if DEBUG && canImport(Darwin)
        let footprint = physicalFootprint()
        let available = os_proc_available_memory()
        let prior = peaks[screen] ?? 0
        guard footprint > prior else { return }
        peaks[screen] = footprint
        let peakMB = Double(footprint) / 1_048_576
        let freeMB = Double(available) / 1_048_576
        let line = String(format: "HB memory %@ peak %.1f MB, available %.1f MB", screen, peakMB, freeMB)
        print(line)
        if footprint > budgetBytes {
            print("HB memory \(screen) is over the 400 MB budget")
        }
        #else
        _ = screen
        #endif
    }

    #if DEBUG && canImport(Darwin)
    private static var peaks: [String: UInt64] = [:]

    private static func physicalFootprint() -> UInt64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer -> kern_return_t in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), rebound, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return UInt64(info.phys_footprint)
    }
    #endif
}
