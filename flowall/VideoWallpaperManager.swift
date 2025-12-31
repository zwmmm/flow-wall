import Cocoa
import AVFoundation

// MARK: - NSScreen Extension

extension NSScreen {
    /// 获取屏幕唯一标识ID
    var screenID: UInt32 {
        return deviceDescription[NSDeviceDescriptionKey(AppConstants.ScreenKey.screenNumber)] as? UInt32 ?? 0
    }
}

// MARK: - ScreenWallpaper

/// 单个屏幕的壁纸信息
class ScreenWallpaper {
    let screenID: UInt32
    var videoPath: String?
    var window: NSWindow?
    var player: AVPlayer?
    var playerLayer: AVPlayerLayer?
    var isPlaying: Bool = false

    init(screenID: UInt32) {
        self.screenID = screenID
    }

    func setup(screen: NSScreen, videoPath: String) {
        // 清理之前的资源
        cleanup()

        self.videoPath = videoPath
        var screenFrame = screen.frame

        // 检查是否启用隐藏刘海屏
        let hideNotch = UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKey.hideNotch)
        if hideNotch, #available(macOS 12.0, *) {
            // 如果有 safeAreaInsets,调整视频区域避开刘海
            let safeArea = screen.safeAreaInsets
            if safeArea.top > 0 {
                screenFrame.origin.y += safeArea.top
                screenFrame.size.height -= safeArea.top
            }
        }

        // 创建窗口
        window = NSWindow(
            contentRect: screenFrame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false,
            screen: screen  // 显式指定屏幕
        )

        guard let window = window else { return }

        // 关键配置:窗口必须位于桌面图标层下方
        window.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopWindow)) - 1)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.contentView?.wantsLayer = true

        // 创建播放器
        let url = URL(fileURLWithPath: videoPath)
        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        player?.volume = 0.0

        // 创建播放器层
        playerLayer = AVPlayerLayer(player: player)
        playerLayer?.frame = window.contentView?.bounds ?? .zero
        playerLayer?.videoGravity = .resizeAspectFill
        playerLayer?.contentsGravity = .resizeAspectFill

        if let contentView = window.contentView, let layer = contentView.layer {
            // 确保播放器层在最底层
            layer.addSublayer(playerLayer!)
        }

        // 监听播放结束
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(playerItemDidReachEnd(_:)),
            name: .AVPlayerItemDidPlayToEndTime,
            object: item
        )

        // 确保窗口显示在正确的屏幕上
        window.setFrame(screenFrame, display: true)
        window.orderFrontRegardless()

        // 调试日志
        print("✅ 壁纸已设置到屏幕: \(screen.localizedName)")
        print("   窗口层级: \(window.level.rawValue)")
        print("   窗口框架: \(screenFrame)")
    }

    func play() {
        player?.play()
        isPlaying = true
    }

    func pause() {
        player?.pause()
        isPlaying = false
    }

    func cleanup() {
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        player?.pause()
        playerLayer?.removeFromSuperlayer()
        playerLayer = nil
        player = nil
        window?.orderOut(nil)
        window = nil
        videoPath = nil
        isPlaying = false
    }

    func updateFrame(screen: NSScreen) {
        let screenFrame = screen.frame
        window?.setFrame(screenFrame, display: true)
        playerLayer?.frame = window?.contentView?.bounds ?? .zero
    }

    @objc private func playerItemDidReachEnd(_ notification: Notification) {
        player?.seek(to: .zero)
        if isPlaying {
            player?.play()
        }
    }

    deinit {
        cleanup()
    }
}

/// 动态视频壁纸管理器
/// 支持多屏幕独立壁纸
class VideoWallpaperManager: NSObject {

    // MARK: - 属性

    /// 每个屏幕的壁纸映射 (screenID -> ScreenWallpaper)
    private var screenWallpapers: [UInt32: ScreenWallpaper] = [:]

    /// 壁纸状态变化回调
    var onWallpaperStateChanged: (() -> Void)?

    // MARK: - 公开方法

    /// 为指定屏幕设置壁纸
    func setWallpaper(videoPath: String, for screen: NSScreen) {
        guard FileManager.default.fileExists(atPath: videoPath) else {
            print("视频文件不存在: \(videoPath)")
            return
        }

        let screenID = screen.screenID

        // 获取或创建屏幕壁纸
        let screenWallpaper: ScreenWallpaper
        if let existing = screenWallpapers[screenID] {
            screenWallpaper = existing
        } else {
            screenWallpaper = ScreenWallpaper(screenID: screenID)
            screenWallpapers[screenID] = screenWallpaper
        }

        screenWallpaper.setup(screen: screen, videoPath: videoPath)
        screenWallpaper.play()

        // 保存设置
        saveWallpaperSettings()

        onWallpaperStateChanged?()
    }

    /// 为当前聚焦屏幕设置壁纸
    func setWallpaperForFocusedScreen(videoPath: String) {
        let screen = getFocusedScreen()
        setWallpaper(videoPath: videoPath, for: screen)

        // 检查是否启用同步到所有桌面
        let syncAllDesktops = UserDefaults.standard.bool(forKey: AppConstants.UserDefaultsKey.syncAllDesktops)
        if syncAllDesktops {
            // 异步为所有其他屏幕设置相同壁纸,提升响应速度
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                let otherScreens = NSScreen.screens.filter { $0 != screen }

                for otherScreen in otherScreens {
                    DispatchQueue.main.async {
                        self.setWallpaper(videoPath: videoPath, for: otherScreen)
                    }
                }
            }
        }
    }

    /// 为当前聚焦屏幕设置随机壁纸
    func setRandomWallpaperForFocusedScreen() {
        let videos = VideoFileManager.loadVideoFiles()
        guard !videos.isEmpty else { return }

        let randomVideo = videos.randomElement()!
        setWallpaperForFocusedScreen(videoPath: randomVideo.path)
    }

    /// 同步当前屏幕的壁纸到所有屏幕
    func syncCurrentWallpaperToAllScreens() {
        let focusedScreen = getFocusedScreen()
        let (videoPath, _) = getWallpaperInfo(for: focusedScreen)

        guard let path = videoPath else { return }

        for screen in NSScreen.screens where screen != focusedScreen {
            setWallpaper(videoPath: path, for: screen)
        }
    }

    /// 停止指定屏幕的壁纸
    func stopWallpaper(for screen: NSScreen) {
        let screenID = screen.screenID
        screenWallpapers[screenID]?.cleanup()
        screenWallpapers.removeValue(forKey: screenID)
        saveWallpaperSettings()
        onWallpaperStateChanged?()
    }

    /// 停止当前聚焦屏幕的壁纸
    func stopWallpaperForFocusedScreen() {
        let screen = getFocusedScreen()
        stopWallpaper(for: screen)
    }

    /// 停止所有屏幕的壁纸
    func stopAllWallpapers() {
        for (_, wallpaper) in screenWallpapers {
            wallpaper.cleanup()
        }
        screenWallpapers.removeAll()
        saveWallpaperSettings()
        onWallpaperStateChanged?()
    }

    /// 播放/暂停指定屏幕
    func togglePlayPause(for screen: NSScreen) {
        let screenID = screen.screenID
        guard let wallpaper = screenWallpapers[screenID] else { return }

        if wallpaper.isPlaying {
            wallpaper.pause()
        } else {
            wallpaper.play()
        }
        onWallpaperStateChanged?()
    }

    /// 播放/暂停当前聚焦屏幕
    func togglePlayPauseForFocusedScreen() {
        let screen = getFocusedScreen()
        togglePlayPause(for: screen)
    }

    /// 播放所有屏幕
    func playAll() {
        for (_, wallpaper) in screenWallpapers {
            wallpaper.play()
        }
        onWallpaperStateChanged?()
    }

    /// 暂停所有屏幕
    func pauseAll() {
        for (_, wallpaper) in screenWallpapers {
            wallpaper.pause()
        }
        onWallpaperStateChanged?()
    }

    // MARK: - 查询方法

    /// 获取当前聚焦的屏幕（鼠标所在屏幕）
    func getFocusedScreen() -> NSScreen {
        let mouseLocation = NSEvent.mouseLocation
        for screen in NSScreen.screens {
            if screen.frame.contains(mouseLocation) {
                return screen
            }
        }
        return NSScreen.main ?? NSScreen.screens.first!
    }

    /// 获取屏幕的壁纸信息
    func getWallpaperInfo(for screen: NSScreen) -> (videoPath: String?, isPlaying: Bool) {
        let screenID = screen.screenID
        if let wallpaper = screenWallpapers[screenID] {
            return (wallpaper.videoPath, wallpaper.isPlaying)
        }
        return (nil, false)
    }

    /// 获取当前聚焦屏幕的壁纸信息
    func getFocusedScreenWallpaperInfo() -> (videoPath: String?, isPlaying: Bool) {
        return getWallpaperInfo(for: getFocusedScreen())
    }

    /// 是否有任何活跃的壁纸
    var hasActiveWallpaper: Bool {
        return !screenWallpapers.isEmpty
    }

    /// 获取屏幕显示名称
    func getScreenDisplayName(_ screen: NSScreen) -> String {
        if screen == NSScreen.main {
            return "主显示器"
        }
        if let index = NSScreen.screens.firstIndex(of: screen) {
            return "显示器 \(index + 1)"
        }
        return "显示器"
    }

    // MARK: - 持久化

    private func saveWallpaperSettings() {
        var settings: [String: String] = [:]
        for (screenID, wallpaper) in screenWallpapers {
            if let path = wallpaper.videoPath {
                settings[String(screenID)] = path
            }
        }
        UserDefaults.standard.set(settings, forKey: AppConstants.UserDefaultsKey.screenWallpapers)
    }

    func loadSavedWallpapers() {
        guard let settings = UserDefaults.standard.dictionary(forKey: AppConstants.UserDefaultsKey.screenWallpapers) as? [String: String] else {
            return
        }

        for screen in NSScreen.screens {
            let screenID = screen.screenID
            if let videoPath = settings[String(screenID)],
               FileManager.default.fileExists(atPath: videoPath) {
                setWallpaper(videoPath: videoPath, for: screen)
            }
        }
    }

    // MARK: - 屏幕变化监听

    func setupScreenChangeObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleScreenChange(_:)),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private func handleScreenChange(_ notification: Notification) {
        // 更新现有壁纸的窗口位置
        for screen in NSScreen.screens {
            let screenID = screen.screenID
            screenWallpapers[screenID]?.updateFrame(screen: screen)
        }
        onWallpaperStateChanged?()
    }

    // MARK: - 播放控制

    /// 暂停所有视频播放
    func pauseAllVideos() {
        for (_, wallpaper) in screenWallpapers {
            wallpaper.pause()
        }
    }

    /// 恢复所有视频播放
    func resumeAllVideos() {
        for (_, wallpaper) in screenWallpapers {
            wallpaper.play()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        stopAllWallpapers()
    }
}
