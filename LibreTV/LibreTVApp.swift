import SwiftUI
import WebKit

@main
struct LibreTVApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

final class WebViewStore: ObservableObject {
    let webView: WKWebView
    @Published var estimatedProgress: Double = 0
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var isLoading = false

    init() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        self.webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true
    }
}

struct WebView: UIViewRepresentable {
    @ObservedObject var store: WebViewStore
    let urlString: String

    func makeCoordinator() -> Coordinator { Coordinator(store: store) }

    func makeUIView(context: Context) -> WKWebView {
        let webView = store.webView
        webView.navigationDelegate = context.coordinator
        context.coordinator.startObserving(webView: webView)
        let refresh = UIRefreshControl()
        refresh.addTarget(context.coordinator, action: #selector(Coordinator.handleRefresh(_:)), for: .valueChanged)
        webView.scrollView.refreshControl = refresh
        if let url = URL(string: urlString) {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKNavigationDelegate {
        let store: WebViewStore
        private var progressObservation: NSKeyValueObservation?

        init(store: WebViewStore) { self.store = store }

        func startObserving(webView: WKWebView) {
            progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self] webView, _ in
                DispatchQueue.main.async {
                    self?.store.estimatedProgress = webView.estimatedProgress
                    self?.store.isLoading = webView.isLoading
                }
            }
        }

        @objc func handleRefresh(_ sender: UIRefreshControl) {
            store.webView.reload()
            sender.endRefreshing()
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            store.canGoBack = webView.canGoBack
            store.canGoForward = webView.canGoForward
            store.isLoading = false
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            store.canGoBack = webView.canGoBack
            store.canGoForward = webView.canGoForward
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            store.isLoading = false
        }
    }
}

struct ContentView: View {
    @AppStorage("serverURL") private var serverURL = ""
    @State private var showSettings = false

    var body: some View {
        if serverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            ServerAddressView(serverURL: $serverURL, isFirstSetup: true)
        } else {
            NavigationStack {
                BrowserView(serverURL: serverURL, showSettings: $showSettings)
            }
            .id(serverURL)
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    ServerAddressView(serverURL: $serverURL, isFirstSetup: false)
                }
            }
        }
    }
}

struct BrowserView: View {
    let serverURL: String
    @Binding var showSettings: Bool
    @StateObject private var store = WebViewStore()

    var body: some View {
        VStack(spacing: 0) {
            if store.isLoading {
                ProgressView(value: store.estimatedProgress)
                    .progressViewStyle(.linear)
            }
            WebView(store: store, urlString: serverURL)
        }
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button(action: { store.webView.goBack() }) {
                    Image(systemName: "chevron.left")
                }
                .disabled(!store.canGoBack)
                Button(action: { store.webView.goForward() }) {
                    Image(systemName: "chevron.right")
                }
                .disabled(!store.canGoForward)
                Spacer()
                Button(action: { store.webView.reload() }) {
                    Image(systemName: "arrow.clockwise")
                }
                Button(action: { showSettings = true }) {
                    Image(systemName: "gearshape")
                }
            }
        }
    }
}

struct ServerAddressView: View {
    @Binding var serverURL: String
    let isFirstSetup: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var draft = ""
    @State private var error = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("LibreTV")
                .font(.largeTitle.bold())
            Text(isFirstSetup ? "粘贴你的 LibreTV 服务器地址" : "修改服务器地址")
                .foregroundStyle(.secondary)
            TextField("https://…", text: $draft)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
            if !error.isEmpty {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
            Button(isFirstSetup ? "进入" : "保存") { save() }
                .buttonStyle(.borderedProminent)
            Text("就是小月发你的那个链接，带 _token 的那一串。地址存在本机，不会发给任何人。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
        .navigationTitle(isFirstSetup ? "" : "设置")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { draft = serverURL }
    }

    private func save() {
        var text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.hasPrefix("http://") && !text.hasPrefix("https://") {
            text = "https://" + text
        }
        guard let url = URL(string: text), url.host != nil else {
            error = "地址不对，检查一下"
            return
        }
        serverURL = text
        if !isFirstSetup {
            dismiss()
        }
    }
}
