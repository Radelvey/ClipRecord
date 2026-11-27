//
//  ClipRow.swift
//  ClipRecord
//
//  Created by Aaron on 11/27/26.
//

import SwiftUI

struct ClipRow: View {
    let item: ClipItem
    let store: ClipStore
    let onPreview: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            thumbnail
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 3) {
                content
                HStack(spacing: 4) {
                    if item.pinned {
                        Image(systemName: "pin.fill").foregroundStyle(.orange)
                    }
                    Text(item.date, style: .relative)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)

            if hovering {
                HStack(spacing: 6) {
                    actionButton("doc.on.doc", "复制") { store.copy(item) }
                    
                    actionButton(item.pinned ? "pin.slash" : "pin",
                                                     item.pinned ? "取消置顶" : "置顶") { store.togglePin(item) }
                    
                    actionButton("eye", "预览", action: onPreview)
                    if item.kind != .text {
                        actionButton("folder", "在 Finder 中显示") { store.reveal(item) }
                    }
                    actionButton("trash", "删除") { store.delete(item) }
                }
                .transition(.opacity)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.12), value: hovering)
        .onTapGesture(count: 2) {
            store.copy(item)
            NotificationCenter.default.post(name: .hideClipPanel, object: nil)
        }
    }

    private func actionButton(_ symbol: String, _ help: String,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol) }
            .buttonStyle(.borderless)
            .help(help)
    }

    @ViewBuilder private var content: some View {
        switch item.kind {
        case .text:
            Text(item.text ?? "").lineLimit(3)
        case .image:
            Text("图片").bold()
        case .file:
            ForEach(item.filePaths.prefix(3), id: \.self) { path in
                VStack(alignment: .leading, spacing: 0) {
                    Text((path as NSString).lastPathComponent).bold().lineLimit(1)
                    Text(path).font(.caption).foregroundStyle(.secondary)
                        .lineLimit(1).truncationMode(.middle)
                }
            }
            if item.filePaths.count > 3 {
                Text("… 共 \(item.filePaths.count) 个文件").font(.caption)
            }
        }
    }

    @ViewBuilder private var thumbnail: some View {
        switch item.kind {
        case .text:
            Image(systemName: "text.alignleft")
                .font(.title2).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.quaternary)
        case .image:
            if let url = store.imageURL(for: item), let img = NSImage(contentsOf: url) {
                Image(nsImage: img).resizable().scaledToFill()
            }
        case .file:
            if let path = item.filePaths.first {
                let url = URL(fileURLWithPath: path)
                if ["png", "jpg", "jpeg", "gif", "heic", "webp", "tiff"].contains(url.pathExtension.lowercased()),
                   let img = NSImage(contentsOf: url) {
                    Image(nsImage: img).resizable().scaledToFill()
                } else {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: path)).resizable().scaledToFit()
                }
            }
        }
    }
}
