import SwiftUI
import ServiceManagement

// MARK: - 设置窗口控制器

class SettingsWindowController: NSWindowController {

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 400),
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

    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题
            Text("Flowall")
                .font(.system(size: 20, weight: .semibold))
                .padding(.top, 20)
                .padding(.bottom, 10)

            Text("v1.0.0")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .padding(.bottom, 20)

            Divider()

            // 设置列表
            List {
                SettingCell(
                    title: "隐藏刘海屏",
                    icon: "display"
                ) {
                    Toggle("", isOn: $hideNotch)
                        .labelsHidden()
                }

                SettingCell(
                    title: "壁纸文件夹",
                    icon: "folder"
                ) {
                    HStack(spacing: 8) {
                        Button(action: {
                            VideoFileManager.openVideoDirectory()
                        }) {
                            HStack(spacing: 4) {
                                Text(wallpaperPath)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                                    .frame(maxWidth: 120, alignment: .trailing)

                                Image(systemName: "arrow.up.forward.square")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)

                        Button("更改") {
                            selectWallpaperPath()
                        }
                    }
                }

                SettingCell(
                    title: "登录时启动",
                    icon: "power"
                ) {
                    Toggle("", isOn: $launchAtLogin)
                        .labelsHidden()
                        .onChange(of: launchAtLogin) { _, newValue in
                            updateLaunchAtLogin(enabled: newValue)
                        }
                }
            }
            .listStyle(.inset)

            Divider()

            // 底部按钮
            HStack(spacing: 16) {
                Button(action: {
                    openProjectPage()
                }) {
                    Image(systemName: "globe")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("访问 GitHub")

                Spacer()

                Button("退出 Flowall") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundColor(.red)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .frame(width: 420, height: 400)
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

    private func openProjectPage() {
        if let url = URL(string: "https://github.com/zwmmm/flow-wall") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - 设置单元格

struct SettingCell<Content: View>: View {
    let title: String
    let icon: String
    let content: Content

    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .frame(width: 28)

            Text(title)
                .font(.system(size: 13))

            Spacer()

            content
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}
