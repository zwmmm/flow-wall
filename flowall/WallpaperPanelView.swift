import AVFoundation
import AppKit
import SwiftUI
import WebKit

// MARK: - 下拉式壁纸选择面板窗口控制器

class WallpaperPanelController: NSObject {

    private var popover: NSPopover?
    private var eventMonitor: Any?

    func show(relativeTo button: NSStatusBarButton) {
        if popover == nil {
            popover = NSPopover()
            popover?.contentSize = NSSize(
                width: AppConstants.UI.panelWidth, height: AppConstants.UI.panelHeight)
            popover?.behavior = .transient
            popover?.animates = true
            popover?.contentViewController = NSHostingController(
                rootView: WallpaperPanelView {
                    self.close()
                })
        }

        if let popover = popover {
            if popover.isShown {
                close()
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)

                eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [
                    .leftMouseDown, .rightMouseDown,
                ]) { [weak self] event in
                    if self?.popover?.isShown == true {
                        self?.close()
                    }
                }
            }
        }
    }

    func close() {
        popover?.performClose(nil)
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}

// MARK: - 主面板视图

struct WallpaperPanelView: View {

    @State private var selectedTab = 1  // 默认展示在线壁纸库
    @State private var localWallpapers: [URL] = []
    @State private var thumbnails: [String: NSImage] = [:]
    @State private var isLoading = false
    @State private var hoveredID: String?
    @State private var visibleWallpapers: Set<String> = []

    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // 顶部栏 - 极简
            topBar

            // Tab栏 - 横向居中
            tabBar

            // 内容区 - 单列垂直滚动
            contentArea
        }
        .background(Color(NSColor.controlBackgroundColor))
        .onAppear {
            loadLocalWallpapers()
        }
    }

    // MARK: - 顶部栏

    private var topBar: some View {
        HStack {
            Text("Flowall")
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.95))

            Spacer()

            HStack(spacing: 14) {
                // 刷新按钮
                Button(action: refreshLocalWallpapers) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("刷新本地视频")

                // 设置按钮
                Button(action: openSettings) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 15))
                        .foregroundColor(.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("设置")
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 18)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Tab栏

    private var tabBar: some View {
        HStack(spacing: 0) {
            Spacer()

            TabButton(title: "本地", isSelected: selectedTab == 0) {
                selectedTab = 0
            }

            Spacer().frame(width: 40)

            TabButton(title: "壁纸库", isSelected: selectedTab == 1) {
                selectedTab = 1
            }

            Spacer()
        }
        .padding(.vertical, 12)
        .padding(.bottom, 0)
    }

    // MARK: - 内容区

    private var contentArea: some View {
        ZStack {
            // 本地壁纸Tab - 始终存在，只控制显示/隐藏
            LocalWallpaperListView(onClose: onClose)
                .opacity(selectedTab == 0 ? 1 : 0)
                .zIndex(selectedTab == 0 ? 1 : 0)

            // 在线壁纸Tab - 始终存在，只控制显示/隐藏
            OnlineWallpaperListView()
                .opacity(selectedTab == 1 ? 1 : 0)
                .zIndex(selectedTab == 1 ? 1 : 0)
        }
    }

    private var loadingView: some View {
        VStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white.opacity(0.5)))
            Text("加载中")
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.5))
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.stack")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.3))

            Text("还没有壁纸")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))

            Button("添加壁纸") {
                importWallpapers()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 单列垂直列表

    private var singleColumnList: some View {
        ScrollView {
            LazyVStack(spacing: AppConstants.UI.cardSpacing) {
                ForEach(localWallpapers, id: \.path) { wallpaper in
                    VideoCard(
                        wallpaper: wallpaper,
                        thumbnail: thumbnails[wallpaper.path],
                        isHovered: hoveredID == wallpaper.path,
                        isVisible: visibleWallpapers.contains(wallpaper.path),
                        onHover: { isHovering in
                            hoveredID = isHovering ? wallpaper.path : nil
                        },
                        onVisibilityChange: { isVisible in
                            if isVisible {
                                visibleWallpapers.insert(wallpaper.path)
                            } else {
                                visibleWallpapers.remove(wallpaper.path)
                            }
                        },
                        onSelect: {
                            applyWallpaper(wallpaper)
                        }
                    )
                    .id(wallpaper.path)
                }
            }
            .padding(.horizontal, AppConstants.UI.cardPadding)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Actions

    private func refreshLocalWallpapers() {
        // 发送通知给 LocalWallpaperListView 刷新
        NotificationCenter.default.post(name: NSNotification.Name("RefreshLocalWallpapers"), object: nil)
    }

    private func loadLocalWallpapers() {
        isLoading = true

        DispatchQueue.global(qos: .userInitiated).async {
            let videos = VideoFileManager.loadVideoFiles()
            var newThumbnails: [String: NSImage] = [:]

            for video in videos {
                if let thumbnail = VideoFileManager.generateThumbnail(for: video) {
                    newThumbnails[video.path] = thumbnail
                }
            }

            DispatchQueue.main.async {
                self.localWallpapers = videos
                self.thumbnails = newThumbnails
                self.isLoading = false
            }
        }
    }

    private func importWallpapers() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.movie, .quickTimeMovie, .mpeg4Movie]
        panel.message = "选择要导入的视频文件"

        if panel.runModal() == .OK {
            let destinationDir = VideoFileManager.getVideoDirectory()

            for sourceURL in panel.urls {
                let destinationURL = destinationDir.appendingPathComponent(
                    sourceURL.lastPathComponent)

                do {
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                    try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
                } catch {
                    print("导入文件失败: \(error)")
                }
            }

            loadLocalWallpapers()
        }
    }

    private func applyWallpaper(_ wallpaper: URL) {
        print("🟢 applyWallpaper 被调用")
        print("🟢 壁纸路径: \(wallpaper.path)")

        // 使用通知机制传递壁纸路径
        NotificationCenter.default.post(
            name: NSNotification.Name("ApplyWallpaper"),
            object: nil,
            userInfo: ["path": wallpaper.path]
        )

        onClose()
    }

    private func openSettings() {
        NotificationCenter.default.post(
            name: NSNotification.Name(AppConstants.NotificationName.openSettings), object: nil)
    }
}

// MARK: - Tab按钮

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : .white.opacity(0.5))

                Rectangle()
                    .fill(isSelected ? Color.white : Color.clear)
                    .frame(height: 2.5)
                    .frame(width: isSelected ? 32 : 0)
                    .cornerRadius(1.25)
            }
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - 视频卡片 - 单列全宽

struct VideoCard: View {
    let wallpaper: URL
    let thumbnail: NSImage?
    let isHovered: Bool
    let isVisible: Bool
    let onHover: (Bool) -> Void
    let onVisibilityChange: (Bool) -> Void
    let onSelect: () -> Void

    // 计算高度,保持原始宽高比
    private var cardHeight: CGFloat {
        guard let thumbnail = thumbnail else { return 180 }
        let imageSize = thumbnail.size
        let aspectRatio = imageSize.height / imageSize.width
        let cardWidth: CGFloat = AppConstants.UI.panelWidth - AppConstants.UI.cardPadding * 2
        return cardWidth * aspectRatio
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomLeading) {
                // 视频播放器或缩略图
                if isVisible {
                    VideoAutoPlayer(url: wallpaper)
                        .frame(height: cardHeight)
                        .cornerRadius(8)
                } else if let thumbnail = thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: cardHeight)
                        .clipped()
                        .cornerRadius(8)
                } else {
                    Rectangle()
                        .fill(Color.white.opacity(0.05))
                        .frame(height: 180)
                        .cornerRadius(8)
                        .overlay(
                            ProgressView()
                                .progressViewStyle(
                                    CircularProgressViewStyle(tint: .white.opacity(0.3)))
                        )
                }

                // 悬停遮罩
                if isHovered {
                    ZStack {
                        Rectangle()
                            .fill(Color.black.opacity(0.3))
                            .cornerRadius(8)

                        VStack(spacing: 4) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.white.opacity(0.9))

                            Text("点击应用")
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }
            }
            .frame(height: cardHeight)
            .shadow(
                color: Color.black.opacity(0.3),
                radius: isHovered ? 16 : 8,
                y: isHovered ? 6 : 3
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.easeOut(duration: 0.15), value: isHovered)
            .onTapGesture {
                print("🔵 VideoCard 点击事件触发")
                print("🔵 壁纸路径: \(wallpaper.path)")
                onSelect()
            }
            .onHover { hovering in
                onHover(hovering)
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
            .onAppear {
                checkVisibility(geometry: geometry)
            }
            .onChange(of: geometry.frame(in: .global)) { _, _ in
                checkVisibility(geometry: geometry)
            }
        }
        .frame(height: cardHeight)
    }

    private func checkVisibility(geometry: GeometryProxy) {
        let frame = geometry.frame(in: .global)
        let screenHeight = AppConstants.UI.panelHeight
        let isCurrentlyVisible = frame.minY < screenHeight && frame.maxY > 0
        onVisibilityChange(isCurrentlyVisible)
    }
}

// MARK: - 视频自动播放器

struct VideoAutoPlayer: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> VideoAutoPlayView {
        let view = VideoAutoPlayView()
        view.setupPlayer(with: url)
        return view
    }

    func updateNSView(_ nsView: VideoAutoPlayView, context: Context) {}

    static func dismantleNSView(_ nsView: VideoAutoPlayView, coordinator: ()) {
        nsView.cleanup()
    }
}

class VideoAutoPlayView: NSView {
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.wantsLayer = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setupPlayer(with url: URL) {
        let playerItem = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: playerItem)
        player?.volume = 0.0
        player?.isMuted = true

        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.frame = bounds
        playerLayer?.videoGravity = .resizeAspectFill

        if let layer = self.layer {
            layer.addSublayer(playerLayer!)
        }

        // 循环播放
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            self?.player?.seek(to: .zero)
            self?.player?.play()
        }

        player?.play()
    }

    override func layout() {
        super.layout()
        playerLayer?.frame = bounds
    }

    func cleanup() {
        player?.pause()
        playerLayer?.removeFromSuperlayer()
        player = nil
        playerLayer = nil
        NotificationCenter.default.removeObserver(self)
    }

    deinit {
        cleanup()
    }
}

// MARK: - WebM 视频播放器 (支持 webm 格式)

struct WebMVideoPlayer: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let webView = WKWebView(frame: .zero, configuration: configuration)

        // 创建 HTML 页面嵌入视频
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                * { margin: 0; padding: 0; overflow: hidden; }
                body { background: #000; }
                video {
                    width: 100vw;
                    height: 100vh;
                    object-fit: cover;
                }
            </style>
        </head>
        <body>
            <video autoplay loop muted playsinline>
                <source src="\(url.absoluteString)" type="video/webm">
                <source src="\(url.absoluteString)" type="video/mp4">
            </video>
        </body>
        </html>
        """

        webView.loadHTMLString(html, baseURL: nil)
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}
}

// MARK: - Preview

#Preview {
    WallpaperPanelView {
        print("Close")
    }
    .frame(width: 280, height: 620)
}
