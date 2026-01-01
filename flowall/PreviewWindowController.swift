import Cocoa
import SwiftUI
import WebKit

// MARK: - 视频预览窗口控制器
class VideoPreviewWindowController: NSWindowController {

    convenience init(videoURL: URL, title: String = "预览") {
        // 默认窗口尺寸 16:9,但允许调整
        let windowWidth: CGFloat = 960
        let windowHeight: CGFloat = 540

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: windowHeight),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.center()
        window.level = .floating
        window.isMovableByWindowBackground = true
        window.minSize = NSSize(width: 480, height: 270)

        self.init(window: window)

        let previewView = VideoPreviewView(videoURL: videoURL)
        let hostingController = NSHostingController(rootView: previewView)
        window.contentViewController = hostingController
    }

    override init(window: NSWindow?) {
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}

// MARK: - 视频预览视图
struct VideoPreviewView: View {
    let videoURL: URL

    var body: some View {
        WebVideoPlayer(url: videoURL)
            .background(Color.black)
    }
}

// MARK: - WKWebView 视频播放器
struct WebVideoPlayer: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator

        // 加载 HTML 播放器
        let htmlContent = createVideoHTML(for: url)
        webView.loadHTMLString(htmlContent, baseURL: nil)

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    private func createVideoHTML(for url: URL) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                * {
                    margin: 0;
                    padding: 0;
                    box-sizing: border-box;
                }
                body {
                    width: 100vw;
                    height: 100vh;
                    background: #000;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    overflow: hidden;
                }
                video {
                    width: 100%;
                    height: 100%;
                    object-fit: contain;
                }
            </style>
        </head>
        <body>
            <video autoplay loop muted playsinline>
                <source src="\(url.absoluteString)" type="video/webm">
                <source src="\(url.absoluteString)" type="video/mp4">
                Your browser does not support the video tag.
            </video>
        </body>
        </html>
        """
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("[WebView] 页面加载完成")
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("[WebView] 加载失败: \(error.localizedDescription)")
        }
    }
}

