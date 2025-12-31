import Foundation

// MARK: - 在线壁纸数据模型
struct OnlineWallpaper: Identifiable, Equatable {
    let title: String
    let url: String
    let thumbnail: String
    var videoURL: String?
    var previewVideoURL: String?  // webm 预览视频地址

    // Identifiable协议要求
    var id: String { url }

    static func == (lhs: OnlineWallpaper, rhs: OnlineWallpaper) -> Bool {
        lhs.url == rhs.url
    }

    // 从标题提取分辨率信息
    var resolution: String {
        let pattern = "(\\d{3,4})x(\\d{3,4})"
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: title, range: NSRange(title.startIndex..., in: title)) {
            return (title as NSString).substring(with: match.range)
        }
        return "1920x1080"
    }

    // 从URL提取分类信息
    var category: String {
        let components = url.split(separator: "/")
        if components.count > 3 {
            let category = String(components[3])
            return category.prefix(1).uppercased() + category.dropFirst()
        }
        return "Wallpaper"
    }
}

// MARK: - 在线壁纸管理器
@MainActor
class OnlineWallpaperManager: ObservableObject {
    static let shared = OnlineWallpaperManager()

    @Published var wallpapers: [OnlineWallpaper] = []
    @Published var isLoading = false
    @Published var hasMorePages = true

    private var currentPage = 0
    private let baseURL = "https://moewalls.com"
    var searchQuery = ""  // 默认搜索为空(内部使用)

    private init() {}

    // MARK: - 更新搜索关键词
    func updateSearchQuery(_ query: String) {
        searchQuery = query
    }

    // MARK: - 加载下一页
    func loadNextPage() async throws -> [OnlineWallpaper] {
        // 检查是否还有更多页面
        guard hasMorePages else { return [] }

        // 避免重复加载
        guard !isLoading else { return [] }

        isLoading = true
        defer { isLoading = false }

        // 页码从1开始
        currentPage += 1

        // URL 编码搜索关键词
        let encodedQuery = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? searchQuery

        // 构建搜索URL: https://moewalls.com/page/{page}/?s={search_term}
        let pageURL = "\(baseURL)/page/\(currentPage)/?s=\(encodedQuery)"

        guard let url = URL(string: pageURL) else {
            throw WallpaperError.invalidURL
        }

        // 配置请求
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        request.timeoutInterval = 30

        // 发起网络请求
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw WallpaperError.networkError
        }

        // 解析HTML
        guard let html = String(data: data, encoding: .utf8) else {
            throw WallpaperError.parseError("无法解码HTML")
        }

        // 从HTML中提取壁纸列表
        let parsedWallpapers = parseWallpapers(from: html)

        // 更新状态
        if parsedWallpapers.isEmpty {
            // 没有更多数据了
            hasMorePages = false
            currentPage -= 1  // 回退页码,因为这一页是空的
        } else {
            // 追加到内部缓存(用于兼容性)
            self.wallpapers.append(contentsOf: parsedWallpapers)
        }

        // 返回本次加载的新数据
        return parsedWallpapers
    }

    // MARK: - 解析HTML提取壁纸列表
    private func parseWallpapers(from html: String) -> [OnlineWallpaper] {
        var wallpapers: [OnlineWallpaper] = []

        // 匹配 li.g1-collection-item 元素
        let liPattern = #"<li[^>]*class="[^"]*g1-collection-item[^"]*"[^>]*>(.*?)</li>"#
        guard let liRegex = try? NSRegularExpression(pattern: liPattern, options: [.dotMatchesLineSeparators]) else {
            return []
        }

        let nsString = html as NSString
        let matches = liRegex.matches(in: html, range: NSRange(location: 0, length: nsString.length))

        for match in matches {
            guard match.numberOfRanges >= 2 else { continue }

            let liContent = nsString.substring(with: match.range(at: 1))

            // 跳过广告
            if liContent.contains("g1-advertisement") {
                continue
            }

            // 提取标题和URL: <h3 class="...entry-title..."><a href="...">Title</a></h3>
            let titlePattern = #"<h3[^>]*entry-title[^>]*>.*?<a[^>]+href="([^"]+)"[^>]*>([^<]+)</a>"#
            guard let titleMatch = extractFirstMatch(from: liContent, pattern: titlePattern, groups: 2) else {
                continue
            }

            let url = titleMatch[0]
            let title = titleMatch[1]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&#8211;", with: "-")

            // 提取缩略图: <a class="g1-frame"><img src="..."></a>
            let thumbnailPattern = #"<a[^>]*class="[^"]*g1-frame[^"]*"[^>]*>.*?<img[^>]+src="([^"]+)"[^>]*>"#
            guard let thumbnailMatch = extractFirstMatch(from: liContent, pattern: thumbnailPattern, groups: 1) else {
                continue
            }

            let thumbnail = thumbnailMatch[0]

            // 创建壁纸对象(视频URL稍后异步获取)
            let wallpaper = OnlineWallpaper(
                title: title,
                url: url,
                thumbnail: thumbnail,
                videoURL: nil
            )

            wallpapers.append(wallpaper)
        }

        return wallpapers
    }

    // MARK: - 获取单个壁纸的预览视频URL (公开方法供ViewModel懒加载使用)
    func fetchPreviewVideoURL(from pageURL: String) async -> String? {
        guard let url = URL(string: pageURL) else { return nil }

        do {
            var request = URLRequest(url: url)
            request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
            request.timeoutInterval = 15

            let (data, _) = try await URLSession.shared.data(for: request)
            guard let html = String(data: data, encoding: .utf8) else { return nil }

            // 方案1: 精确匹配预览视频路径
            let previewPattern = #"<source[^>]+src="(/wp-content/uploads/preview/[^"]+\.(?:webm|mp4))"[^>]*>"#
            if let match = extractFirstMatch(from: html, pattern: previewPattern, groups: 1) {
                let relativePath = match[0]
                return relativePath.hasPrefix("/") ? baseURL + relativePath : relativePath
            }

            // 方案2: 从URL推断预览视频地址
            return inferPreviewVideoURL(from: pageURL)
        } catch {
            return nil
        }
    }

    // MARK: - 从详情页URL推断预览视频地址
    private func inferPreviewVideoURL(from pageURL: String) -> String? {
        // 提取文件名部分
        // 例如: https://moewalls.com/anime/yandere-anime-school-girl-samurai-live-wallpaper/
        // 文件名: yandere-anime-school-girl-samurai
        let pattern = #"moewalls\.com/[^/]+/([^/]+?)(?:-live-wallpaper)?/?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]),
              let match = regex.firstMatch(in: pageURL, range: NSRange(location: 0, length: (pageURL as NSString).length)),
              match.numberOfRanges >= 2 else {
            return nil
        }

        let fileName = (pageURL as NSString).substring(with: match.range(at: 1))
        let currentYear = Calendar.current.component(.year, from: Date())

        // 构建预览视频URL
        return "\(baseURL)/wp-content/uploads/preview/\(currentYear)/\(fileName)-preview.webm"
    }

    // MARK: - 辅助方法：正则提取
    private func extractFirstMatch(from text: String, pattern: String, groups: Int) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return nil
        }

        let nsString = text as NSString
        guard let match = regex.firstMatch(in: text, range: NSRange(location: 0, length: nsString.length)),
              match.numberOfRanges > groups else {
            return nil
        }

        var results: [String] = []
        for i in 1...groups {
            let range = match.range(at: i)
            if range.location != NSNotFound {
                results.append(nsString.substring(with: range))
            }
        }

        return results.isEmpty ? nil : results
    }

    // MARK: - 重置加载状态
    func reset() {
        currentPage = 0
        wallpapers.removeAll()
        hasMorePages = true
    }

    // MARK: - 获取视频下载URL (从下载按钮提取data-url)
    func getDownloadURL(for wallpaper: OnlineWallpaper) async throws -> String {
        guard let detailURL = URL(string: wallpaper.url) else {
            throw WallpaperError.invalidURL
        }

        var request = URLRequest(url: detailURL)
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw WallpaperError.networkError
        }

        guard let html = String(data: data, encoding: .utf8) else {
            throw WallpaperError.parseError("无法解码HTML")
        }

        // 提取下载按钮的data-url属性
        let dataUrlPattern = #"id\s*=\s*"moe-download"[^>]*data-url\s*=\s*"([^"]+)""#
        guard let dataUrlMatch = extractFirstMatch(from: html, pattern: dataUrlPattern, groups: 1),
              let dataUrl = dataUrlMatch.first else {
            throw WallpaperError.downloadURLNotFound
        }

        // 构建下载地址
        return "https://go.moewalls.com/download.php?video=\(dataUrl)"
    }
}

// MARK: - 错误类型
enum WallpaperError: LocalizedError {
    case invalidURL
    case networkError
    case parseError(String)
    case downloadURLNotFound

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的URL"
        case .networkError:
            return "网络请求失败"
        case .parseError(let detail):
            return "解析错误: \(detail)"
        case .downloadURLNotFound:
            return "未找到下载链接"
        }
    }
}
