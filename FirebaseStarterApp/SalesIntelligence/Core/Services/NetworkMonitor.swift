import Foundation
import Network

final class NetworkMonitor {
    static let shared = NetworkMonitor()

    enum NotificationName {
        static let statusDidChange = Notification.Name("NetworkMonitor.statusDidChange")
    }

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.salesintelligence.network-monitor")
    private(set) var isConnected: Bool = true

    private init() {}

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            guard let self else { return }
            let connected = path.status == .satisfied
            if self.isConnected != connected {
                self.isConnected = connected
                NotificationCenter.default.post(name: NotificationName.statusDidChange, object: self)
            }
        }
        monitor.start(queue: queue)
    }

    func stop() {
        monitor.cancel()
    }
}
