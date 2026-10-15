import SwiftUI

// MARK: - 共享小组件（骨架期占位卡 / 空态卡）

struct PlaceholderCard: View {
    let title: String
    let hint: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).scaledFont(.title)
            Text(hint).scaledFont(.sm).foregroundStyle(.secondary)
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

    var body: some View {
        VStack(spacing: 12) {
            CategoryIcon(asset: icon, size: 52)   // 空态是首屏唯一的东西，给大
                .accessibilityHidden(true)                            // 装饰
            Text(title).scaledFont(.body).foregroundStyle(.secondary)
            Text(hint).scaledFont(.sm).foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .background(Theme.card)
        .cornerRadius(Radius.large)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - 自绘设置卡（2026-10-15 D2：设置类页面从系统 List / Form 改全自绘）
//
// 全 App 的容器语言统一为 **`ScrollView` + `VStack` + 白卡**（`Theme.card` + `Radius.large`）。
// `List` / `Form` 是第二、第三种容器哲学（系统分组底色、系统行底、系统分隔线、系统缩进），
// 与另外 7 个业务页对不上 —— 这里把「表单型卡片」的三件套收敛成共享构件，三页共用。
//
// 用法：
// ```
// VStack(spacing: Radius.cardSpacing) {
//     CardSectionTitle(text: "记账")
//     CardSection {
//         CardRow("名称") { TextField(...) }
//         CardDivider()
//         CardRow("金额") { ... }
//     }
//     CardFooterNote(text: "说明文字")
// }
// ```

/// 表单卡片容器（白卡 + 大圆角；行之间用 `CardDivider` 分隔）
struct CardSection<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) { content }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Theme.card)
            .cornerRadius(Radius.large)
    }
}

/// 卡内一行：左标签 + 右内容
struct CardRow<Content: View>: View {
    private let label: String
    private let content: Content

    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 8) {
            Text(label).scaledFont(.body, weight: .medium)
            Spacer(minLength: 8)
            content
        }
        .padding(.vertical, 10)
    }
}

/// 卡内分隔线（极细，与系统分隔线解耦）
struct CardDivider: View {
    var body: some View {
        Rectangle().fill(Theme.hairline).frame(height: 1)
    }
}

/// 卡片上方的分组标题 —— 替代 `List` 的 `Section` header
struct CardSectionTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .scaledFont(.sm, weight: .semibold)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }
}

/// 卡片下方的说明文字 —— 替代 `List` 的 `Section` footer
struct CardFooterNote: View {
    let text: String

    var body: some View {
        Text(text)
            .scaledFont(.xs)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }
}
