# flowall - macOS 动态壁纸应用

一款简洁的 macOS 动态壁纸应用,支持视频壁纸播放,灵感来自 pap.er。

## 功能特性

### 核心功能
- ✅ 视频动态壁纸播放
- ✅ 静态帧提取(空间切换时显示)
- ✅ 多空间支持
- ✅ 状态栏菜单控制
- ✅ 可视化壁纸选择界面
- ✅ 自动循环播放
- ✅ 多屏幕独立壁纸支持

### 新增功能 (v2.0)
- ✅ **隐藏刘海屏**: 自动调整视频区域避开刘海屏
- ✅ **随机换壁纸**: 一键随机选择壁纸
- ✅ **自定义存储路径**: 支持自定义壁纸存储位置
- ✅ **导入本地壁纸**: 批量导入视频文件
- ✅ **同步所有桌面**: 自动同步壁纸到所有屏幕
- ✅ **Dock 显示控制**: 切换应用在 Dock 中的可见性
- ✅ **登录时启动**: 开机自动启动
- ✅ **语言选择**: 支持简体中文和英文

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

1. 点击状态栏的 "pap.er" 文本
2. 选择"设置"(快捷键: ⌘,)
3. 在设置界面中配置各项功能

### 快捷键

- `⌘+O` - 打开壁纸选择窗口
- `⌘+P` - 播放/暂停当前壁纸
- `⌘+,` - 打开设置
- `⌘+Q` - 退出应用

## 项目架构

```
flowall/
├── flowallApp.swift                    # 应用入口
├── AppDelegate.swift                    # 应用代理,核心协调器
├── StatusItemManager.swift              # 状态栏菜单
├── SettingsView.swift                   # 设置界面(NEW)
├── WallpaperSelectionView.swift         # 壁纸选择界面(SwiftUI)
├── VideoWallpaperManager.swift          # 动态视频壁纸管理
├── VideoFileManager.swift               # 文件管理
├── VideoProcessor.swift                 # 视频处理
└── WallpaperManager.swift               # 静态壁纸管理
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
针对带刘海的 MacBook Pro 机型,自动调整视频显示区域避开刘海部分。

### 2. 随机换壁纸
从视频库中随机选择一个视频作为壁纸,适合经常更换壁纸的用户。

### 3. 壁纸存储位置
- 默认路径: `~/Livewall`
- 可自定义到任意目录
- 实时显示库大小

### 4. 导入本地壁纸
- 支持多选视频文件
- 自动复制到壁纸库
- 支持格式: mp4, mov, m4v, mkv

### 5. 同步壁纸到所有桌面
开启后,选择的壁纸会自动应用到所有连接的显示器。

### 6. 在 Dock 显示图标
- 关闭: 纯菜单栏应用模式
- 开启: 在 Dock 中显示图标

### 7. 登录时启动
开机自动启动应用,无需手动打开。

### 8. 语言
- 简体中文
- English

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

查看 [CHANGELOG.md](CHANGELOG.md) 了解详细更新历史。

## 许可证

MIT License

## 致谢

- 参考项目: [thusvill/LiveWallpaperMacOS](https://github.com/thusvill/LiveWallpaperMacOS)
- UI 设计灵感: [pap.er](https://paper.meiyuan.in/)

## 截图

### 状态栏
状态栏显示 "pap.er" 文本,点击打开菜单。

### 设置界面
包含所有功能开关的设置界面,采用 SwiftUI 构建。

### 壁纸选择
网格视图展示所有可用壁纸,支持预览和快速应用。
