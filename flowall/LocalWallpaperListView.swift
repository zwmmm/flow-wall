import SwiftUI
import AppKit
import AVFoundation

// MARK: - 本地壁纸卡片组件
struct LocalWallpaperCard: View {
    let videoURL: URL
    let thumbnail: NSImage?
    let onPreview: () -> Void
    let onApply: () -> Void

    @State private var isHovered = false

    // 计算高度,保持原视频宽高比
    private var cardHeight: CGFloat {
        guard let thumbnail = thumbnail else { return 140 }
        let imageSize = thumbnail.size
        let aspectRatio = imageSize.height / imageSize.width
        let cardWidth: CGFloat = 280 - 15 * 2
        return cardWidth * aspectRatio
    }

    var body: some View {
        ZStack(alignment: .center) {
            // 缩略图
            if let thumbnail = thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 250, height: cardHeight)
                    .clipped()
            } else {
                Color.gray.opacity(0.2)
                    .frame(height: 140)
            }

            // 悬停遮罩
            if isHovered {
                ZStack {
                    Color.black.opacity(0.4)

                    HStack(spacing: 30) {
                        // 预览按钮
                        Button(action: onPreview) {
                            VStack(spacing: 4) {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(.white)
                                Text("预览")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                        }
                        .buttonStyle(.plain)

                        // 应用按钮
                        Button(action: onApply) {
                            VStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(.white)
                                Text("应用")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.9))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(height: cardHeight)
        .cornerRadius(8)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - 本地壁纸列表视图
struct LocalWallpaperListView: View {
    @State private var localWallpapers: [URL] = []
    @State private var thumbnails: [String: NSImage] = [:]
    @State private var isLoading = false
    @State private var isInitialLoad = true

    var onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // 壁纸列表
            if isLoading && isInitialLoad {
                loadingView
            } else if localWallpapers.isEmpty && !isLoading {
                emptyView
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(localWallpapers, id: \.path) { wallpaper in
                            LocalWallpaperCard(
                                videoURL: wallpaper,
                                thumbnail: thumbnails[wallpaper.path],
                                onPreview: {
                                    openPreviewWindow(for: wallpaper)
                                },
                                onApply: {
                                    applyWallpaper(wallpaper)
                                }
                            )
                            .id(wallpaper.path)
                        }
                    }
                    .padding(.horizontal, 15)
                    .padding(.vertical, 10)
                }
                .hideScrollIndicators()
            }
        }
        .onAppear {
            loadLocalWallpapers(isRefresh: false)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshLocalWallpapers"))) { _ in
            loadLocalWallpapers(isRefresh: true)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)

            Text("加载中...")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.stack")
                .font(.system(size: 36))
                .foregroundColor(.secondary)

            Text("还没有壁纸")
                .font(.system(size: 13))
                .foregroundColor(.secondary)

            Button("添加壁纸") {
                importWallpapers()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadLocalWallpapers(isRefresh: Bool = false) {
        // 刷新时不显示 loading 状态,避免闪烁
        if !isRefresh {
            isLoading = true
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let videos = VideoFileManager.loadVideoFiles()
            var newThumbnails: [String: NSImage] = [:]

            for video in videos {
                // 如果是刷新且缩略图已存在,跳过重新生成
                if isRefresh && self.thumbnails[video.path] != nil {
                    newThumbnails[video.path] = self.thumbnails[video.path]
                } else if let thumbnail = VideoFileManager.generateThumbnail(for: video) {
                    newThumbnails[video.path] = thumbnail
                }
            }

            DispatchQueue.main.async {
                self.localWallpapers = videos
                self.thumbnails = newThumbnails
                self.isLoading = false
                self.isInitialLoad = false
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
                let destinationURL = destinationDir.appendingPathComponent(sourceURL.lastPathComponent)

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
        NotificationCenter.default.post(
            name: NSNotification.Name("ApplyWallpaper"),
            object: nil,
            userInfo: ["path": wallpaper.path]
        )
        onClose()
    }

    private func openPreviewWindow(for wallpaper: URL) {
        NotificationCenter.default.post(
            name: NSNotification.Name("PreviewLocalWallpaper"),
            object: nil,
            userInfo: ["url": wallpaper.absoluteString]
        )
    }
}
