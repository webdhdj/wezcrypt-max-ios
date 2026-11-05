import UIKit
import WebKit

/// Native shell for https://max.wezcrypt.site — WezCrypt MAX.
/// All app features live in the web app (chat, web search, autonomous agent,
/// file uploads, image generator); this controller provides the native
/// chrome: full-screen WKWebView, pull-to-refresh, progress bar, download
/// handling (share sheet), external-link routing and an offline retry view.
final class ViewController: UIViewController {
    static let appBackground = UIColor(red: 10/255, green: 12/255, blue: 16/255, alpha: 1)
    private static let accent = UIColor(red: 77/255, green: 163/255, blue: 1, alpha: 1)
    private let homeURL = URL(string: "https://max.wezcrypt.site")!

    private var webView: WKWebView!
    private let progressView = UIProgressView(progressViewStyle: .bar)
    private var errorView: UIView!
    private var progressObservation: NSKeyValueObservation?
    private var downloadDestinations: [ObjectIdentifier: URL] = [:]

    override func loadView() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        // The web app persists chats/jobs in localStorage — keep it durable.
        config.websiteDataStore = .default()

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.isOpaque = false
        webView.backgroundColor = Self.appBackground
        webView.scrollView.backgroundColor = Self.appBackground
        // Lets the site know it runs inside the native app (hides the
        // "install the PWA" banner, which is meaningless here).
        webView.customUserAgent = (webView.value(forKey: "userAgent") as? String ?? "")
            + " WezCryptMAXApp/1.0"

        let refresh = UIRefreshControl()
        refresh.addTarget(self, action: #selector(reloadPage), for: .valueChanged)
        webView.scrollView.refreshControl = refresh

        self.webView = webView
        view = UIView()
        view.backgroundColor = Self.appBackground
        view.addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        progressView.trackTintColor = .clear
        progressView.progressTintColor = Self.accent
        progressView.alpha = 0
        view.addSubview(progressView)
        progressView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            progressView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 2)
        ])
        buildErrorView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] _, change in
            guard let self, let value = change.newValue else { return }
            DispatchQueue.main.async {
                self.progressView.progress = Float(value)
                UIView.animate(withDuration: 0.25) {
                    self.progressView.alpha = value >= 1.0 ? 0 : 1
                }
            }
        }
        webView.load(URLRequest(url: homeURL))
    }

    override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }

    @objc private func reloadPage() { webView.reload() }

    // MARK: offline / error overlay
    private func buildErrorView() {
        let container = UIView()
        container.backgroundColor = Self.appBackground
        container.isHidden = true
        let label = UILabel()
        label.text = "⚠️ تعذّر الاتصال بالموقع\nتحقق من اتصال الإنترنت ثم حاول مجددًا"
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = UIColor(red: 233/255, green: 237/255, blue: 244/255, alpha: 1)
        label.font = .systemFont(ofSize: 16, weight: .medium)
        let button = UIButton(type: .system)
        button.setTitle("إعادة المحاولة", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        button.setTitleColor(UIColor(red: 4/255, green: 18/255, blue: 46/255, alpha: 1), for: .normal)
        button.backgroundColor = Self.accent
        button.layer.cornerRadius = 10
        button.contentEdgeInsets = UIEdgeInsets(top: 10, left: 22, bottom: 10, right: 22)
        button.addTarget(self, action: #selector(retryLoad), for: .touchUpInside)
        let stack = UIStackView(arrangedSubviews: [label, button])
        stack.axis = .vertical
        stack.spacing = 18
        stack.alignment = .center
        container.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -24)
        ])
        view.addSubview(container)
        container.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: view.topAnchor),
            container.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        errorView = container
    }

    @objc private func retryLoad() {
        errorView.isHidden = true
        if webView.url == nil {
            webView.load(URLRequest(url: homeURL))
        } else {
            webView.reload()
        }
    }

    private func showError() {
        // Only cover the screen when there is nothing useful to show.
        if webView.url == nil { errorView.isHidden = false }
    }
}

// MARK: - Navigation policy
extension ViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.scrollView.refreshControl?.endRefreshing()
        errorView.isHidden = true
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        webView.scrollView.refreshControl?.endRefreshing()
        showError()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        webView.scrollView.refreshControl?.endRefreshing()
        showError()
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel); return
        }
        let scheme = url.scheme?.lowercased() ?? ""
        if scheme == "mailto" || scheme == "tel" || scheme == "sms" {
            UIApplication.shared.open(url)
            decisionHandler(.cancel); return
        }
        if scheme == "http" || scheme == "https" {
            if url.host != homeURL.host && navigationAction.navigationType == .linkActivated {
                UIApplication.shared.open(url)   // external link → Safari
                decisionHandler(.cancel); return
            }
            decisionHandler(.allow); return
        }
        decisionHandler(.cancel)
    }

    // Attachments / non-renderable responses become native downloads.
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        let disposition = (navigationResponse.response as? HTTPURLResponse)?
            .value(forHTTPHeaderField: "Content-Disposition")?.lowercased() ?? ""
        if disposition.contains("attachment") || !navigationResponse.canShowMIMEType {
            decisionHandler(.download)
        } else {
            decisionHandler(.allow)
        }
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = self
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = self
    }
}

// MARK: - Downloads → share sheet
extension ViewController: WKDownloadDelegate {
    func download(_ download: WKDownload,
                  decideDestinationUsing response: URLResponse,
                  suggestedFilename: String,
                  completionHandler: @escaping (URL?) -> Void) {
        let safe = suggestedFilename.replacingOccurrences(of: "/", with: "_")
        let dest = FileManager.default.temporaryDirectory.appendingPathComponent(safe)
        try? FileManager.default.removeItem(at: dest)
        downloadDestinations[ObjectIdentifier(download)] = dest
        completionHandler(dest)
    }

    func downloadDidFinish(_ download: WKDownload) {
        guard let file = downloadDestinations.removeValue(forKey: ObjectIdentifier(download)) else { return }
        let share = UIActivityViewController(activityItems: [file], applicationActivities: nil)
        share.popoverPresentationController?.sourceView = view
        present(share, animated: true)
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        downloadDestinations.removeValue(forKey: ObjectIdentifier(download))
    }
}

// MARK: - UI delegate (new-window links load in place / Safari policy above)
extension ViewController: WKUIDelegate {
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        // target=_blank: same-host loads in place; external hosts go to Safari
        // via the navigation policy on the next load — load here and let the
        // policy decide.
        if let url = navigationAction.request.url {
            if url.host == homeURL.host {
                webView.load(URLRequest(url: url))
            } else {
                UIApplication.shared.open(url)
            }
        }
        return nil
    }
}
