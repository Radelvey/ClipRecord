//
//  ClipItem.swift
//  ClipRecord
//
//  Created by Aaron on 11/27/26.
//

import AppKit

enum ClipKind: String, Codable { case text, image, file }

struct ClipItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var kind: ClipKind
    var text: String? = nil
    var imageFile: String? = nil      // Application Support/ClipHistory/images 下的文件名
    var filePaths: [String] = []      // 文件类型：原始路径
    var pinned = false                // 置顶: 不会被「清空」和自动淘汰删除
    var date = Date()
}

// 放在 extension 里以保留自动生成的 memberwise init; 旧数据没有 pinned 字段时会按照 false 处理
extension ClipItem {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        kind = try c.decode(ClipKind.self, forKey: .kind)
        text = try c.decodeIfPresent(String.self, forKey: .text)
        imageFile = try c.decodeIfPresent(String.self, forKey: .imageFile)
        filePaths = try c.decodeIfPresent([String].self, forKey: .filePaths) ?? []
        pinned = try c.decodeIfPresent(Bool.self, forKey: .pinned) ?? false
        date = try c.decode(Date.self, forKey: .date)
    }
}

extension NSImage {
    func pngData() -> Data? {
        guard let tiff = tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}
