import SwiftUI
import QuickLook

@main struct MyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    var body: some Scene {
//        WindowGroup {
//            ContentView()
//        }
        Settings { EmptyView() }   // App 协议要求至少一个 Scene
    }
}

struct ContentView: View {
    @State private var store = ClipStore.shared
    @State private var query = ""
    @State private var previewItem: ClipItem?
    @FocusState private var searchFocused: Bool

    private var filtered: [ClipItem] {
        // 置顶项排在最前，其余保持时间倒序
        let sorted = store.items.filter(\.pinned) + store.items.filter { !$0.pinned }
        guard !query.isEmpty else { return sorted }
        return sorted.filter {
            ($0.text ?? "").localizedCaseInsensitiveContains(query)
            || $0.filePaths.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶部拖动条：按住拖动整个面板
            ZStack {
                WindowDragArea()
                Capsule().fill(.tertiary).frame(width: 36, height: 4)
            }
            .frame(height: 16)
            .help("按住拖动")
            
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("搜索剪贴板历史", text: $query)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                }
                Button { store.clearUnpinned() } label: { Image(systemName: "trash") }
                    .buttonStyle(.borderless)
                    .help("清空历史（保留置顶）")
                    .disabled(!store.hasUnpinned)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
            .background(WindowDragArea())   // 搜索栏的空白处一可以拖动

            Divider()

            List(filtered) { item in
                ClipRow(item: item, store: store) {
                    withAnimation(.easeOut(duration: 0.15)) { previewItem = item }
                }
            }
            .scrollContentBackground(.hidden)
            .overlay {
                if store.items.isEmpty {
                    ContentUnavailableView("还没有记录", systemImage: "doc.on.clipboard",
                                           description: Text("复制文本、图片或文件后会出现在这里"))
                }
            }
        }
        // 预览页覆盖整个面板
        .overlay {
            if let item = previewItem {
                PreviewPane(item: item, store: store) {
                    withAnimation(.easeOut(duration: 0.15)) { previewItem = nil }
                }
                .transition(.move(edge: .trailing))
            }
        }
        // 每次面板弹出：回到列表、清空搜索并聚焦
        .onReceive(NotificationCenter.default.publisher(for: .clipPanelDidShow)) { _ in
            previewItem = nil
            query = ""
            searchFocused = true
        }
        // Esc：先关预览，再关面板
        .onReceive(NotificationCenter.default.publisher(for: .clipPanelCancel)) { _ in
            if previewItem != nil {
                withAnimation(.easeOut(duration: 0.15)) { previewItem = nil }
            } else {
                NotificationCenter.default.post(name: .hideClipPanel, object: nil)
            }
        }
    }
}
