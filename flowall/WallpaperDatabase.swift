import Foundation

// MARK: - 壁纸数据库管理器 (JSON存储)
class WallpaperDatabase {
    static let shared = WallpaperDatabase()

    private var dbFileURL: URL
    private var cachedWallpapers: [String: [OnlineWallpaper]] = [:]

    private init() {
        let dbPath = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Flowall")

        try? FileManager.default.createDirectory(at: dbPath, withIntermediateDirectories: true)

        dbFileURL = dbPath.appendingPathComponent("wallpapers.json")
        loadFromDisk()
    }

    // MARK: - 保存壁纸
    func saveWallpapers(_ wallpapers: [OnlineWallpaper], query: String) {
        let key = query.isEmpty ? "_default" : query
        cachedWallpapers[key] = wallpapers
        saveToDisk()
    }

    // MARK: - 获取壁纸
    func getWallpapers(query: String, limit: Int = 10) -> [OnlineWallpaper] {
        let key = query.isEmpty ? "_default" : query
        let wallpapers = cachedWallpapers[key] ?? []
        return Array(wallpapers.prefix(limit))
    }

    // MARK: - 保存到磁盘
    private func saveToDisk() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted

            // 转换为可编码的字典
            var encodableData: [String: [[String: String?]]] = [:]
            for (key, wallpapers) in cachedWallpapers {
                encodableData[key] = wallpapers.map { wallpaper in
                    [
                        "title": wallpaper.title,
                        "url": wallpaper.url,
                        "thumbnail": wallpaper.thumbnail,
                        "videoURL": wallpaper.videoURL
                    ]
                }
            }

            let data = try encoder.encode(encodableData)
            try data.write(to: dbFileURL)
        } catch {
            // 静默失败
        }
    }

    // MARK: - 从磁盘加载
    private func loadFromDisk() {
        do {
            guard FileManager.default.fileExists(atPath: dbFileURL.path) else { return }

            let data = try Data(contentsOf: dbFileURL)
            let decoder = JSONDecoder()
            let encodableData = try decoder.decode([String: [[String: String?]]].self, from: data)

            // 转换回OnlineWallpaper
            cachedWallpapers.removeAll()
            for (key, wallpaperDicts) in encodableData {
                let wallpapers = wallpaperDicts.compactMap { dict -> OnlineWallpaper? in
                    guard let title = dict["title"] as? String,
                          let url = dict["url"] as? String,
                          let thumbnail = dict["thumbnail"] as? String else {
                        return nil
                    }
                    return OnlineWallpaper(
                        title: title,
                        url: url,
                        thumbnail: thumbnail,
                        videoURL: dict["videoURL"] as? String
                    )
                }
                cachedWallpapers[key] = wallpapers
            }
        } catch {
            // 静默失败
        }
    }

    // MARK: - 清理旧数据
    func clearAll() {
        cachedWallpapers.removeAll()
        try? FileManager.default.removeItem(at: dbFileURL)
    }
}
