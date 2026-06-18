import SwiftUI
import UIKit

/// Entry points for the Midgar in-app storefront.
public enum Midgar {

    /// Returns the storefront as a SwiftUI view for custom embedding.
    @MainActor
    public static func storeView(config: MidgarConfig = .default) -> some View {
        MidgarStoreView(config: config)
    }

    /// Presents the storefront modally from UIKit. Without an explicit presenter, the top-most
    /// view controller in the active scene is used.
    @MainActor
    public static func present(from presenter: UIViewController? = nil, config: MidgarConfig = .default) {
        let host = UIHostingController(rootView: MidgarStoreView(config: config))
        host.modalPresentationStyle = .automatic
        (presenter ?? topViewController())?.present(host, animated: true)
    }

    @MainActor
    static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
            ?? UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let root = scene?.windows.first(where: \.isKeyWindow)?.rootViewController
            ?? scene?.windows.first?.rootViewController
        return root.map(topMost)
    }

    @MainActor
    private static func topMost(_ controller: UIViewController) -> UIViewController {
        if let presented = controller.presentedViewController {
            return topMost(presented)
        }
        if let nav = controller as? UINavigationController, let visible = nav.visibleViewController {
            return topMost(visible)
        }
        if let tab = controller as? UITabBarController, let selected = tab.selectedViewController {
            return topMost(selected)
        }
        return controller
    }
}
