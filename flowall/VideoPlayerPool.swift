import Foundation

// MARK: - 视频播放器池管理
@MainActor
class VideoPlayerPool: ObservableObject {
    static let shared = VideoPlayerPool()

    private var activePlayerCount = 0
    private let maxConcurrentPlayers = 6  // 同时最多 6 个视频播放器

    private init() {}

    // MARK: - 公开方法

    /// 检查是否可以激活新的播放器
    func canActivatePlayer() -> Bool {
        return activePlayerCount < maxConcurrentPlayers
    }

    /// 激活一个播放器
    func activatePlayer() {
        activePlayerCount += 1
        print("🎬 激活播放器, 当前活跃数: \(activePlayerCount)/\(maxConcurrentPlayers)")
    }

    /// 停用一个播放器
    func deactivatePlayer() {
        activePlayerCount = max(0, activePlayerCount - 1)
        print("⏸️ 停用播放器, 当前活跃数: \(activePlayerCount)/\(maxConcurrentPlayers)")
    }

    /// 重置所有播放器
    func reset() {
        activePlayerCount = 0
        print("🔄 重置播放器池")
    }
}
