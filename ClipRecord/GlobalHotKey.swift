//
//  GlobalHotKey.swift
//  ClipRecord
//
//  Created by Aaron on 11/27/26.
//

import Carbon.HIToolbox

/// 基于 Carbon RegisterEventHotKey 的全局快捷键：
/// 不需要辅助功能 / 输入监控权限，沙盒内外都可用。
final class GlobalHotKey {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let action: () -> Void

    /// - Parameters:
    ///   - keyCode: 虚拟键码，如 `UInt32(kVK_ANSI_V)`
    ///   - modifiers: Carbon 修饰键，如 `UInt32(cmdKey | shiftKey)`
    init(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) {
        self.action = action

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData in
            guard let userData else { return noErr }
            let me = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { me.action() }
            return noErr
        }, 1, &spec, selfPtr, &handlerRef)

        let id = EventHotKeyID(signature: OSType(0x434C4950), id: 1)   // 'CLIP'
        RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}
