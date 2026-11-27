//
//  PanelController.swift
//  ClipRecord
//
//  Created by Aaron on 11/27/26.
//

import AppKit
import SwiftUI

extension Notification.Name {
    static let clipPanelDidShow = Notification.Name("clipPanelDidShow")
    static let hideClipPanel = Notification.Name("hideClipPanel")
    static let clipPanelCancel = Notification.Name("clipPanelCancel")   // 按下 Esc
}

/// 无边框浮动面板：能成为 key window（才能输入搜索），但不会成为 main window
final class ClipPanel: NSPanel {
    var onCancel: (() -> Void)?
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) { onCancel?() }   // Esc
}

@MainActor
final class PanelController {
    private let panel: ClipPanel
    private var observers: [NSObjectProtocol] = []

    private let defaultSize = NSSize(width: 480, height: 560)
    private let minSize = NSSize(width: 360, height: 320)
    private let frameKey = "ClipPanelFrame"

    init() {
        panel = ClipPanel(contentRect: NSRect(origin: .zero, size: defaultSize),
                          styleMask: [.borderless, .resizable],   // 拖边缘/角即可调整大小
                          backing: .buffered,
                          defer: false)
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true     // 按住空白处拖动位置
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.contentMinSize = minSize
        // 出现在当前桌面，也能盖在全屏 App 上
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let root = ContentView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        let hosting = NSHostingView(rootView: root)
        hosting.sizingOptions = []                   // 窗口大小由用户决定，不被 SwiftUI 内容反向约束
        panel.contentView = hosting
        panel.onCancel = { NotificationCenter.default.post(name: .clipPanelCancel, object: nil) }

        let nc = NotificationCenter.default
        // 失去焦点（点到别处）时自动隐藏
        observers.append(nc.addObserver(forName: NSWindow.didResignKeyNotification,
                                        object: panel, queue: .main) { [weak self] _ in
            DispatchQueue.main.async { self?.panel.orderOut(nil) }
        })
        // 移动 / 缩放后记录位置与大小
        for name in [NSWindow.didMoveNotification, NSWindow.didResizeNotification] {
            observers.append(nc.addObserver(forName: name, object: panel, queue: .main) { [weak self] _ in
                DispatchQueue.main.async { self?.saveFrame() }
            })
        }
        // 双击复制后由 ClipRow 请求关闭
        observers.append(nc.addObserver(forName: .hideClipPanel, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.hide() }
        })
    }

    func toggle() {
        if panel.isVisible && panel.isKeyWindow { hide() } else { show() }
    }

    func show() {
        if let saved = savedFrame() {
            panel.setFrame(saved, display: false)    // 恢复上次关闭时的位置和大小
        } else {
            centerOnMouseScreen()
        }
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        NotificationCenter.default.post(name: .clipPanelDidShow, object: nil)
    }

    func hide() {
        panel.orderOut(nil)
    }

    /// 菜单里的“重置窗口位置和大小”
    func resetFrame() {
        UserDefaults.standard.removeObject(forKey: frameKey)
        panel.setContentSize(defaultSize)
        centerOnMouseScreen()
    }

    // MARK: 位置 / 大小记忆

    private func saveFrame() {
        guard panel.isVisible else { return }
        UserDefaults.standard.set(NSStringFromRect(panel.frame), forKey: frameKey)
    }

    private func savedFrame() -> NSRect? {
        guard let str = UserDefaults.standard.string(forKey: frameKey) else { return nil }
        let r = NSRectFromString(str)
        guard r.width >= minSize.width, r.height >= minSize.height else { return nil }
        // 外接显示器拔掉等情况：保存的位置已不在任何屏幕内，就放弃，回到居中
        let onScreen = NSScreen.screens.contains { $0.visibleFrame.intersects(r.insetBy(dx: 40, dy: 40)) }
        return onScreen ? r : nil
    }

    private func centerOnMouseScreen() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let f = screen?.visibleFrame else { return }
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(x: f.midX - size.width / 2,
                                     y: f.midY - size.height / 2 + f.height * 0.08))
    }
}
