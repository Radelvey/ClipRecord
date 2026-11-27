//
//  WindowDragArea.swift
//  ClipRecord
//
//  Created by Aaron on 11/27/26.
//

import SwiftUI
import AppKit

/// 放在 SwiftUI 视图背后，让该区域的空白处可以按住拖动整个窗口。
/// （List、Material 等会吞掉鼠标事件，单靠 isMovableByWindowBackground 不可靠。）
struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    final class DragView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }
        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }
}
