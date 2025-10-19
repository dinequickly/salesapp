import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        _ = AppState.shared
        NetworkMonitor.shared.start()
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = initialRootController()
        window.makeKeyAndVisible()
        self.window = window
    }

    private func initialRootController() -> UIViewController {
        if AppState.shared.hasUserId {
            return MainTabBarController()
        } else {
            let entry = UserIdEntryViewController()
            entry.onCompletion = { [weak self] in
                self?.showMainInterface()
            }
            let navigationController = UINavigationController(rootViewController: entry)
            navigationController.navigationBar.prefersLargeTitles = true
            return navigationController
        }
    }

    private func showMainInterface() {
        guard let window else { return }
        let tabController = MainTabBarController()
        UIView.transition(with: window,
                          duration: 0.3,
                          options: [.transitionCrossDissolve],
                          animations: {
                              window.rootViewController = tabController
                          })
    }
}
