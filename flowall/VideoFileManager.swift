import Foundation
import AppKit
import AVFoundation

/// 视频文件管理器
/// 职责:管理壁纸视频文件的读取、缓存和处理
/// 遵循 SOLID 原则:单一职责(SRP) - 专注于文件管理
class VideoFileManager {

    // MARK: - 缩略图缓存

    /// 缩略图缓存目录
    private static let thumbnailCacheURL: URL = {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        return cacheDir.appendingPathComponent(AppConstants.File.thumbnailCacheDir)
    }()

    /// 确保缩略图缓存目录存在
    private static func ensureThumbnailCacheDirectoryExists() {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: thumbnailCacheURL.path) {
            try? fileManager.createDirectory(
                at: thumbnailCacheURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }

    /// 获取视频文件的缓存缩略图路径
    private static func getThumbnailCachePath(for videoURL: URL) -> URL {
        let videoFileName = videoURL.lastPathComponent
        let cacheFileName = "\(videoFileName.hashValue).jpg"
        return thumbnailCacheURL.appendingPathComponent(cacheFileName)
    }

    // MARK: - 视频目录管理

    /// 获取视频目录路径(支持自定义路径)
    static func getVideoDirectory() -> URL {
        let customPath = UserDefaults.standard.string(forKey: AppConstants.UserDefaultsKey.wallpaperPath)
        if let path = customPath, !path.isEmpty {
            return URL(fileURLWithPath: path)
        }
        // 默认路径
        let defaultPath = "\(NSHomeDirectory())/\(AppConstants.File.defaultWallpaperDir)"
        return URL(fileURLWithPath: defaultPath)
    }

    /// 加载视频文件列表
    /// - Returns: 视频文件 URL 数组
    static func loadVideoFiles() -> [URL] {
        let fileManager = FileManager.default
        let videoDirectory = getVideoDirectory()

        // 确保目录存在
        ensureDirectoryExists()

        guard let contents = try? fileManager.contentsOfDirectory(atPath: videoDirectory.path) else {
            print("无法读取目录: \(videoDirectory.path)")
            return []
        }

        return contents.compactMap { filename in
            let url = videoDirectory.appendingPathComponent(filename)

            // 只返回视频文件
            let fileExtension = url.pathExtension.lowercased()

            return AppConstants.File.supportedVideoExtensions.contains(fileExtension) ? url : nil
        }
    }

    /// 确保视频目录存在
    static func ensureDirectoryExists() {
        let fileManager = FileManager.default
        let videoDirectory = getVideoDirectory()

        if !fileManager.fileExists(atPath: videoDirectory.path) {
            try? fileManager.createDirectory(
                at: videoDirectory,
                withIntermediateDirectories: true,
                attributes: nil
            )
            print("已创建视频目录: \(videoDirectory.path)")
        }
    }

    /// 在 Finder 中打开视频目录
    static func openVideoDirectory() {
        ensureDirectoryExists()
        NSWorkspace.shared.open(getVideoDirectory())
    }

    /// 获取视频库大小
    static func getVideoLibrarySize() -> Int64 {
        let fileManager = FileManager.default
        let videoDirectory = getVideoDirectory()

        guard let enumerator = fileManager.enumerator(at: videoDirectory, includingPropertiesForKeys: [.fileSizeKey]) else {
            return 0
        }

        var totalSize: Int64 = 0

        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                  let fileSize = resourceValues.fileSize else {
                continue
            }
            totalSize += Int64(fileSize)
        }

        return totalSize
    }

    /// 获取视频文件缩略图(带缓存)
    /// - Parameter url: 视频 URL
    /// - Returns: 缩略图图片
    static func generateThumbnail(for url: URL) -> NSImage? {
        ensureThumbnailCacheDirectoryExists()

        let cachePath = getThumbnailCachePath(for: url)

        // 1. 检查缓存是否存在且有效(视频文件未修改)
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: cachePath.path) {
            // 检查视频文件的修改时间
            if let videoAttrs = try? fileManager.attributesOfItem(atPath: url.path),
               let cacheAttrs = try? fileManager.attributesOfItem(atPath: cachePath.path),
               let videoModDate = videoAttrs[.modificationDate] as? Date,
               let cacheModDate = cacheAttrs[.modificationDate] as? Date,
               cacheModDate > videoModDate {
                // 缓存有效,直接返回
                if let cachedImage = NSImage(contentsOf: cachePath) {
                    return cachedImage
                }
            }
        }

        // 2. 生成新缩略图
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true

        let time = CMTime(seconds: 1.0, preferredTimescale: 600)

        do {
            let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))

            // 3. 保存缩略图到缓存
            if let tiffData = nsImage.tiffRepresentation,
               let bitmap = NSBitmapImageRep(data: tiffData),
               let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) {
                try? jpegData.write(to: cachePath)
            }

            return nsImage
        } catch {
            print("生成缩略图失败: \(error)")
            return nil
        }
    }

    /// 清除缩略图缓存
    static func clearThumbnailCache() {
        let fileManager = FileManager.default
        try? fileManager.removeItem(at: thumbnailCacheURL)
        ensureThumbnailCacheDirectoryExists()
    }
}
