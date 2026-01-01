import Foundation

// MARK: - 在线壁纸数据模型（API 版本）
struct OnlineWallpaper: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let coverUrl: String      // 封面图（缩略图）
    let previewUrl: String    // webm 预览视频
    let videoUrl: String      // mp4 下载地址

    enum CodingKeys: String, CodingKey {
        case id, name
        case coverUrl = "cover_url"
        case previewUrl = "preview_url"
        case videoUrl = "video_url"
    }

    static func == (lhs: OnlineWallpaper, rhs: OnlineWallpaper) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - API 响应结构
struct WallpaperAPIResponse: Codable {
    let success: Bool
    let data: WallpaperData

    struct WallpaperData: Codable {
        let items: [OnlineWallpaper]
        let pagination: Pagination
    }

    struct Pagination: Codable {
        let page: Int
        let limit: Int
        let total: Int
        let totalPages: Int
    }
}

// MARK: - API 错误类型
enum APIError: LocalizedError {
    case invalidURL
    case networkError(Error)
    case invalidResponse
    case httpError(statusCode: Int)
    case decodingError(Error)
    case downloadFailed  // 下载失败

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的 URL"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .invalidResponse:
            return "服务器响应无效"
        case .httpError(let code):
            return "HTTP 错误: \(code)"
        case .decodingError(let error):
            return "数据解析失败: \(error.localizedDescription)"
        case .downloadFailed:
            return "下载失败"
        }
    }
}
