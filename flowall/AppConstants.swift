import Foundation

/// 应用常量统一管理
enum AppConstants {

    // MARK: - UserDefaults Keys

    enum UserDefaultsKey {
        /// 壁纸文件路径
        static let wallpaperPath = "wallpaperPath"
        /// 屏幕壁纸映射
        static let screenWallpapers = "ScreenWallpapers"
        /// 隐藏刘海屏
        static let hideNotch = "hideNotch"
        /// 同步所有桌面
        static let syncAllDesktops = "syncAllDesktops"
        /// 登录时启动
        static let launchAtLogin = "launchAtLogin"
        /// 缩略图缓存版本
        static let thumbnailCacheVersion = "thumbnailCacheVersion"
    }

    // MARK: - 屏幕标识

    enum ScreenKey {
        /// 屏幕编号键名
        static let screenNumber = "NSScreenNumber"
    }

    // MARK: - 通知名称

    enum NotificationName {
        /// 打开设置
        static let openSettings = "OpenSettings"
    }

    // MARK: - 文件相关

    enum File {
        /// 默认壁纸目录名
        static let defaultWallpaperDir = "Livewall"
        /// 支持的视频格式
        static let supportedVideoExtensions = ["mp4", "mov", "m4v", "mkv"]
        /// 缩略图缓存目录
        static let thumbnailCacheDir = "flowall/ThumbnailCache"
    }

    // MARK: - UI 常量

    enum UI {
        /// 面板宽度
        static let panelWidth: CGFloat = 280
        /// 面板高度
        static let panelHeight: CGFloat = 620
        /// 卡片内边距
        static let cardPadding: CGFloat = 14
        /// 卡片间距
        static let cardSpacing: CGFloat = 12

        /// 设置窗口宽度
        static let settingsWidth: CGFloat = 420
        /// 设置窗口高度
        static let settingsHeight: CGFloat = 550
    }

    // MARK: - 外部链接

    enum Links {
        /// GitHub 仓库
        static let github = "https://github.com/zwmmm/flow-wall"
        /// Issues 反馈
        static let issues = "https://github.com/zwmmm/flow-wall/issues"
        /// 发布页面
        static let releases = "https://github.com/zwmmm/flow-wall/releases"
    }
}
