import UIKit
import os

/// Entry points for the Midgar in-app storefront.
public enum Midgar {

    private static let log = Logger(subsystem: "com.midgar.storefront", category: "Midgar")

    /// Returns the storefront wrapped in a navigation controller, ready to present or embed.
    @MainActor
    public static func makeStoreViewController(config: MidgarConfig = .default) -> UIViewController {
        let store = MidgarStoreViewController(config: config)
        let navigation = UINavigationController(rootViewController: store)
        navigation.navigationBar.prefersLargeTitles = true
        if let accent = config.accent { navigation.view.tintColor = accent }
        return navigation
    }

    /// Presents the storefront modally. Without an explicit presenter, the top-most view controller
    /// in the active scene is used — convenient from SwiftUI hosts and UIKit alike.
    /// Returns `false` (and logs) when no presenter could be found; pass an explicit `presenter`
    /// from custom-window hosts to guarantee presentation.
    @discardableResult
    @MainActor
    public static func present(from presenter: UIViewController? = nil, config: MidgarConfig = .default) -> Bool {
        guard let host = presenter ?? topViewController() else {
            log.error("Midgar.present found no view controller to present from; pass an explicit presenter.")
            assertionFailure("Midgar.present found no view controller to present from.")
            return false
        }
        let navigation = makeStoreViewController(config: config)
        navigation.modalPresentationStyle = .automatic
        host.present(navigation, animated: true)
        return true
    }

    @MainActor
    static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        let root = scene?.windows.first(where: \.isKeyWindow)?.rootViewController
            ?? scene?.windows.first?.rootViewController
        return root.map(topMost)
    }

    @MainActor
    private static func topMost(_ controller: UIViewController) -> UIViewController {
        if let presented = controller.presentedViewController {
            return topMost(presented)
        }
        if let navigation = controller as? UINavigationController, let visible = navigation.visibleViewController {
            return topMost(visible)
        }
        if let tab = controller as? UITabBarController, let selected = tab.selectedViewController {
            return topMost(selected)
        }
        return controller
    }
}
