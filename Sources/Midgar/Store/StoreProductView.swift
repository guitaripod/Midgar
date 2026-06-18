import SwiftUI
import StoreKit

/// Presents a native App Store product page in-app via `SKStoreProductViewController`, so users can
/// install without leaving the host app. Falls back to opening the public store URL if the product
/// fails to load (e.g. unavailable in the current storefront).
struct StoreProductView: UIViewControllerRepresentable {
    let appId: String
    let fallbackURL: URL
    let onFinish: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(fallbackURL: fallbackURL, onFinish: onFinish)
    }

    func makeUIViewController(context: Context) -> SKStoreProductViewController {
        let controller = SKStoreProductViewController()
        controller.delegate = context.coordinator
        let parameters = [SKStoreProductParameterITunesItemIdentifier: appId]
        controller.loadProduct(withParameters: parameters) { success, _ in
            if !success { context.coordinator.openFallback() }
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: SKStoreProductViewController, context: Context) {}

    final class Coordinator: NSObject, SKStoreProductViewControllerDelegate {
        private let fallbackURL: URL
        private let onFinish: () -> Void
        private var didFallback = false

        init(fallbackURL: URL, onFinish: @escaping () -> Void) {
            self.fallbackURL = fallbackURL
            self.onFinish = onFinish
        }

        func productViewControllerDidFinish(_ viewController: SKStoreProductViewController) {
            onFinish()
        }

        func openFallback() {
            guard !didFallback else { return }
            didFallback = true
            UIApplication.shared.open(fallbackURL)
            onFinish()
        }
    }
}
