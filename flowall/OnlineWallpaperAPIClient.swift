import Foundation

// MARK: - 在线壁纸 API 客户端
@MainActor
class OnlineWallpaperAPIClient: ObservableObject {
    static let shared = OnlineWallpaperAPIClient()

    private let baseURL = "https://ljlklchwubjgdqwmxmfx.supabase.co"
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: config)
    }

    // MARK: - 获取壁纸列表
    func fetchWallpapers(
        page: Int = 1,
        limit: Int = 20,
        search: String? = nil
    ) async throws -> WallpaperAPIResponse {
        var components = URLComponents(string: "\(baseURL)/functions/v1/flowall")!

        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "page", value: "\(page)"),
            URLQueryItem(name: "limit", value: "\(limit)")
        ]

        if let search = search, !search.isEmpty {
            queryItems.append(URLQueryItem(name: "search", value: search))
            print("🌐 API 请求 URL 包含搜索词: '\(search)'")
        }

        components.queryItems = queryItems

        guard let url = components.url else {
            throw APIError.invalidURL
        }

        print("🌐 发送 API 请求: \(url.absoluteString)")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("Flowall/1.0", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            print("🌐 API 响应状态码: \(httpResponse.statusCode)")

            guard (200...299).contains(httpResponse.statusCode) else {
                throw APIError.httpError(statusCode: httpResponse.statusCode)
            }

            let decoder = JSONDecoder()
            return try decoder.decode(WallpaperAPIResponse.self, from: data)

        } catch let error as APIError {
            throw error
        } catch let error as DecodingError {
            throw APIError.decodingError(error)
        } catch {
            throw APIError.networkError(error)
        }
    }
}
