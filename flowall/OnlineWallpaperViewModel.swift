import Foundation
import AppKit

// MARK: - 在线壁纸 ViewModel（API 版本）
@MainActor
class OnlineWallpaperViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var wallpapers: [OnlineWallpaper] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var thumbnails: [String: NSImage] = [:]  // 缩略图缓存(备用)
    @Published var currentPage = 0
    @Published var totalPages = 0
    @Published var downloadingIds: Set<String> = []  // 正在下载的壁纸 ID
    @Published var downloadProgress: [String: Double] = [:]  // 下载进度 ID -> 进度(0-1)

    // MARK: - Private Properties
    private let apiClient = OnlineWallpaperAPIClient.shared
    private var currentSearch: String = ""
    private var downloadQueue: [OnlineWallpaper] = []
    private var isDownloading = false

    // MARK: - 搜索(移除默认关键词)
    func performSearch(query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        print("🔍 开始搜索: '\(trimmedQuery)'")

        // 重置所有状态
        currentSearch = trimmedQuery
        currentPage = 0
        totalPages = 0
        wallpapers.removeAll()

        // 不在这里设置 isLoading,让 loadMore() 自己管理

        // 开始加载新搜索结果
        Task {
            await loadMore()
        }
    }

    // MARK: - 加载更多
    func loadMore() async {
        // 检查状态，避免重复加载
        guard !isLoading, currentPage < totalPages || currentPage == 0 else {
            print("⚠️ loadMore 被跳过: isLoading=\(isLoading), currentPage=\(currentPage), totalPages=\(totalPages)")
            return
        }

        print("📥 开始 loadMore, 当前壁纸数: \(wallpapers.count), 搜索词: '\(currentSearch)'")
        isLoading = true

        do {
            // 调用 API 获取数据
            let response = try await apiClient.fetchWallpapers(
                page: currentPage + 1,
                limit: 20,
                search: currentSearch.isEmpty ? nil : currentSearch
            )

            print("✅ API 响应成功: 返回 \(response.data.items.count) 项")

            // 追加新数据
            wallpapers.append(contentsOf: response.data.items)
            currentPage = response.data.pagination.page
            totalPages = response.data.pagination.totalPages

            print("✅ 加载完成, 新增: \(response.data.items.count), 总数: \(wallpapers.count), 页码: \(currentPage)/\(totalPages)")

        } catch {
            print("❌ loadMore 失败: \(error)")
            showError(error.localizedDescription)
        }

        isLoading = false
    }

    // MARK: - 缩略图加载（保留作为备用）
    func loadThumbnail(for wallpaper: OnlineWallpaper) {
        guard thumbnails[wallpaper.id] == nil, !isWallpaperDownloaded(wallpaper) else {
            return
        }

        Task {
            guard let url = URL(string: wallpaper.coverUrl) else { return }

            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = NSImage(data: data) {
                    thumbnails[wallpaper.id] = image
                }
            } catch {
                // 静默失败
            }
        }
    }

    // MARK: - 壁纸操作
    func handleWallpaperAction(_ wallpaper: OnlineWallpaper) {
        if isWallpaperDownloaded(wallpaper) {
            applyWallpaper(wallpaper)
        } else {
            addToDownloadQueue(wallpaper)
        }
    }

    // MARK: - 下载队列管理
    private func addToDownloadQueue(_ wallpaper: OnlineWallpaper) {
        guard !downloadQueue.contains(where: { $0.id == wallpaper.id }) else {
            return
        }

        downloadQueue.append(wallpaper)
        downloadingIds.insert(wallpaper.id)  // 标记为下载中

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
            downloadingIds.remove(wallpaper.id)  // 下载完成，移除标记
            isDownloading = false

            if !downloadQueue.isEmpty {
                processDownloadQueue()
            }
        }
    }

    private func downloadWallpaper(_ wallpaper: OnlineWallpaper) async {
        do {
            // 直接使用 API 返回的 videoUrl
            guard let url = URL(string: wallpaper.videoUrl) else {
                throw APIError.invalidURL
            }

            // 创建 URLSession 配置以追踪进度
            let session = URLSession(configuration: .default, delegate: nil, delegateQueue: nil)

            // 初始化进度
            downloadProgress[wallpaper.id] = 0.0

            // 使用异步下载并追踪进度
            let downloadTask = session.downloadTask(with: url) { [weak self] tempFileURL, response, error in
                guard let self = self else { return }

                Task { @MainActor in
                    do {
                        if let error = error {
                            throw error
                        }

                        guard let tempFileURL = tempFileURL else {
                            throw APIError.downloadFailed
                        }

                        let fileManager = FileManager.default
                        let wallpaperPath = VideoFileManager.getVideoDirectory()
                        let fileName = self.getFileName(for: wallpaper)
                        let destinationURL = wallpaperPath.appendingPathComponent("\(fileName).mp4")

                        if fileManager.fileExists(atPath: destinationURL.path) {
                            try fileManager.removeItem(at: destinationURL)
                        }

                        try fileManager.moveItem(at: tempFileURL, to: destinationURL)

                        // 下载成功,刷新本地壁纸列表
                        NotificationCenter.default.post(name: NSNotification.Name("RefreshLocalWallpapers"), object: nil)

                        // 清理进度
                        self.downloadProgress.removeValue(forKey: wallpaper.id)

                    } catch {
                        self.downloadProgress.removeValue(forKey: wallpaper.id)
                        self.showError("下载失败: \(error.localizedDescription)", duration: 3)
                    }
                }
            }

            // 监听下载进度
            let observation = downloadTask.progress.observe(\Progress.fractionCompleted, options: [.new]) { (progress: Progress, _) in
                Task { @MainActor in
                    self.downloadProgress[wallpaper.id] = progress.fractionCompleted
                }
            }

            downloadTask.resume()

            // 等待下载完成
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                DispatchQueue.global().async {
                    while downloadTask.state == URLSessionTask.State.running {
                        Thread.sleep(forTimeInterval: 0.1)
                    }
                    observation.invalidate()
                    continuation.resume()
                }
            }

        } catch {
            downloadProgress.removeValue(forKey: wallpaper.id)
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
        // 使用 API 返回的 id 作为文件名
        return wallpaper.id
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
