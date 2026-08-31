import Foundation
import MetricKit

/// Subscribes to MetricKit's crash/hang diagnostics. Unlike the crash reports in App Store
/// Connect's Xcode Organizer — which only come from devices where the user opted in to
/// "Share With App Developers" — MetricKit delivers diagnostics for every device running
/// the app, opted in or not, so this is the broader signal of the two.
///
/// Diagnostics arrive in daily batches, not in real time. Each one is summarized into an
/// anonymous TelemetryDeck signal (exception/hang type only, no stack traces or identifiers)
/// so crash volume shows up in the existing dashboard; the full JSON payload is also written
/// to Application Support purely so it can be pulled off a device via Xcode's file browser
/// during TestFlight debugging.
final class CrashDiagnosticsReporter: NSObject, MXMetricManagerSubscriber {
    static let shared = CrashDiagnosticsReporter()

    private override init() {}

    func start() {
        MXMetricManager.shared.add(self)
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for payload in payloads {
            for crash in payload.crashDiagnostics ?? [] {
                AnalyticsService.diagnosticDetected(type: "crash", detail: crash.terminationReason)
            }
            for hang in payload.hangDiagnostics ?? [] {
                AnalyticsService.diagnosticDetected(type: "hang", detail: hang.hangDuration.description)
            }
        }
        persist(payloads)
    }

    private func persist(_ payloads: [MXDiagnosticPayload]) {
        guard !payloads.isEmpty else { return }
        let directory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Diagnostics", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        for payload in payloads {
            let filename = "\(Int(payload.timeStampEnd.timeIntervalSince1970)).json"
            try? payload.jsonRepresentation().write(to: directory.appendingPathComponent(filename))
        }
    }
}
