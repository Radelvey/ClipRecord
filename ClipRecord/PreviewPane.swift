//
//  PreviewPane.swift
//  ClipRecord
//
//  Created by Aaron on 11/27/26.
//

import SwiftUI
import QuickLookUI

/// 内嵌的 Quick Look 视图（PDF、Office、视频、音频、压缩包等都能预览）
struct QLView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> QLPreviewView {
        let v = QLPreviewView(frame: .zero, style: .normal)!
        v.autostarts = true
        v.previewItem = url as NSURL
        return v
    }

    func updateNSView(_ v: QLPreviewView, context: Context) {
        if (v.previewItem as? NSURL) != (url as NSURL) { v.previewItem = url as NSURL }
    }

    static func dismantleNSView(_ v: QLPreviewView, coordinator: ()) { v.close() }
}

/// 面板内的预览页：覆盖在列表之上，点“返回”或按 Esc 回到列表
struct PreviewPane: View {
    let item: ClipItem
    let store: ClipStore
    let onClose: () -> Void

    @State private var fileIndex = 0

    private var fileURLs: [URL] { item.filePaths.map { URL(fileURLWithPath: $0) } }

    private var title: String {
        switch item.kind {
        case .text: "文本"
        case .image: "图片"
        case .file: fileURLs.indices.contains(fileIndex) ? fileURLs[fileIndex].lastPathComponent : "文件"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button(action: onClose) { Label("返回", systemImage: "chevron.left") }
                    .buttonStyle(.borderless)
                Spacer()
                Text(title).font(.headline).lineLimit(1).truncationMode(.middle)
                Spacer()
                Button { store.copy(item) } label: { Image(systemName: "doc.on.doc") }
                    .buttonStyle(.borderless).help("复制")
                if item.kind != .text {
                    Button { store.reveal(item) } label: { Image(systemName: "folder") }
                        .buttonStyle(.borderless).help("在 Finder 中显示")
                }
            }
            .padding(12)

            Divider()

            if item.kind == .file, fileURLs.count > 1 {
                Picker("", selection: $fileIndex) {
                    ForEach(fileURLs.indices, id: \.self) { i in
                        Text(fileURLs[i].lastPathComponent).tag(i)
                    }
                }
                .labelsHidden()
                .padding(.horizontal, 12).padding(.top, 8)
            }

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(.regularMaterial)
    }

    @ViewBuilder private var content: some View {
        switch item.kind {
        case .text:
            ScrollView {
                Text(item.text ?? "")
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
        case .image:
            if let url = store.imageURL(for: item), let img = NSImage(contentsOf: url) {
                Image(nsImage: img).resizable().scaledToFit().padding(12)
            } else {
                missing
            }
        case .file:
            if fileURLs.indices.contains(fileIndex),
               FileManager.default.fileExists(atPath: fileURLs[fileIndex].path) {
                filePreview(fileURLs[fileIndex])
            } else {
                missing
            }
        }
    }

    @ViewBuilder private func filePreview(_ url: URL) -> some View {
        if ["png", "jpg", "jpeg", "gif", "heic", "webp", "tiff", "bmp"].contains(url.pathExtension.lowercased()),
           let img = NSImage(contentsOf: url) {
            Image(nsImage: img).resizable().scaledToFit().padding(12)
        } else {
            QLView(url: url).id(url)
        }
    }

    private var missing: some View {
        ContentUnavailableView("无法预览", systemImage: "questionmark.folder",
                               description: Text("文件已被移动、删除，或没有读取权限"))
    }
}
