import GoogleMobileAds
import SwiftUI

/// Wraps a Google Mobile Ads adaptive anchored banner. Sized to the full screen width at
/// the view's own position — callers pin it with `.safeAreaInset(edge: .bottom)`.
struct BannerAdView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> BannerAdViewController {
        BannerAdViewController()
    }

    func updateUIViewController(_ uiViewController: BannerAdViewController, context: Context) {}
}

final class BannerAdViewController: UIViewController {
    private let bannerView = BannerView()
    private var didRequestAd = false

    override func viewDidLoad() {
        super.viewDidLoad()
        bannerView.adUnitID = Secrets.admobBannerAdUnitID
        bannerView.rootViewController = self
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

extension BannerAdViewController {
    /// Fixed height of the standard adaptive banner at typical iPhone widths, used so
    /// SwiftUI can reserve layout space before the ad loads.
    static let approximateHeight: CGFloat = 50
}
