import GoogleMobileAds

/// Starts the Google Mobile Ads SDK once at launch, per Google's integration guide.
enum GoogleMobileAdsInitializer {
    static func start() {
        MobileAds.shared.start(completionHandler: nil)
    }
}
