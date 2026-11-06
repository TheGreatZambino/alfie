import GoogleMobileAds
import SwiftUI

/// Wraps a Google Mobile Ads adaptive anchored banner. Sized to the full screen width at
/// the view's own position — callers pin it with `.safeAreaInset(edge: .bottom)`.
struct BannerAdView: UIViewControllerRepresentable {
    /// Called with true when an ad loads and false when a request gets no ad.
    var onLoadResult: (Bool) -> Void = { _ in }

    func makeUIViewController(context: Context) -> BannerAdViewController {
        let controller = BannerAdViewController()
        controller.onLoadResult = onLoadResult
        return controller
    }

    func updateUIViewController(_ uiViewController: BannerAdViewController, context: Context) {
        uiViewController.onLoadResult = onLoadResult
    }
}

final class BannerAdViewController: UIViewController {
    private let bannerView = BannerView()
    private var didRequestAd = false
    var onLoadResult: (Bool) -> Void = { _ in }

    override func viewDidLoad() {
        super.viewDidLoad()
        bannerView.adUnitID = Secrets.admobBannerAdUnitID
        bannerView.rootViewController = self
        bannerView.delegate = self
        bannerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bannerView)
        NSLayoutConstraint.activate([
            bannerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bannerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bannerView.topAnchor.constraint(equalTo: view.topAnchor),
            bannerView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        let width = view.frame.width
        guard width > 0 else { return }
        bannerView.adSize = currentOrientationAnchoredAdaptiveBanner(width: width)
        guard !didRequestAd else { return }
        didRequestAd = true
        bannerView.load(Request())
    }
}

extension BannerAdViewController: BannerViewDelegate {
    func bannerViewDidReceiveAd(_ bannerView: BannerView) {
        print("[Ads] banner loaded, size \(bannerView.adSize.size)")
        onLoadResult(true)
    }

    func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
        print("[Ads] banner failed: \((error as NSError).code) \(error.localizedDescription)")
        onLoadResult(false)
    }
}

extension BannerAdViewController {
    /// Fixed height of the standard adaptive banner at typical iPhone widths, used so
    /// SwiftUI can reserve layout space before the ad loads.
    static let approximateHeight: CGFloat = 50
}
