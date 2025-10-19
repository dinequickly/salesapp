import UIKit
import WebKit

final class PracticeAudioViewController: UIViewController {
    private var webView: WKWebView!

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Audio"
        view.backgroundColor = .systemBackground
        configureWebView()
        loadAgentWidget()
    }

    private func configureWebView() {
        let configuration = WKWebViewConfiguration()
        if #available(iOS 15.0, *) {
            configuration.mediaTypesRequiringUserActionForPlayback = []
        } else {
            configuration.requiresUserActionForMediaPlayback = false
        }
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        view.addSubview(webView)

        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func loadAgentWidget() {
        let html = """
        <!DOCTYPE html>
        <html lang=\"en\">
        <head>
            <meta charset=\"utf-8\">
            <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
            <style>
                body { margin: 0; padding: 0; background: #f2f2f7; }
                .container { display: flex; justify-content: center; align-items: center; height: 100vh; }
            </style>
        </head>
        <body>
            <div class=\"container\">
                <elevenlabs-convai agent-id=\"agent_1801k4yzmzs1exz9bee2kep0npbq\"></elevenlabs-convai>
            </div>
            <script src=\"https://unpkg.com/@elevenlabs/convai-widget-embed\" async type=\"text/javascript\"></script>
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }
}
