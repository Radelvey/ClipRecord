# ClipHistory

macOS 15+ SwiftUI 菜单栏剪贴板历史：记录文本 / 图片 / 文件。

- 菜单栏图标常驻（无 Dock 图标），菜单：显示历史 / 清空 / 开机自启 / 退出
- 全局快捷键 **⌃⌥V** 呼出 / 隐藏浮动面板（改键见 AppDelegate.swift 顶部两行常量）
- 面板可拖动（按住顶部拖动条或搜索栏空白处）、可缩放（拖边缘/角）；关闭后下次打开恢复上次的位置和大小；菜单里可重置
- 面板：搜索框自动聚焦；Esc 或点击别处关闭；双击一条 = 复制并关闭
- 置顶：悬停点图钉按钮；置顶项排在最前，不会被一键清空或自动淘汰，只能单独删除
- 悬停每一行：复制、预览（面板内嵌：文本/图片原生显示，其他文件用 Quick Look 视图）、在 Finder 中显示、删除

## 运行（任选其一）

**A. Xcode 直接打开 Package**：File → Open… 选本目录，目标 My Mac，⌘R
**B. 生成标准 .xcodeproj**：`brew install xcodegen && xcodegen && open ClipHistory.xcodeproj`
**C. 命令行**：`swift run`

> “开机自动启动” 只在打包成 .app（方式 B）时有效。
> App Sandbox 已关闭（否则读不到被复制文件的缩略图/预览）。

## 数据位置
~/Library/Application Support/ClipHistory/（items.json + images/）

## 结构
- ClipHistoryApp.swift   入口（仅挂载 AppDelegate）
- AppDelegate.swift      状态栏图标与菜单、注册全局快捷键、开机启动
- GlobalHotKey.swift     Carbon 全局快捷键封装（无需额外权限）
- PanelController.swift  无边框浮动面板：定位、显示/隐藏、失焦自动关闭
- ContentView.swift      搜索 + 列表 + 预览页切换
- PreviewPane.swift      内嵌预览页（含 QLPreviewView 封装）
- ClipRow.swift          行视图与悬停按钮
- ClipStore.swift        剪贴板轮询、持久化、复制/预览/Finder 定位
- ClipItem.swift         数据模型
