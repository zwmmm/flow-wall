import SwiftUI
import AppKit
import ServiceManagement

// MARK: - 设置窗口控制器

class SettingsWindowController: NSWindowController {

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: AppConstants.UI.settingsWidth, height: AppConstants.UI.settingsHeight),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "设置"
        window.center()

        self.init(window: window)

        let settingsView = SettingsView()
        let hostingController = NSHostingController(rootView: settingsView)
        window.contentViewController = hostingController
    }

    override init(window: NSWindow?) {
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
}

// MARK: - 设置视图

struct SettingsView: View {

    @AppStorage(AppConstants.UserDefaultsKey.hideNotch) private var hideNotch = false
    @AppStorage(AppConstants.UserDefaultsKey.wallpaperPath) private var wallpaperPath = VideoFileManager.getVideoDirectory().path
    @AppStorage(AppConstants.UserDefaultsKey.launchAtLogin) private var launchAtLogin = false

    @State private var isCheckingUpdate = false
    @State private var updateMessage = ""
    @State private var showUpdateAlert = false

    var body: some View {
        VStack(spacing: 0) {
            // 顶部 - 应用信息
            aboutSection
                .padding(.top, 20)
                .padding(.bottom, 16)

            Divider()

            // 中间 - 设置列表
            ScrollView {
                VStack(spacing: 16) {
                    // 功能设置组
                    settingsGroup

                    // 链接组
                    linksGroup
                }
                .padding(20)
            }

            Divider()

            // 底部 - 操作按钮
            bottomActions
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
        }
        .frame(width: AppConstants.UI.settingsWidth, height: AppConstants.UI.settingsHeight)
        .alert("检查更新", isPresented: $showUpdateAlert) {
            Button("确定", role: .cancel) {
                updateMessage = ""
            }
        } message: {
            Text(updateMessage)
        }
    }

    // MARK: - 关于部分

    private var aboutSection: some View {
        HStack(spacing: 16) {
            Spacer()

            // 应用图标 - 使用真实的 AppIcon
            if let appIcon = NSImage(named: "AppIcon") {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 64, height: 64)
                    .cornerRadius(12)
            } else {
                // 备用图标
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 40))
                    .foregroundColor(.accentColor)
                    .frame(width: 64, height: 64)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
            }

            // 应用名称和描述
            VStack(alignment: .leading, spacing: 4) {
                Text(AppVersion.appName)
                    .font(.system(size: 22, weight: .semibold))

                Text(AppVersion.description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                Text(AppVersion.shortVersion)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.top, 2)
            }

            Spacer()
        }
        .padding(.horizontal, 4)
    }

    // MARK: - 功能设置组

    private var settingsGroup: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("功能设置")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                SettingRow(
                    icon: "display",
                    title: "隐藏刘海屏",
                    subtitle: "自动调整视频区域避开刘海"
                ) {
                    Toggle("", isOn: $hideNotch)
                        .labelsHidden()
                }

                Divider()
                    .padding(.leading, 44)

                SettingRow(
                    icon: "folder",
                    title: "壁纸文件夹",
                    subtitle: "管理本地壁纸存储位置"
                ) {
                    HStack(spacing: 8) {
                        Button(action: {
                            VideoFileManager.openVideoDirectory()
                        }) {
                            Image(systemName: "arrow.up.forward.square")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("在访达中打开")

                        Button("更改...") {
                            selectWallpaperPath()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                Divider()
                    .padding(.leading, 44)

                SettingRow(
                    icon: "power",
                    title: "登录时启动",
                    subtitle: "开机自动启动 Flowall"
                ) {
                    Toggle("", isOn: $launchAtLogin)
                        .labelsHidden()
                        .onChange(of: launchAtLogin) { _, newValue in
                            updateLaunchAtLogin(enabled: newValue)
                        }
                }
            }
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
    }

    // MARK: - 链接组

    private var linksGroup: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("支持与反馈")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                LinkRow(
                    icon: "checkmark.circle",
                    title: "检查更新",
                    subtitle: "查看是否有新版本可用"
                ) {
                    if isCheckingUpdate {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 20, height: 20)
                    } else {
                        Button("检查") {
                            checkForUpdates()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                Divider()
                    .padding(.leading, 44)

                LinkRow(
                    icon: "link.circle",
                    title: "在线地址",
                    subtitle: "GitHub · Issues"
                ) {
                    HStack(spacing: 10) {
                        // GitHub 图标
                        Button(action: AppVersion.openGitHub) {
                            Image(systemName: "star.circle")
                                .font(.system(size: 18))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("打开 GitHub 仓库")

                        // Issues 图标
                        Button(action: AppVersion.openIssues) {
                            Image(systemName: "exclamationmark.bubble")
                                .font(.system(size: 18))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("报告问题或提建议")
                    }
                }
            }
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
        }
    }

    // MARK: - 底部操作

    private var bottomActions: some View {
        HStack {
            // 版权信息
            Text(AppVersion.copyright)
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            Spacer()

            // 退出按钮
            Button("退出 Flowall") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundColor(.red)
        }
    }

    // MARK: - Actions

    private func selectWallpaperPath() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = "选择壁纸存储目录"

        if panel.runModal() == .OK, let url = panel.url {
            wallpaperPath = url.path
            NotificationCenter.default.post(
                name: NSNotification.Name("WallpaperPathChanged"),
                object: nil,
                userInfo: ["path": url.path]
            )
        }
    }

    private func updateLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("设置登录启动失败: \(error)")
            }
        }
    }

    private func checkForUpdates() {
        isCheckingUpdate = true
        updateMessage = ""

        AppVersion.checkForUpdates { hasUpdate, latestVersion, downloadURL, error in
            isCheckingUpdate = false

            if let error = error {
                updateMessage = "检查更新失败\n\(error)"
                showUpdateAlert = true
                return
            }

            if hasUpdate, let version = latestVersion {
                updateMessage = "发现新版本 v\(version)\n当前版本: \(AppVersion.version)"
                showUpdateAlert = true

                // 可选:直接打开下载页面
                if let urlString = downloadURL, let url = URL(string: urlString) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        NSWorkspace.shared.open(url)
                    }
                }
            } else {
                updateMessage = "已是最新版本 \(AppVersion.version)"
                showUpdateAlert = true
            }
        }
    }
}

// MARK: - 设置行组件

struct SettingRow<Content: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    let content: Content

    init(
        icon: String,
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // 图标 - 统一灰色
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.secondary)
                .frame(width: 32, height: 32)

            // 文本
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13))

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // 控件
            content
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

// MARK: - 链接行组件

struct LinkRow<Content: View>: View {
    let icon: String
    let title: String
    let subtitle: String
    let content: Content

    init(
        icon: String,
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // 图标 - 统一灰色
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.secondary)
                .frame(width: 32, height: 32)

            // 文本
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13))

                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // 控件
            content
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}
