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
    var icon: String = "🧾"
    var title: String = "还没有记录"
    var hint: String = "点右下角 + 记第一笔"

    var body: some View {
        VStack(spacing: 10) {
            Text(icon).font(.system(size: 44))
            Text(title).font(.subheadline).foregroundStyle(.secondary)
            Text(hint).font(.caption).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Theme.card)
        .cornerRadius(Radius.large)
    }
}
