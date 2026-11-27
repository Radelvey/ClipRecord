//
//  ClipStore.swift
//  ClipRecord
//
//  Created by Aaron on 11/27/26.
//

import AppKit
import Observation

@MainActor @Observable
final class ClipStore {
    static let shared = ClipStore()

    var items: [ClipItem] = []

    @ObservationIgnored private let pb = NSPasteboard.general
    @ObservationIgnored private var lastChange: Int
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private let imagesDir: URL
    @ObservationIgnored private let jsonURL: URL
    @ObservationIgnored private let maxItems = 500

    private init() {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ClipHistory", isDirectory: true)
        imagesDir = base.appendingPathComponent("images", isDirectory: true)
        jsonURL = base.appendingPathComponent("items.json")
        try? FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
        lastChange = pb.changeCount
        load()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
    }

    // MARK: 监听

    private func poll() {
        guard pb.changeCount != lastChange else { return }
        lastChange = pb.changeCount

        // 跳过密码管理器标记的敏感内容
        let concealed = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
        if pb.types?.contains(concealed) == true { return }

        guard let item = readPasteboard() else { return }
        if let first = items.first, first.kind == item.kind,
           item.kind != .image, first.text == item.text, first.filePaths == item.filePaths { return }

        items.insert(item, at: 0)
        // 超出上限时只淘汰最旧的「未置顶」记录
        let unpinned = items.filter { !$0.pinned }
        if unpinned.count > maxItems {
            let overflow = unpinned.suffix(unpinned.count - maxItems)
            overflow.forEach(removeImageFile)
            let ids = Set(overflow.map(\.id))
            items.removeAll { ids.contains($0.id) }
        }
        save()
    }

    private func readPasteboard() -> ClipItem? {
        // 1. 文件（Finder 复制文件时同时带文本，必须最先判断）
        if let urls = pb.readObjects(forClasses: [NSURL.self],
                                     options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !urls.isEmpty {
            return ClipItem(kind: .file, filePaths: urls.map(\.path))
        }
        // 2. 文本
        if let s = pb.string(forType: .string),
           !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ClipItem(kind: .text, text: s)
        }
        // 3. 图片
        if let img = NSImage(pasteboard: pb), let png = img.pngData() {
            let name = UUID().uuidString + ".png"
            do {
                try png.write(to: imagesDir.appendingPathComponent(name))
                return ClipItem(kind: .image, imageFile: name)
            } catch { return nil }
        }
        return nil
    }

    // MARK: 操作

    func imageURL(for item: ClipItem) -> URL? {
        item.imageFile.map { imagesDir.appendingPathComponent($0) }
    }

    func copy(_ item: ClipItem) {
        pb.clearContents()
        switch item.kind {
        case .text:
            pb.setString(item.text ?? "", forType: .string)
        case .image:
            if let url = imageURL(for: item), let img = NSImage(contentsOf: url) {
                pb.writeObjects([img])
            }
        case .file:
            pb.writeObjects(item.filePaths.map { URL(fileURLWithPath: $0) as NSURL })
        }
        lastChange = pb.changeCount   // 不把自己写入的内容再记一遍
    }

    func previewURL(for item: ClipItem) -> URL? {
        switch item.kind {
        case .text:
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("clip-\(item.id.uuidString).txt")
            try? (item.text ?? "").write(to: url, atomically: true, encoding: .utf8)
            return url
        case .image:
            return imageURL(for: item)
        case .file:
            return item.filePaths.map { URL(fileURLWithPath: $0) }
                .first { FileManager.default.fileExists(atPath: $0.path) }
        }
    }

    func reveal(_ item: ClipItem) {
        switch item.kind {
        case .text: break
        case .image:
            if let url = imageURL(for: item) { NSWorkspace.shared.activateFileViewerSelecting([url]) }
        case .file:
            let urls = item.filePaths.map { URL(fileURLWithPath: $0) }
                .filter { FileManager.default.fileExists(atPath: $0.path) }
            if !urls.isEmpty { NSWorkspace.shared.activateFileViewerSelecting(urls) }
        }
    }

    func delete(_ item: ClipItem) {
        removeImageFile(item)
        items.removeAll { $0.id == item.id }
        save()
    }
    
    var hasUnpinned: Bool { items.contains { !$0.pinned } }

    /// 一键清空：置顶项会被保留，只能单独删除
    func clearUnpinned() {
        items.filter { !$0.pinned }.forEach(removeImageFile)
        items.removeAll { !$0.pinned }
        save()
    }

    func togglePin(_ item: ClipItem) {
        guard let i = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[i].pinned.toggle()
        save()
    }

    func clearAll() {
        items.forEach(removeImageFile)
        items.removeAll()
        save()
    }

    // MARK: 持久化

    private func removeImageFile(_ item: ClipItem) {
        if let url = imageURL(for: item) { try? FileManager.default.removeItem(at: url) }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) { try? data.write(to: jsonURL) }
    }

    private func load() {
        guard let data = try? Data(contentsOf: jsonURL),
              let list = try? JSONDecoder().decode([ClipItem].self, from: data) else { return }
        items = list
    }
}
