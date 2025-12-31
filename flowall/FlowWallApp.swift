import SwiftUI

@main
struct flowallApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // 不需要默认的 Window，我们使用状态栏菜单
        Settings {
            EmptyView()
        }
    }
}
