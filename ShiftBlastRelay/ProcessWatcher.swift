import Foundation
import Darwin
import OSLog

private let log = Logger(subsystem: "com.davide.shiftblast.relay", category: "ProcessWatcher")

/// Polls the process table once per second and fires `onAgentFinished` whenever
/// a specific process PID whose name is in `AgentNames.processNames` was running
/// on the previous tick and is no longer running on the current one.
///
/// Works inside the App Sandbox: `sysctl(KERN_PROC_ALL)` returns at minimum the
/// processes belonging to the calling user, with `kproc.kp_proc.p_comm` filled
/// in. We never read argv (`KERN_PROCARGS2` is restricted in sandbox), so only
/// agents whose binary name itself is a known one are detected.
@MainActor
final class ProcessWatcher {
    private let onAgentFinished: @MainActor (String) -> Void
    private let interval: TimeInterval
    private var timer: Timer?
    private var previouslyRunning: [pid_t: String] = [:]
    private var hasInitialSnapshot = false

    init(interval: TimeInterval = 1.0, onAgentFinished: @escaping @MainActor (String) -> Void) {
        self.interval = interval
        self.onAgentFinished = onAgentFinished
    }

    func start() {
        guard timer == nil else { return }
        tick()
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        previouslyRunning = [:]
        hasInitialSnapshot = false
    }

    deinit {
        timer?.invalidate()
    }

    private func tick() {
        let running = Self.runningAgentProcesses()

        if !hasInitialSnapshot {
            previouslyRunning = running
            hasInitialSnapshot = true
            if running.isEmpty {
                log.debug("📸 snapshot iniziale: nessun agente attivo")
            } else {
                log.notice("📸 snapshot iniziale: agenti già attivi \(Self.summary(running), privacy: .public)")
            }
            return
        }

        let runningPIDs = Set(running.keys)
        let previousPIDs = Set(previouslyRunning.keys)
        let startedPIDs = runningPIDs.subtracting(previousPIDs).sorted()
        let finishedPIDs = previousPIDs.subtracting(runningPIDs).sorted()

        for pid in startedPIDs {
            guard let name = running[pid] else { continue }
            log.notice("▶️ agente AVVIATO: \(name, privacy: .public) pid=\(pid, privacy: .public)")
        }
        for pid in finishedPIDs {
            guard let name = previouslyRunning[pid] else { continue }
            log.notice("⏹️ agente TERMINATO: \(name, privacy: .public) pid=\(pid, privacy: .public)")
            onAgentFinished(name)
        }

        if !startedPIDs.isEmpty || !finishedPIDs.isEmpty {
            log.debug("📊 agenti attivi ora: \(Self.summary(running), privacy: .public)")
        }
        previouslyRunning = running
    }

    /// Snapshot of process PIDs matching `AgentNames.processNames` from the
    /// current process table.
    static func runningAgentProcesses() -> [pid_t: String] {
        guard let processes = sysctlProcessList() else { return [:] }
        var result: [pid_t: String] = [:]
        for entry in processes where AgentNames.processNames.contains(entry.name) {
            result[entry.pid] = entry.name
        }
        return result
    }

    private static func summary(_ processes: [pid_t: String]) -> String {
        guard !processes.isEmpty else { return "nessuno" }
        let grouped = Dictionary(grouping: processes.values, by: { $0 })
        return grouped
            .map { name, values in "\(name)x\(values.count)" }
            .sorted()
            .joined(separator: ", ")
    }

    private struct ProcEntry {
        let pid: pid_t
        let name: String
    }

    private static func sysctlProcessList() -> [ProcEntry]? {
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
        var size = 0
        if sysctl(&mib, u_int(mib.count), nil, &size, nil, 0) != 0 { return nil }

        let count = size / MemoryLayout<kinfo_proc>.stride
        guard count > 0 else { return [] }

        var buffer = [kinfo_proc](repeating: kinfo_proc(), count: count)
        let status = buffer.withUnsafeMutableBufferPointer { ptr -> Int32 in
            sysctl(&mib, u_int(mib.count), ptr.baseAddress, &size, nil, 0)
        }
        if status != 0 { return nil }

        let actualCount = size / MemoryLayout<kinfo_proc>.stride
        return (0..<actualCount).map { i in
            var proc = buffer[i].kp_proc
            let name = withUnsafePointer(to: &proc.p_comm) { tuplePtr -> String in
                tuplePtr.withMemoryRebound(to: CChar.self, capacity: Int(MAXCOMLEN) + 1) { cstr in
                    String(cString: cstr)
                }
            }
            return ProcEntry(pid: buffer[i].kp_proc.p_pid, name: name)
        }
    }
}
