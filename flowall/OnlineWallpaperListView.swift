import AVFoundation
import AppKit
import SwiftUI
import WebKit

// MARK: - 隐藏滚动条的 ViewModifier
struct HiddenScrollViewModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear {
                DispatchQueue.main.async {
                    hideScrollbars(in: NSApp.windows)
                }
            }
    }

    private func hideScrollbars(in windows: [NSWindow]) {
        for window in windows {
            hideScrollbars(in: window.contentView)
        }
    }

    private func hideScrollbars(in view: NSView?) {
        guard let view = view else { return }

        if let scrollView = view as? NSScrollView {
            scrollView.scrollerStyle = .overlay
            scrollView.hasVerticalScroller = false
            scrollView.hasHorizontalScroller = false
            scrollView.verticalScroller?.alphaValue = 0
            scrollView.horizontalScroller?.alphaValue = 0
        }

        for subview in view.subviews {
            hideScrollbars(in: subview)
        }
    }
}

extension View {
    func hideScrollIndicators() -> some View {
        self.modifier(HiddenScrollViewModifier())
    }
}

// MARK: - 优化的壁纸卡片（虚拟列表核心）
struct OptimizedWallpaperCard: View {
    let wallpaper: OnlineWallpaper
    let isDownloaded: Bool
    let isDownloading: Bool  // 新增：是否正在下载
    let thumbnail: NSImage?
    let onAction: () -> Void

    @State private var isHovered = false
    @State private var isInViewport = false
    @State private var shouldPlayVideo = false
    @StateObject private var playerPool = VideoPlayerPool.shared

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .center) {
                // 永远使用在线预览视频
                if shouldPlayVideo {
                    WebMVideoPlayer(url: URL(string: wallpaper.previewUrl)!)
                } else if let thumbnail = thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    Color.gray.opacity(0.2)
                }

                // Hover 遮罩
                if isHovered {
                    ZStack {
                        Color.black.opacity(0.3)
                        Button(action: onAction) {
                            if isDownloading {
                                // 下载中：显示 loading
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(1.5)
                            } else if isDownloaded {
                                // 已下载：显示播放图标
                                Image(systemName: "play.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white)
                            } else {
                                // 未下载：显示下载图标
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white)
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(isDownloading)  // 下载中禁用按钮
                    }
                }
            }
            .frame(height: 140)
            .clipped()
            .cornerRadius(8)
            .onAppear {
                updateViewportStatus(geometry: geometry)
            }
            .onDisappear {
                if shouldPlayVideo {
                    playerPool.deactivatePlayer()
                    shouldPlayVideo = false
                }
                isInViewport = false
            }
            .onChange(of: geometry.frame(in: .global)) { _, _ in
                updateViewportStatus(geometry: geometry)
            }
            .onHover { hovering in
                isHovered = hovering
            }
            .onTapGesture {
                onAction()
            }
        }
        .frame(height: 140)
    }

    // 可视区域检测 + 播放器池管理
    private func updateViewportStatus(geometry: GeometryProxy) {
        let frame = geometry.frame(in: .global)
        let panelHeight: CGFloat = 620
        let buffer: CGFloat = 150  // 预加载缓冲区

        let isVisible = frame.minY < panelHeight + buffer && frame.maxY > -buffer

        if isVisible != isInViewport {
            isInViewport = isVisible

            if isVisible {
                // 进入可视区域：延迟启动视频
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    if isInViewport && playerPool.canActivatePlayer() {
                        playerPool.activatePlayer()
                        shouldPlayVideo = true
                    }
                }
            } else {
                // 离开可视区域：立即停止视频
                if shouldPlayVideo {
                    playerPool.deactivatePlayer()
                    shouldPlayVideo = false
                }
            }
        }
    }
}

// MARK: - 壁纸库列表视图
struct OnlineWallpaperListView: View {
    @StateObject private var viewModel = OnlineWallpaperViewModel()
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            // 搜索框
            searchBar

            // 壁纸列表或空状态
            if viewModel.wallpapers.isEmpty && !viewModel.isLoading {
                emptyStateView
            } else {
                wallpaperList
            }
        }
        .overlay(alignment: .bottom) {
            errorOverlay
        }
        // 移除 onAppear 的 loadDefaultWallpapers()
    }

    // MARK: - 搜索框
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 12))

            TextField("搜索壁纸...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .onSubmit {
                    viewModel.performSearch(query: searchText)
                }

            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                    viewModel.performSearch(query: "")
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
            } else if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.5)
                    .frame(width: 12, height: 12)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
        .padding(.horizontal, 15)
        .padding(.top, 10)
        .padding(.bottom, 8)
    }

    // MARK: - 壁纸列表
    private var wallpaperList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(viewModel.wallpapers) { wallpaper in
                    OptimizedWallpaperCard(
                        wallpaper: wallpaper,
                        isDownloaded: viewModel.isWallpaperDownloaded(wallpaper),
                        isDownloading: viewModel.downloadingIds.contains(wallpaper.id),
                        thumbnail: viewModel.thumbnails[wallpaper.id],
                        onAction: {
                            viewModel.handleWallpaperAction(wallpaper)
                        }
                    )
                    .onAppear {
                        // 加载缩略图（备用）
                        viewModel.loadThumbnail(for: wallpaper)

                        // 触底加载
                        if wallpaper.id == viewModel.wallpapers.suffix(3).first?.id {
                            Task {
                                await viewModel.loadMore()
                            }
                        }
                    }
                }

                // 加载指示器
                if viewModel.isLoading && !viewModel.wallpapers.isEmpty {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.7)
                        Text("加载更多...")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 15)
                }

                // 没有更多数据
                if viewModel.currentPage >= viewModel.totalPages && !viewModel.wallpapers.isEmpty {
                    Text("已加载全部")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 15)
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 10)
        }
        .hideScrollIndicators()
    }

    // MARK: - 空状态视图
    private var emptyStateView: some View {
        VStack(spacing: 15) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 48, weight: .thin))
                .foregroundColor(.secondary.opacity(0.6))

            VStack(spacing: 6) {
                Text("在线壁纸库")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)

                Text("输入关键词搜索精选壁纸")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 错误提示
    private var errorOverlay: some View {
        Group {
            if let errorMessage = viewModel.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: getMessageIcon(for: errorMessage))
                        .font(.system(size: 12))
                    Text(errorMessage)
                        .font(.system(size: 11))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(getMessageBackground(for: errorMessage))
                .cornerRadius(8)
                .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
                .padding(.bottom, 15)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - Helper Methods
    private func getMessageIcon(for message: String) -> String {
        if message.contains("成功") {
            return "checkmark.circle.fill"
        } else if message.contains("下载") || message.contains("获取") {
            return "arrow.down.circle.fill"
        } else {
            return "exclamationmark.circle.fill"
        }
    }

    private func getMessageBackground(for message: String) -> Color {
        if message.contains("成功") {
            return Color.green.opacity(0.9)
        } else if message.contains("下载") || message.contains("获取") {
            return Color.blue.opacity(0.9)
        } else {
            return Color.red.opacity(0.9)
        }
    }
}

#Preview {
    OnlineWallpaperListView()
        .frame(width: 280, height: 620)
}
