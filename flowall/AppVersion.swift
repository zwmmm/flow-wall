import Foundation
import AppKit

/// 应用版本管理
struct AppVersion {

    // MARK: - 版本信息

    /// 应用名称
    static let appName = "Flowall"

    /// 应用显示名称
    static let displayName = "Flowall - 动态壁纸"

    /// 应用版本号(从 Info.plist 读取)
    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    /// 构建版本号(从 Info.plist 读取)
    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    /// 完整版本字符串
    static var fullVersion: String {
        "v\(version) (\(buildNumber))"
    }

    /// 简短版本字符串
    static var shortVersion: String {
        "v\(version)"
    }

    // MARK: - 应用信息

    /// 应用简介
    static let description = "简洁优雅的 macOS 动态壁纸应用"

    /// 版权信息
    static var copyright: String {
        let year = Calendar.current.component(.year, from: Date())
        return "© \(year) Flowall. All rights reserved."
    }

    // MARK: - 链接

    /// GitHub 仓库地址
    static let githubURL = "https://github.com/zwmmm/flow-wall"

    /// Issues 反馈地址
    static let issuesURL = "https://github.com/zwmmm/flow-wall/issues"

    /// 发布页面地址
    static let releasesURL = "https://github.com/zwmmm/flow-wall/releases"

    /// 检查更新 API(GitHub Releases Latest API)
    static let updateCheckURL = "https://api.github.com/repos/zwmmm/flow-wall/releases/latest"

    // MARK: - 更新检查

    /// 检查是否有新版本
    /// - Parameter completion: 回调(有新版本, 最新版本号, 下载链接, 错误信息)
    static func checkForUpdates(completion: @escaping (Bool, String?, String?, String?) -> Void) {
        guard let url = URL(string: updateCheckURL) else {
            completion(false, nil, nil, "无效的更新检查地址")
            return
        }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github.v3+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, nil, nil, "网络请求失败: \(error.localizedDescription)")
                    return
                }

                guard let data = data else {
                    completion(false, nil, nil, "未收到数据")
                    return
                }

                do {
                    let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

                    guard let tagName = json?["tag_name"] as? String else {
                        completion(false, nil, nil, "无法解析版本信息")
                        return
                    }

                    // 移除版本号前的 'v' 前缀
                    let latestVersion = tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName

                    // 比较版本
                    let hasNewVersion = compareVersions(current: version, latest: latestVersion)

                    // 获取下载链接
                    let downloadURL = json?["html_url"] as? String ?? releasesURL

                    completion(hasNewVersion, latestVersion, downloadURL, nil)

                } catch {
                    completion(false, nil, nil, "解析数据失败: \(error.localizedDescription)")
                }
            }
        }.resume()
    }

    /// 比较版本号
    /// - Parameters:
    ///   - current: 当前版本
    ///   - latest: 最新版本
    /// - Returns: 是否有新版本
    private static func compareVersions(current: String, latest: String) -> Bool {
        let currentComponents = current.split(separator: ".").compactMap { Int($0) }
        let latestComponents = latest.split(separator: ".").compactMap { Int($0) }

        for i in 0..<max(currentComponents.count, latestComponents.count) {
            let currentValue = i < currentComponents.count ? currentComponents[i] : 0
            let latestValue = i < latestComponents.count ? latestComponents[i] : 0

            if latestValue > currentValue {
                return true
            } else if latestValue < currentValue {
                return false
            }
        }

        return false
    }

    // MARK: - 便捷方法

    /// 在浏览器中打开 GitHub 仓库
    static func openGitHub() {
        if let url = URL(string: githubURL) {
            NSWorkspace.shared.open(url)
        }
    }

    /// 在浏览器中打开 Issues 页面
    static func openIssues() {
        if let url = URL(string: issuesURL) {
            NSWorkspace.shared.open(url)
        }
    }

    /// 在浏览器中打开发布页面
    static func openReleases() {
        if let url = URL(string: releasesURL) {
            NSWorkspace.shared.open(url)
        }
    }
}
