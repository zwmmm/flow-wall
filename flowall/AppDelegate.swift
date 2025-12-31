import Cocoa
import AVFoundation

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemManager: StatusItemManager?
    var videoWallpaperManager: VideoWallpaperManager?
    private var settingsWindowController: SettingsWindowController?

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
