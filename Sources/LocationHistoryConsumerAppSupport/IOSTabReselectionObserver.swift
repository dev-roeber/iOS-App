#if canImport(SwiftUI) && canImport(UIKit) && os(iOS)
import SwiftUI
import UIKit

struct IOSTabReselectionObserver: UIViewControllerRepresentable {
    let onTabSelection: (Int, Bool) -> Void

    func makeUIViewController(context: Context) -> ObserverViewController {
        let controller = ObserverViewController()
        controller.onTabSelection = onTabSelection
        return controller
    }

    func updateUIViewController(_ uiViewController: ObserverViewController, context: Context) {
        uiViewController.onTabSelection = onTabSelection
    }
}

final class ObserverViewController: UIViewController, UITabBarControllerDelegate {
    var onTabSelection: ((Int, Bool) -> Void)?

    private weak var previousDelegate: UITabBarControllerDelegate?
    private var lastSelectedIndex: Int?
    private var hasObservedInitialSelection = false

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        attachToTabBarControllerIfNeeded()
    }

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        attachToTabBarControllerIfNeeded()
    }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        let selectedIndex = tabBarController.selectedIndex
        let isReselection = hasObservedInitialSelection && lastSelectedIndex == selectedIndex
        hasObservedInitialSelection = true
        lastSelectedIndex = selectedIndex

        onTabSelection?(selectedIndex, isReselection)
        previousDelegate?.tabBarController?(tabBarController, didSelect: viewController)
    }

    private func attachToTabBarControllerIfNeeded() {
        guard let tabBarController = parentTabBarController else {
            return
        }

        if tabBarController.delegate !== self {
            previousDelegate = tabBarController.delegate
            tabBarController.delegate = self
            lastSelectedIndex = tabBarController.selectedIndex
            hasObservedInitialSelection = false
        }
    }

    private var parentTabBarController: UITabBarController? {
        sequence(first: parent, next: \.parent)
            .compactMap { $0 as? UITabBarController }
            .first
    }
}
#endif
