import UIKit

final class MainTabBarController: UITabBarController {
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupTabs()
    }

    private func setupTabs() {
        let home = UINavigationController(rootViewController: HomeViewController())
        home.tabBarItem = UITabBarItem(title: "Home",
                                       image: UIImage(systemName: "house"),
                                       selectedImage: UIImage(systemName: "house.fill"))

        let practice = UINavigationController(rootViewController: PracticeViewController())
        practice.tabBarItem = UITabBarItem(title: "Practice",
                                           image: UIImage(systemName: "video"),
                                           selectedImage: UIImage(systemName: "video.fill"))

        let audioPractice = UINavigationController(rootViewController: PracticeAudioViewController())
        audioPractice.tabBarItem = UITabBarItem(title: "Audio",
                                                image: UIImage(systemName: "mic"),
                                                selectedImage: UIImage(systemName: "mic.fill"))

        let review = UINavigationController(rootViewController: ReviewViewController())
        review.tabBarItem = UITabBarItem(title: "Review",
                                         image: UIImage(systemName: "list.bullet"),
                                         selectedImage: UIImage(systemName: "list.bullet"))

        viewControllers = [home, practice, audioPractice, review]
    }
}
