import SwiftUI

// MARK: - 共享小组件（骨架期占位卡 / 空态卡）

struct PlaceholderCard: View {
    let title: String
    let hint: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.headline)
            Text(hint).font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Theme.card)
        .cornerRadius(Radius.large)
    }
}

struct EmptyStateCard: View {
    /// Fluent 3D asset 名（`cur_*` / `acct_*`）—— **不再收 emoji 字符**
    var icon: String = "cur_receipt"
    var title: String = "还没有记录"
    var hint: String = "点右下角 + 记第一笔"

    /// asset 缺失时的兜底：从 curated 表反查（自定义图标不在表内则留空，只显示文字）
    private var fallback: String { CuratedIcons.item(icon)?.emoji ?? "" }

    var body: some View {
        VStack(spacing: 12) {
            CategoryIcon(asset: icon, fallback: fallback, size: 52)   // 空态是首屏唯一的东西，给大
                .accessibilityHidden(true)                            // 装饰
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Text(hint).font(.caption).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Theme.card)
        .cornerRadius(Radius.large)
        .accessibilityElement(children: .combine)
    }
}
