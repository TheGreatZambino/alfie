import AppTrackingTransparency
import Combine
import GoogleMobileAds
import UIKit

/// Asks for App Tracking Transparency permission, then starts the Google Mobile Ads SDK once.
/// The SDK must not start (and no ad requests may load) until the user has answered the prompt.
@MainActor
final class GoogleMobileAdsInitializer: ObservableObject {
    static let shared = GoogleMobileAdsInitializer()

    /// True once the ATT flow has resolved and the SDK is running; ad views wait on this.
    @Published private(set) var isReady = false
    private var isRequesting = false

    /// Suspends until the ATT flow has resolved, so other launch-time system prompts don't pre-empt it.
    func waitUntilResolved(timeout: Duration = .seconds(30)) async {
        let deadline = ContinuousClock.now + timeout
        while !isReady, ContinuousClock.now < deadline {
            try? await Task.sleep(for: .milliseconds(300))
        }
    }

    /// Call when the app is active — the ATT prompt is silently skipped if the app isn't.
    /// Free-tier users only see ads, but the SDK start is gated identically for everyone.
    func requestPermissionAndStart() {
        guard !isReady, !isRequesting else { return }
        isRequesting = true
        Task {
            // iOS silently drops an ATT request made while the app isn't active or another system
            // prompt/sheet is up (it returns .notDetermined). Keep retrying until it actually resolves.
            var attempts = 0
            while attempts < 20 {
                attempts += 1
                try? await Task.sleep(for: .milliseconds(attempts == 1 ? 1000 : 1500))
                guard UIApplication.shared.applicationState == .active else { continue }
                // Any answer (authorized, denied, restricted) is fine — denied just means non-personalized ads.
                let status = await ATTrackingManager.requestTrackingAuthorization()
                if status != .notDetermined { break }
            }
            guard ATTrackingManager.trackingAuthorizationStatus != .notDetermined else {
                isRequesting = false  // retry on next activation
                return
            }
            _ = await MobileAds.shared.start()
            isReady = true
            isRequesting = false
        }
    }
}
