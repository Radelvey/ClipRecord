//
//  AppDelegate.swift
//  ClipRecord
//
//  Created by Aaron on 11/27/26.
//

import AppKit
import ServiceManagement
import Carbon.HIToolbox

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var panelController: PanelController!
    private var hotKey: GlobalHotKey?
    private let loginItem = NSMenuItem()

    // ── 全局快捷键：想改就改这两行 ──────────────────────────
    // 默认 ⌃⌥V。其他例子：⌘⇧V → UInt32(cmdKey | shiftKey)
    private let hotKeyCode = UInt32(kVK_ANSI_V)
    private let hotKeyModifiers = UInt32(controlKey | optionKey)
    private let hotKeyLabel = "⌃⌥V"
    // ────────────────────────────────────────────────────────

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)      // 不在 Dock 显示（等同 LSUIElement）
        _ = ClipStore.shared                       // 启动即开始监听剪贴板
        panelController = PanelController()

        hotKey = GlobalHotKey(keyCode: hotKeyCode, modifiers: hotKeyModifiers) { [weak self] in
            Task { @MainActor in self?.panelController.toggle() }
        }
        setupStatusItem()
    }

    // MARK: 菜单栏图标

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "doc.on.clipboard",
                                           accessibilityDescription: "剪贴板历史")

        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(makeItem("显示剪贴板历史（\(hotKeyLabel)）", #selector(showPanel)))
        menu.addItem(.separator())
        menu.addItem(makeItem("清空历史(保留置顶)", #selector(clearAll)))
        menu.addItem(makeItem("重制窗口位置和大小", #selector(resetFrame)))
        loginItem.title = "开机自动启动"
        loginItem.action = #selector(toggleLogin)
        loginItem.target = self
        menu.addItem(loginItem)
        menu.addItem(.separator())
        menu.addItem(makeItem("退出", #selector(quit)))
        statusItem.menu = menu
    }

    private func makeItem(_ title: String, _ action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        return item
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    @objc private func showPanel() { panelController.show() }
    @objc private func clearAll() { ClipStore.shared.clearUnpinned() }
    @objc private func resetFrame() { panelController.resetFrame() }
    @objc private func quit() { NSApp.terminate(nil) }

    /// 仅在打包成 .app（Xcode / XcodeGen 方式）时有效；`swift run` 下会失败
    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSSound.beep()
        }
    }
}
