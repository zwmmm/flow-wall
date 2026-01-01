# Flowall - macOS 动态壁纸应用

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14.0+-blue" alt="macOS 14.0+">
  <img src="https://img.shields.io/badge/Swift-5.9-orange" alt="Swift 5.9">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="MIT License">
</p>

一款简洁优雅的 macOS 动态壁纸应用,支持视频壁纸播放,灵感来自 pap.er。

## ✨ 功能特性

### 核心功能
- ✅ **视频动态壁纸** - 支持 mp4, mov, m4v, mkv 格式
- ✅ **多屏幕支持** - 每个显示器独立管理壁纸
- ✅ **空间切换优化** - 静态帧提取,切换流畅
- ✅ **刘海屏适配** - 自动调整视频区域避开刘海
- ✅ **自动循环播放** - 无缝循环,体验流畅

### 用户体验
- ✅ **美观的设置界面** - 现代化 SwiftUI 设计
- ✅ **状态栏控制** - 便捷的菜单栏操作
- ✅ **登录时启动** - 开机自动运行
- ✅ **随机换壁纸** - 一键随机选择
- ✅ **在线壁纸库** - 丰富的在线资源

### 管理功能
- ✅ **自定义存储路径** - 灵活的文件管理
- ✅ **批量导入** - 快速添加本地视频
- ✅ **缩略图缓存** - 快速预览加载
- ✅ **同步所有桌面** - 一键同步所有屏幕

### 开发者友好
- ✅ **版本管理系统** - 集中式版本信息管理
- ✅ **更新检查** - 基于 GitHub Releases API
- ✅ **清晰的代码架构** - 遵循 SOLID 原则
- ✅ **完善的文档** - 详细的集成指南

## 系统要求

- macOS 14.0+
- Xcode 15.0+
- 刘海屏功能需要 macOS 12.0+

## 安装步骤

### 1. 构建项目

```bash
cd flowall.xcodeproj
open flowall.xcodeproj
```

在 Xcode 中点击运行(⌘+R)

## 使用方法

### 添加壁纸

将视频文件(支持 mp4, mov, m4v, mkv)放入 `~/Livewall` 目录:

```bash
mkdir ~/Livewall
cp /path/to/your/video.mp4 ~/Livewall/
```

或者通过设置界面的"导入本地壁纸"功能批量导入。

### 设置壁纸

1. 点击状态栏的 "pap.er" 文本
2. 选择"选择壁纸..."或直接从菜单中选择视频
3. 壁纸将自动应用到当前屏幕

### 打开设置

1. 点击状态栏的应用图标
2. 选择右键菜单"设置"
3. 查看和配置各项功能

**设置界面包含:**
- 📱 **应用信息** - 查看版本号和应用说明
- ⚙️ **功能配置** - 刘海屏隐藏、文件夹管理、启动设置
- 🔗 **支持链接** - GitHub、问题反馈、检查更新
- 📊 **版权信息** - 底部版权声明

### 快捷键

- `⌘+O` - 打开壁纸选择窗口
- `⌘+P` - 播放/暂停当前壁纸
- `⌘+,` - 打开设置
- `⌘+Q` - 退出应用

## 项目架构

```
flowall/
├── FlowWallApp.swift                 # 应用入口
├── AppDelegate.swift                 # 应用代理,核心协调器
├── AppConstants.swift                # 应用常量统一管理
├── AppVersion.swift                  # 版本管理和更新检查(NEW)
├── StatusItemManager.swift           # 状态栏菜单管理
├── SettingsView.swift                # 设置界面(重构优化)
├── WallpaperPanelView.swift          # 壁纸面板视图
├── LocalWallpaperListView.swift      # 本地壁纸列表
├── OnlineWallpaperListView.swift     # 在线壁纸列表
├── VideoWallpaperManager.swift       # 动态视频壁纸管理
├── VideoFileManager.swift            # 文件管理和缓存
├── VideoPlayerPool.swift             # 视频播放器池
├── OnlineWallpaperAPIClient.swift    # 在线 API 客户端
└── WallpaperAPIModels.swift          # API 数据模型
```

## 核心技术

### 双层架构

1. **静态层**: 使用 AppleScript 设置系统壁纸
2. **动态层**: 使用 AVPlayer 播放视频窗口

### 窗口层级控制

- 使用 `kCGDesktopWindowLevel - 1` 确保视频位于桌面图标下方
- 配置 `ignoresMouseEvents = true` 避免干扰用户交互

### 多屏幕支持

- 每个屏幕独立管理壁纸
- 支持单独控制或同步所有屏幕
- 自动适配屏幕分辨率变化

### 刘海屏适配

- 检测 `NSScreen.safeAreaInsets`
- 自动调整视频显示区域
- 可选开启/关闭

### 数据持久化

使用 `UserDefaults` 存储:
- 每屏幕的壁纸设置
- 用户偏好设置
- 自定义路径配置

## 设置功能详解

### 1. 隐藏刘海屏
针对带刘海的 MacBook Pro 机型,自动调整视频显示区域避开刘海部分,提供更好的视觉体验。

### 2. 壁纸文件夹
- **默认路径**: `~/Livewall`
- **自定义路径**: 可更改到任意目录
- **快速访问**: 一键在访达中打开文件夹

### 3. 登录时启动
开启后应用会在开机时自动启动,无需手动打开。使用 macOS 13+ 的现代登录项 API。

### 4. 检查更新
- **手动检查**: 点击"检查"按钮
- **自动通知**: 发现新版本时弹窗提示
- **版本比较**: 基于语义化版本号智能比较
- **一键跳转**: 自动打开 GitHub Release 页面下载

### 5. GitHub 仓库
查看项目源代码、Star 支持项目、了解最新开发动态。

### 6. 问题反馈
通过 GitHub Issues 报告 Bug、提出功能建议或改进意见。我们欢迎所有反馈!

## 开发说明

### 授权配置

应用需要以下权限(已在 entitlements 中配置):

- 文件读写访问
- Apple Events(用于设置壁纸)
- 网络访问

### 调试

运行应用后,查看 Console 输出了解详细信息:

- 视频加载状态
- 壁纸设置结果
- 屏幕变化事件

### 编程原则

本项目严格遵循:
- **KISS**: 简单直观的代码和设计
- **YAGNI**: 只实现必要的功能
- **DRY**: 避免代码重复
- **SOLID**: 单一职责,开放封闭,依赖倒置

## 更新日志

### v1.0.0 (2026-01-01)

**新增功能:**
- ✨ 全新设计的设置界面
- ✨ 版本管理系统 (AppVersion)
- ✨ 手动检查更新功能
- ✨ GitHub 和 Issues 快速链接
- ✨ 完善的关于页面

**优化改进:**
- 🎨 更专业的 UI 设计
- 📝 重构设置页面代码
- 🔧 优化常量管理
- 📚 新增 Sparkle 集成文档

**代码质量:**
- ♻️ 遵循 SOLID 原则
- 📖 改进代码注释
- 🏗️ 更清晰的架构

查看完整更新历史: [CHANGELOG.md](CHANGELOG.md)

## 许可证

MIT License

## 致谢

- 参考项目: [thusvill/LiveWallpaperMacOS](https://github.com/thusvill/LiveWallpaperMacOS)
- UI 设计灵感: [pap.er](https://paper.meiyuan.in/)

## 支持项目

如果你喜欢这个项目,请考虑:

- ⭐ 给项目点个 Star
- 🐛 [报告 Bug](https://github.com/zwmmm/flow-wall/issues)
- 💡 [提出新功能](https://github.com/zwmmm/flow-wall/issues)
- 🔀 提交 Pull Request

## 路线图

- [ ] 集成 Sparkle 自动更新框架(详见 [SPARKLE_INTEGRATION.md](SPARKLE_INTEGRATION.md))
- [ ] 支持更多视频格式
- [ ] 壁纸效果(模糊、亮度调节等)
- [ ] 预设壁纸包
- [ ] 社区壁纸分享

## 截图

### 状态栏
状态栏显示 "pap.er" 文本,点击打开菜单。

### 设置界面
包含所有功能开关的设置界面,采用 SwiftUI 构建。

### 壁纸选择
网格视图展示所有可用壁纸,支持预览和快速应用。
