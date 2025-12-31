import Cocoa

/// 状态栏菜单管理器代理
protocol StatusItemManagerDelegate: AnyObject {
    func statusItemManager(_ manager: StatusItemManager, didSelectVideoAtPath path: String)
    func statusItemManagerDidTogglePlayPause(_ manager: StatusItemManager)
    func statusItemManagerDidSelectStop(_ manager: StatusItemManager)
    func statusItemManagerDidSelectQuit(_ manager: StatusItemManager)
    func statusItemManagerDidSelectSettings(_ manager: StatusItemManager)
    func statusItemManagerGetWallpaperManager(_ manager: StatusItemManager) -> VideoWallpaperManager?
}

/// 状态栏菜单管理器
class StatusItemManager {

    weak var delegate: StatusItemManagerDelegate?
    private var statusItem: NSStatusItem?
    private var panelController: WallpaperPanelController?
    private var isPlaying: Bool = true
    private var contextMenu: NSMenu?

    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        panelController = WallpaperPanelController()

        if let button = statusItem?.button {
            // 优先尝试加载 SVG 图标
            if let iconImage = loadSVGIcon() ?? createStatusBarIcon() {
                button.image = iconImage
                button.title = ""
            } else {
                // 降级到文本
                button.title = "Flowall"
                button.image = nil
            }

            // 设置点击事件
            button.action = #selector(statusItemClicked(_:))
            button.target = self
            // 监听左右键点击
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        // 创建菜单但不设置
        setupMenu()
    }

    private func setupMenu() {
        let menu = NSMenu()

        // 暂停/播放
        let playPauseItem = NSMenuItem(
            title: "暂停播放",
            action: #selector(togglePlayPause),
            keyEquivalent: "p"
        )
        playPauseItem.target = self
        menu.addItem(playPauseItem)

        menu.addItem(NSMenuItem.separator())

        // 同步所有屏幕
        let syncItem = NSMenuItem(
            title: "同步所有屏幕",
            action: #selector(syncAllScreens),
            keyEquivalent: "s"
        )
        syncItem.target = self
        menu.addItem(syncItem)

        menu.addItem(NSMenuItem.separator())

        // 退出应用
        let quitItem = NSMenuItem(
            title: "退出 Flowall",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        // 保存菜单引用
        contextMenu = menu
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            // 右键 - 显示菜单
            contextMenu?.popUp(
                positioning: nil,
                at: NSPoint(x: 0, y: sender.bounds.height),
                in: sender
            )
        } else {
            // 左键 - 显示壁纸面板
            panelController?.show(relativeTo: sender)
        }
    }

    @objc private func togglePlayPause() {
        isPlaying.toggle()

        if let manager = delegate?.statusItemManagerGetWallpaperManager(self) {
            if isPlaying {
                manager.resumeAllVideos()
            } else {
                manager.pauseAllVideos()
            }
        }

        // 更新菜单项文字
        if let menu = contextMenu,
           let playPauseItem = menu.items.first {
            playPauseItem.title = isPlaying ? "暂停播放" : "继续播放"
        }
    }

    @objc private func syncAllScreens() {
        if let manager = delegate?.statusItemManagerGetWallpaperManager(self) {
            manager.syncCurrentWallpaperToAllScreens()
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    /// 加载 SVG 图标文件
    private func loadSVGIcon() -> NSImage? {
        // 尝试从 Assets 加载图标
        let iconName = "StatusBarIcon"
        if let image = NSImage(named: iconName) {
            image.isTemplate = true
            image.size = NSSize(width: 16, height: 16)
            return image
        }

        // 尝试从应用包加载 SVG 文件
        if let svgURL = Bundle.main.url(forResource: "statusbar_icon", withExtension: "svg"),
           let image = NSImage(contentsOf: svgURL) {
            image.isTemplate = true
            image.size = NSSize(width: 16, height: 16)
            return image
        }

        return nil
    }

    private func createStatusBarIcon() -> NSImage? {
        // 创建自定义状态栏图标 (标准macOS状态栏图标尺寸)
        let size = NSSize(width: 16, height: 16)
        let image = NSImage(size: size)

        image.lockFocus()

        // 绘制简单的壁纸图标 (矩形+山形)
        let rect = NSRect(x: 1.5, y: 1.5, width: 13, height: 13)

        // 外框
        let path = NSBezierPath(roundedRect: rect, xRadius: 1.5, yRadius: 1.5)
        NSColor.controlTextColor.setStroke()
        path.lineWidth = 1.2
        path.stroke()

        // 山形装饰
        let mountainPath = NSBezierPath()
        mountainPath.move(to: NSPoint(x: 3, y: 5))
        mountainPath.line(to: NSPoint(x: 6, y: 10))
        mountainPath.line(to: NSPoint(x: 9, y: 7))
        mountainPath.line(to: NSPoint(x: 13, y: 12))
        mountainPath.line(to: NSPoint(x: 13, y: 5))
        mountainPath.line(to: NSPoint(x: 3, y: 5))
        mountainPath.close()

        NSColor.controlTextColor.withAlphaComponent(0.5).setFill()
        mountainPath.fill()

        // 小圆点(太阳)
        let circlePath = NSBezierPath(ovalIn: NSRect(x: 10.5, y: 10.5, width: 2.5, height: 2.5))
        NSColor.controlTextColor.setFill()
        circlePath.fill()

        image.unlockFocus()
        image.isTemplate = true

        return image
    }
}
