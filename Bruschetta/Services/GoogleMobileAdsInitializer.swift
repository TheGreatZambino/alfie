import AppTrackingTransparency
import Combine
import GoogleMobileAds

/// Asks for App Tracking Transparency permission, then starts the Google Mobile Ads SDK once.
/// The SDK must not start (and no ad requests may load) until the user has answered the prompt.
@MainActor
final class GoogleMobileAdsInitializer: ObservableObject {
    static let shared = GoogleMobileAdsInitializer()

    /// True once the ATT flow has resolved and the SDK is running; ad views wait on this.
    @Published private(set) var isReady = false
    private var isRequesting = false

    /// Call when the app is active — the ATT prompt is silently skipped if the app isn't.
    /// Free-tier users only see ads, but the SDK start is gated identically for everyone.
    func requestPermissionAndStart() {
        guard !isReady, !isRequesting else { return }
        isRequesting = true
        Task { @MainActor in
            // iOS can drop an ATT request made the instant the app becomes active; wait briefly.
            try? await Task.sleep(for: .milliseconds(750))
            self.requestAuthorization()
        }
    }

    private func requestAuthorization() {
        ATTrackingManager.requestTrackingAuthorization { status in
            // Any answer (authorized, denied, restricted) is fine — denied just means non-personalized ads.
            Task { @MainActor in
                self.isRequesting = false
                // iOS skips the prompt if the app wasn't active yet; retry on the next activation.
                guard status != .notDetermined else { return }
                guard !self.isReady else { return }
                MobileAds.shared.start(completionHandler: nil)
                self.isReady = true
            }
        }
    }
}
