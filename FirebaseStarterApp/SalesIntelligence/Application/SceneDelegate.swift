import Combine
import SwiftUI
import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    private var cancellables: Set<AnyCancellable> = []
    private var onboardingNavigationController: UINavigationController?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = initialRootController()
        window.makeKeyAndVisible()
        self.window = window

        _ = AppState.shared // Ensure eager initialisation
        NetworkMonitor.shared.start()

        observeOnboardingProgress()
    }

    private func initialRootController() -> UIViewController {
        let supabase = SupabaseService.shared // prime auth listeners

        switch supabase.step {
        case .completed:
            return MainTabBarController()
        default:
            let controller = makeOnboardingController()
            onboardingNavigationController = controller
            return controller
        }
    }

    private func makeOnboardingController() -> UINavigationController {
        let hostingController = UIHostingController(
            rootView: OnboardingContainerView { [weak self] in
                self?.showMainInterface()
            }
        )
        hostingController.view.backgroundColor = .systemBackground

        let navigationController = UINavigationController(rootViewController: hostingController)
        navigationController.setNavigationBarHidden(true, animated: false)
        return navigationController
    }

    private func showMainInterface(animated: Bool = true) {
        guard let window else { return }
        onboardingNavigationController = nil

        let controller = MainTabBarController()
        let transitionBlock = {
            window.rootViewController = controller
        }

        if animated {
            UIView.transition(with: window,
                              duration: 0.3,
                              options: [.transitionCrossDissolve],
                              animations: transitionBlock)
        } else {
            transitionBlock()
        }
    }

    private func showOnboardingIfNeeded(animated: Bool = true) {
        guard let window else { return }

        if window.rootViewController === onboardingNavigationController,
           onboardingNavigationController != nil {
            return
        }

        let controller = makeOnboardingController()
        onboardingNavigationController = controller

        let transitionBlock = {
            window.rootViewController = controller
        }

        if animated {
            UIView.transition(with: window,
                              duration: 0.3,
                              options: [.transitionCrossDissolve],
                              animations: transitionBlock)
        } else {
            transitionBlock()
        }
    }

    private func observeOnboardingProgress() {
        SupabaseService.shared.$step
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] step in
                switch step {
                case .completed:
                    self?.showMainInterface()
                default:
                    self?.showOnboardingIfNeeded()
                }
            }
            .store(in: &cancellables)
    }
}
