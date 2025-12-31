import Foundation
import AppKit

// MARK: - 在线壁纸 ViewModel
@MainActor
class OnlineWallpaperViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var wallpapers: [OnlineWallpaper] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var thumbnails: [String: NSImage] = [:]
    @Published var previewURLs: [String: String] = [:]  // 懒加载的预览URL缓存
    @Published var hasMorePages: Bool = true  // 是否还有更多页面

    // MARK: - Private Properties
    private let manager = OnlineWallpaperManager.shared
    private let database = WallpaperDatabase.shared
    private var hasLoadedDefault = false
    private var downloadQueue: [OnlineWallpaper] = []
    private var isDownloading = false

    // MARK: - Initialization
    func loadDefaultWallpapers() {
        guard !hasLoadedDefault else { return }
        hasLoadedDefault = true

        let defaultQuery = "School Girl"

        // 先从数据库加载缓存
        let cached = database.getWallpapers(query: defaultQuery, limit: 10)
        if !cached.isEmpty {
            wallpapers = cached
            return
        }

        // 从网络加载
        manager.updateSearchQuery(defaultQuery)
        manager.reset()
        Task {
            await loadMore()
        }
    }

    // MARK: - Search
    func performSearch(query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let actualQuery = trimmedQuery.isEmpty ? "School Girl" : trimmedQuery

        // 重置所有状态
        manager.updateSearchQuery(actualQuery)
        manager.reset()

        // 同步重置 ViewModel 状态
        wallpapers.removeAll()
        hasMorePages = true
        isLoading = false

        // 开始加载新搜索结果
        Task {
            await loadMore()
        }
    }

    // MARK: - Load More
    func loadMore() async {
        // 检查状态,避免重复加载
        guard !isLoading, hasMorePages else {
            print("⚠️ loadMore 被跳过: isLoading=\(isLoading), hasMorePages=\(hasMorePages)")
            return
        }

        print("📥 开始 loadMore, 当前壁纸数: \(wallpapers.count)")
        isLoading = true

        do {
            // Manager 返回本次新加载的数据
            let newWallpapers = try await manager.loadNextPage()

            print("✅ loadNextPage 完成, 新增壁纸数: \(newWallpapers.count)")

            if !newWallpapers.isEmpty {
                // 追加新数据到 ViewModel
                wallpapers.append(contentsOf: newWallpapers)
                hasMorePages = manager.hasMorePages

                print("✅ 追加完成, 总壁纸数: \(wallpapers.count), hasMorePages: \(hasMorePages)")

                // 保存到数据库
                database.saveWallpapers(wallpapers, query: manager.searchQuery)
            } else {
                // 没有新数据
                hasMorePages = false
                print("⚠️ 没有新增数据, 标记为无更多页")
            }
        } catch {
            print("❌ loadMore 失败: \(error)")
            showError(error.localizedDescription)
        }

        isLoading = false
    }

    // MARK: - Hover Preview (懒加载预览URL)
    func loadPreviewOnHover(for wallpaper: OnlineWallpaper) {
        // 如果已下载或已有预览URL，直接返回
        if isWallpaperDownloaded(wallpaper) || previewURLs[wallpaper.url] != nil {
            return
        }

        Task {
            if let previewURL = await manager.fetchPreviewVideoURL(from: wallpaper.url) {
                previewURLs[wallpaper.url] = previewURL
            }
        }
    }

    // MARK: - Thumbnail Loading
    func loadThumbnail(for wallpaper: OnlineWallpaper) {
        guard thumbnails[wallpaper.url] == nil, !isWallpaperDownloaded(wallpaper) else {
            return
        }

        Task {
            guard let url = URL(string: wallpaper.thumbnail) else { return }

            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = NSImage(data: data) {
                    thumbnails[wallpaper.url] = image
                }
            } catch {
                // 静默失败
            }
        }
    }

    // MARK: - Wallpaper Actions
    func handleWallpaperAction(_ wallpaper: OnlineWallpaper) {
        if isWallpaperDownloaded(wallpaper) {
            applyWallpaper(wallpaper)
        } else {
            addToDownloadQueue(wallpaper)
        }
    }

    // MARK: - Download Management
    private func addToDownloadQueue(_ wallpaper: OnlineWallpaper) {
        guard !downloadQueue.contains(where: { $0.url == wallpaper.url }) else {
            showError("已在下载队列中", duration: 2)
            return
        }

        downloadQueue.append(wallpaper)
        showError("已添加到下载队列 (\(downloadQueue.count))", duration: 2)

        if !isDownloading {
            processDownloadQueue()
        }
    }

    private func processDownloadQueue() {
        guard !downloadQueue.isEmpty, !isDownloading else { return }

        isDownloading = true
        let wallpaper = downloadQueue.removeFirst()

        Task {
            await downloadWallpaper(wallpaper)
            isDownloading = false

            if !downloadQueue.isEmpty {
                processDownloadQueue()
            }
        }
    }

    private func downloadWallpaper(_ wallpaper: OnlineWallpaper) async {
        do {
            errorMessage = "正在获取下载链接... (剩余: \(downloadQueue.count))"
            let downloadURLString = try await manager.getDownloadURL(for: wallpaper)

            guard let url = URL(string: downloadURLString) else {
                throw WallpaperError.downloadURLNotFound
            }

            errorMessage = "正在下载 \(wallpaper.title)... (剩余: \(downloadQueue.count))"
            let (tempFileURL, _) = try await URLSession.shared.download(from: url)

            let fileManager = FileManager.default
            let wallpaperPath = VideoFileManager.getVideoDirectory()
            let fileName = getFileName(for: wallpaper)
            let destinationURL = wallpaperPath.appendingPathComponent("\(fileName).mp4")

            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }

            try fileManager.moveItem(at: tempFileURL, to: destinationURL)

            showError("下载成功 ✓ (剩余: \(downloadQueue.count))", duration: 2)

            // 刷新本地壁纸列表
            NotificationCenter.default.post(name: NSNotification.Name("RefreshLocalWallpapers"), object: nil)

        } catch {
            showError("下载失败: \(error.localizedDescription)", duration: 3)
        }
    }

    // MARK: - Helper Methods
    func isWallpaperDownloaded(_ wallpaper: OnlineWallpaper) -> Bool {
        let fileName = getFileName(for: wallpaper)
        let fileURL = VideoFileManager.getVideoDirectory().appendingPathComponent("\(fileName).mp4")
        return FileManager.default.fileExists(atPath: fileURL.path)
    }

    func getLocalVideoURL(for wallpaper: OnlineWallpaper) -> URL? {
        guard isWallpaperDownloaded(wallpaper) else { return nil }
        let fileName = getFileName(for: wallpaper)
        return VideoFileManager.getVideoDirectory().appendingPathComponent("\(fileName).mp4")
    }

    private func getFileName(for wallpaper: OnlineWallpaper) -> String {
        let fileName = wallpaper.url.split(separator: "/").last.map(String.init) ?? wallpaper.id
        return fileName.replacingOccurrences(of: "[^a-zA-Z0-9-]", with: "_", options: .regularExpression)
    }

    private func applyWallpaper(_ wallpaper: OnlineWallpaper) {
        let fileName = getFileName(for: wallpaper)
        let fileURL = VideoFileManager.getVideoDirectory().appendingPathComponent("\(fileName).mp4")

        NotificationCenter.default.post(
            name: NSNotification.Name("ApplyWallpaper"),
            object: nil,
            userInfo: ["path": fileURL.path]
        )
    }

    private func showError(_ message: String, duration: TimeInterval = 3) {
        errorMessage = message
        Task {
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            if errorMessage == message {
                errorMessage = nil
            }
        }
    }
}
