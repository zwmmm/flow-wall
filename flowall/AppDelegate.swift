import Cocoa
import AVFoundation

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemManager: StatusItemManager?
    var videoWallpaperManager: VideoWallpaperManager?
    private var settingsWindowController: SettingsWindowController?
    private var previewWindowController: VideoPreviewWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        videoWallpaperManager = VideoWallpaperManager()
        videoWallpaperManager?.setupScreenChangeObserver()

        statusItemManager = StatusItemManager()
        statusItemManager?.delegate = self
        statusItemManager?.setupStatusItem()

        videoWallpaperManager?.loadSavedWallpapers()

        // 监听打开设置的通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOpenSettings),
            name: NSNotification.Name(AppConstants.NotificationName.openSettings),
            object: nil
        )

        // 监听应用壁纸的通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleApplyWallpaper(_:)),
            name: NSNotification.Name("ApplyWallpaper"),
            object: nil
        )

        // 监听本地壁纸预览通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLocalPreview(_:)),
            name: NSNotification.Name("PreviewLocalWallpaper"),
            object: nil
        )

        // 监听在线壁纸预览通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOnlinePreview(_:)),
            name: NSNotification.Name("PreviewOnlineWallpaper"),
            object: nil
        )
    }

    @objc private func handleApplyWallpaper(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let path = userInfo["path"] as? String,
              let manager = videoWallpaperManager else {
            return
        }

        // 只设置当前显示器,不同步到其他屏幕
        let screen = manager.getFocusedScreen()
        manager.setWallpaper(videoPath: path, for: screen)
    }

    @objc private func handleOpenSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func handleLocalPreview(_ notification: Notification) {
        print("[AppDelegate] 收到本地预览通知")
        guard let userInfo = notification.userInfo,
              let urlString = userInfo["url"] as? String,
              let videoURL = URL(string: urlString) else {
            print("[AppDelegate] 本地预览通知参数错误: \(notification.userInfo ?? [:])")
            return
        }

        print("[AppDelegate] 打开本地预览: \(videoURL.lastPathComponent)")
        let fileName = videoURL.lastPathComponent

        previewWindowController = VideoPreviewWindowController(
            videoURL: videoURL,
            title: fileName
        )

        guard let window = previewWindowController?.window else {
            print("[AppDelegate] ❌ 窗口创建失败")
            return
        }

        print("[AppDelegate] ✓ 窗口已创建: \(window)")
        print("[AppDelegate] 窗口可见性: \(window.isVisible)")
        print("[AppDelegate] 窗口 frame: \(window.frame)")

        previewWindowController?.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        print("[AppDelegate] showWindow 后窗口可见性: \(window.isVisible)")
    }

    @objc private func handleOnlinePreview(_ notification: Notification) {
        print("[AppDelegate] 收到在线预览通知")
        guard let userInfo = notification.userInfo,
              let previewUrlString = userInfo["previewUrl"] as? String,
              let previewURL = URL(string: previewUrlString) else {
            print("[AppDelegate] 在线预览通知参数错误: \(notification.userInfo ?? [:])")
            return
        }

        print("[AppDelegate] 打开在线预览")
        print("[AppDelegate] 完整 URL: \(previewURL.absoluteString)")
        print("[AppDelegate] URL Scheme: \(previewURL.scheme ?? "无")")
        print("[AppDelegate] URL Host: \(previewURL.host ?? "无")")
        print("[AppDelegate] URL Path: \(previewURL.path)")
        print("[AppDelegate] 文件名: \(previewURL.lastPathComponent)")

        let fileName = previewURL.lastPathComponent
        let title = fileName.isEmpty ? "在线壁纸预览" : fileName

        previewWindowController = VideoPreviewWindowController(
            videoURL: previewURL,
            title: title
        )

        guard let window = previewWindowController?.window else {
            print("[AppDelegate] ❌ 窗口创建失败")
            return
        }

        print("[AppDelegate] ✓ 窗口已创建: \(window)")
        print("[AppDelegate] 窗口可见性: \(window.isVisible)")
        print("[AppDelegate] 窗口 frame: \(window.frame)")

        previewWindowController?.showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        print("[AppDelegate] showWindow 后窗口可见性: \(window.isVisible)")
    }

    func applicationWillTerminate(_ notification: Notification) {
        videoWallpaperManager?.stopAllWallpapers()
    }
}

// MARK: - StatusItemManagerDelegate

extension AppDelegate: StatusItemManagerDelegate {
    func statusItemManager(_ manager: StatusItemManager, didSelectVideoAtPath path: String) {
        videoWallpaperManager?.setWallpaperForFocusedScreen(videoPath: path)
    }

    func statusItemManagerDidTogglePlayPause(_ manager: StatusItemManager) {
        videoWallpaperManager?.togglePlayPauseForFocusedScreen()
    }

    func statusItemManagerDidSelectStop(_ manager: StatusItemManager) {
        videoWallpaperManager?.stopWallpaperForFocusedScreen()
    }

    func statusItemManagerDidSelectQuit(_ manager: StatusItemManager) {
        NSApplication.shared.terminate(nil)
    }

    func statusItemManagerDidSelectSettings(_ manager: StatusItemManager) {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func statusItemManagerGetWallpaperManager(_ manager: StatusItemManager) -> VideoWallpaperManager? {
        return videoWallpaperManager
    }
}
