import SwiftUI
import SwiftData

// MARK: - 固定支出图标（复用已有 Fluent 3D 贴图，asset 名即 `sub_*`）
//
// 说明：`FixedExpense.emoji` 这个字段名没改（改字段名会破坏 SwiftData 轻量迁移），
// 但**内容语义已扩展** —— 新写入的是 `sub_*` asset 名；老数据里存的裸 emoji 字符
// 由 `CuratedIcons.asset(forEmoji:)` 反查回 asset。所以无需 schema 迁移。
// （2026-10-15：`CategoryIcon` 的 emoji 兜底出口已删，查不到的语义渲染灰底占位。）

struct FixedExpenseIconDef: Identifiable {
    let asset: String
    let emoji: String
    let name: String
    var id: String { asset }
}

enum FixedExpenseIcon {
    static let all: [FixedExpenseIconDef] = [
        .init(asset: "sub_rent",         emoji: "🏠", name: "房租"),
        .init(asset: "sub_subscription", emoji: "📺", name: "订阅会员"),
        .init(asset: "sub_utility",      emoji: "💡", name: "水电燃气"),
        .init(asset: "sub_commute",      emoji: "🚇", name: "通勤"),
        .init(asset: "sub_digital",      emoji: "📱", name: "手机宽带"),
        .init(asset: "sub_fitness",      emoji: "🏋️", name: "健身"),
        .init(asset: "sub_home",         emoji: "🛋️", name: "家居"),
        .init(asset: "sub_medical",      emoji: "💊", name: "保险医疗"),
        .init(asset: "sub_fun",          emoji: "🎮", name: "娱乐"),
        .init(asset: "sub_transport",    emoji: "✈️", name: "出行"),
        .init(asset: "sub_repay",        emoji: "💳", name: "还款分期"),
        .init(asset: "sub_ticket",       emoji: "🎫", name: "票券"),
    ]

    /// 存进 `FixedExpense.emoji` 的值 → asset 名（找不到返回 nil，渲染灰底占位）
    ///
    /// 三种形态兼容：① 新数据 = `sub_*` asset 名；② `cur_*`（预留：将来这套也可能被选中）；
    /// ③ 老数据 = 裸 emoji 字符（2026-10-11 之前写入的）→ 反查 curated 表。
    /// 空串（理论上不会出现）退回 Fluent 日历，不再用 iOS emoji。
    static func render(_ stored: String) -> String? {
        if let hit = all.first(where: { $0.asset == stored }) {
            return hit.asset
        }
        if let item = CuratedIcons.item(stored) {
            return item.asset
        }
        if stored.isEmpty {
            return "cur_tear_off_calendar"
        }
        return CuratedIcons.asset(forEmoji: stored)
    }
}

/// 固定支出 / 订阅（独立模块，方案 §12 D17）
///
/// 房租、会员这类「每月固定扣、永远不结束」的支出 —— **它不是负债**：
/// 不进「待还总额」、没有期数、不会还完；但会扣掉本月可支配。
/// 2026-10-11：与卡包改造对齐 —— 去掉绿重卡（改纯文本汇总行）、图标换 Fluent 3D、
/// 每行加可见的编辑入口；新增/编辑 sheet 重做成建户页那套（固定头部 + 卡片式表单）。
struct FixedExpenseView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FixedExpense.sortOrder) private var items: [FixedExpense]

    @State private var showAdd = false
    @State private var editing: FixedExpense?

    private let ciArgs = ProcessInfo.processInfo.arguments

    private var monthlyTotal: Decimal { items.reduce(Decimal(0)) { $0 + $1.amount } }

    var body: some View {
        ScrollView {
            VStack(spacing: Radius.cardSpacing) {
                summaryRow
                notice

                if items.isEmpty {
                    EmptyStateCard(icon: "cur_tear_off_calendar", title: "还没有固定支出",
                                   hint: "添加房租、会员等每月固定扣款")
                } else {
                    listCard
                }

                addButton
            }
            .padding(.horizontal, Radius.pagePadding)
            .padding(.top, 6)
            .padding(.bottom, 40)
        }
        .background(Theme.bg)
        .navigationTitle("固定支出 / 订阅")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Haptics.tap(); showAdd = true } label: {
                    Image(systemName: "plus").scaledFont(.title, weight: .semibold)
                }
                .accessibilityLabel("添加固定支出")
            }
        }
        .sheet(isPresented: $showAdd) {
            FixedExpenseSheet()
                .presentationDetents([.fraction(0.68), .large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(item: $editing) { item in
            FixedExpenseSheet(editing: item)
                .presentationDetents([.fraction(0.68), .large])
                .presentationDragIndicator(.hidden)
        }
        .onAppear {
            // CI 截图钩子：直接展开「添加固定支出」sheet
            if ciArgs.contains("-ci-open-fixed-add") { showAdd = true }
        }
    }

    // MARK: 汇总行（纯文本 —— 与资产页净资产行同构，不再用绿重卡）

    private var summaryRow: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("每月固定合计").scaledFont(.sm).foregroundStyle(.secondary)
            Text("¥ " + Money.string(dec(monthlyTotal)))
                .scaledFont(.xl, weight: .heavy, design: .rounded)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text("\(items.count) 项 · 每月自动扣，不累计成欠款")
                .scaledFont(.xs).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 2)
    }

    private var notice: some View {
        Text("这些是「每月固定扣的持续支出」，不是负债 —— 所以不叫待还、也不会还完；但它们照样会扣掉你的本月可支配。")
            .scaledFont(.xs)
            .foregroundStyle(Theme.blueText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(hex: 0xEAF1FE))
            .cornerRadius(Radius.medium)
    }

    // MARK: 列表（一个白卡容器 + 分隔线，与账户组同构）

    private var listCard: some View {
        VStack(spacing: 0) {
            ForEach(items.indices, id: \.self) { idx in
                row(items[idx], divider: idx > 0)
            }
        }
        .background(Theme.card)
        .cornerRadius(Radius.large)
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }

    private func row(_ item: FixedExpense, divider: Bool) -> some View {
        let icon = FixedExpenseIcon.render(item.emoji)
        return Button { Haptics.tap(); editing = item } label: {
            HStack(spacing: 12) {
                CategoryIcon(asset: icon, size: 24)
                    .frame(width: 40, height: 40)
                    .background(Theme.iconBg)
                    .cornerRadius(12)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.name).scaledFont(.body, weight: .semibold).foregroundStyle(.primary)
                    Text("每月 \(item.dueDay) 日扣款").scaledFont(.xs).foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                Text("¥" + Money.string(dec(item.amount)))
                    .scaledFont(.body, weight: .bold).monospacedDigit()
                    .foregroundStyle(.primary)

                // 可见的编辑入口（原先只能靠"点这一行"或长按，界面上毫无提示）
                Text("›").scaledFont(.title).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
            .overlay(alignment: .top) {
                if divider {
                    Rectangle().fill(Theme.hairline).frame(height: 0.5)
                }
            }
        }
        .buttonStyle(PressableButtonStyle(scale: 0.98))
        .accessibilityHint("打开编辑")
        .contextMenu {
            Button { Haptics.tap(); editing = item } label: {
                Label("编辑", systemImage: "pencil")
            }
            Button(role: .destructive) {
                Haptics.tap()
                modelContext.delete(item)
                try? modelContext.save()
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }

    private var addButton: some View {
        Button { Haptics.tap(); showAdd = true } label: {
            Text("＋ 添加固定支出")
                .scaledFont(.body, weight: .semibold)
                .foregroundStyle(Theme.greenText)
                .frame(maxWidth: .infinity).padding(.vertical, 15)
                .background(Theme.greenSoft).cornerRadius(14)
        }
        .buttonStyle(PressableButtonStyle(scale: 0.985))
        .padding(.top, 4)
    }

    private func dec(_ d: Decimal) -> Double { NSDecimalNumber(decimal: d).doubleValue }
}

// MARK: - 新增 / 编辑固定支出（2026-10-11 对齐建户页那套：固定头部 + 卡片式表单）

struct FixedExpenseSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var editing: FixedExpense?

    init(editing: FixedExpense? = nil) { self.editing = editing }

    @State private var name = ""
    @State private var amountStr = ""
    @State private var dueDay = 1
    @State private var iconAsset = "sub_rent"

    private let iconColumns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 6)

    private var amount: Decimal { Decimal(string: amountStr) ?? 0 }
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && amount > 0
    }

    var body: some View {
        VStack(spacing: 0) {
            // ⚠️ 把手与头部必须在 ScrollView **外面** —— 放里面会跟着内容滚走
            SheetGrabber()
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    iconSection
                    formSection
                    if editing != nil { deleteSection }
                }
                .padding(.horizontal, Radius.pagePadding)
                .padding(.bottom, 34)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.bg)
        .onAppear(perform: prefill)
    }

    // MARK: 头部（取消 / 标题 / 保存 —— 与建户页一致）

    private var header: some View {
        HStack {
            Button {
                Haptics.tap()
                dismiss()
            } label: {
                Text("取消").scaledFont(.body).foregroundStyle(.secondary)
            }
            .buttonStyle(PressableButtonStyle(scale: 0.96))
            .accessibilityLabel("取消")

            Spacer()
            Text(editing == nil ? "添加固定支出" : "编辑固定支出")
                .scaledFont(.title, weight: .bold)
            Spacer()

            Button {
                Haptics.success()
                save()
                dismiss()
            } label: {
                Text("保存")
                    .scaledFont(.body, weight: .semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .green3D(enabled: canSave, capsule: true)
            }
            .buttonStyle(PressableButtonStyle(scale: 0.95))
            .disabled(!canSave)
        }
        .padding(.horizontal, Radius.pagePadding)
        .padding(.top, 6)
        .padding(.bottom, 6)
    }

    // MARK: 图标（Fluent 3D 网格）

    private var iconSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("图标").scaledFont(.sm, weight: .semibold).foregroundStyle(.secondary)
            LazyVGrid(columns: iconColumns, spacing: 12) {
                ForEach(FixedExpenseIcon.all) { ic in
                    iconCell(ic)
                }
            }
        }
    }

    private func iconCell(_ ic: FixedExpenseIconDef) -> some View {
        let selected = iconAsset == ic.asset
        return Button {
            Haptics.tap()
            iconAsset = ic.asset
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(selected ? Theme.greenSoft : Theme.card)
                    .frame(height: 48)
                CategoryIcon(asset: ic.asset, size: 26)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(selected ? Theme.green : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(PressableButtonStyle(scale: 0.94))
        .accessibilityLabel(ic.name)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: 表单（卡片式 + 分隔线）

    private var formSection: some View {
        VStack(spacing: 0) {
            row("名称") {
                TextField("房租 / 视频会员", text: $name)
                    .scaledFont(.body, weight: .semibold)
                    .multilineTextAlignment(.trailing)
            }
            divider
            row("每月金额") {
                HStack(spacing: 4) {
                    Text("¥").scaledFont(.body, weight: .semibold).foregroundStyle(.secondary)
                    TextField("如 1230.50", text: $amountStr)
                        .keyboardType(.decimalPad)
                        .scaledFont(.body, weight: .bold)
                        .multilineTextAlignment(.trailing)
                        .monospacedDigit()
                }
            }
            divider
            row("每月扣款日") {
                Picker("", selection: $dueDay) {
                    ForEach(1...31, id: \.self) { Text("\($0) 日").tag($0) }
                }
                .pickerStyle(.menu)
                .tint(.primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Theme.card)
        .cornerRadius(Radius.large)
    }

    private func row<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 8) {
            Text(label).scaledFont(.body, weight: .medium)
            Spacer(minLength: 8)
            content()
        }
        .padding(.vertical, 10)
    }

    private var divider: some View {
        Rectangle().fill(Theme.hairline).frame(height: 1)
    }

    // MARK: 删除（编辑模式）

    private var deleteSection: some View {
        Button {
            if let item = editing {
                Haptics.tap()
                modelContext.delete(item)
                try? modelContext.save()
                dismiss()
            }
        } label: {
            Text("删除这项")
                .scaledFont(.body, weight: .semibold)
                .foregroundStyle(Theme.redText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(Theme.card)
                .cornerRadius(Radius.medium)
        }
        .buttonStyle(PressableButtonStyle(scale: 0.97))
    }

    // MARK: 预填 / 保存

    private func prefill() {
        guard let item = editing else { return }
        name = item.name
        amountStr = NSDecimalNumber(decimal: item.amount).stringValue
        dueDay = item.dueDay
        // 老数据可能是裸 emoji（找不到对应 asset）→ 保持原值，保存时原样写回
        if FixedExpenseIcon.all.contains(where: { $0.asset == item.emoji }) {
            iconAsset = item.emoji
        } else if let hit = FixedExpenseIcon.all.first(where: { $0.emoji == item.emoji }) {
            iconAsset = hit.asset
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let item = editing {
            item.name = trimmed
            item.amount = amount
            item.dueDay = dueDay
            item.emoji = iconAsset
        } else {
            let order = (try? modelContext.fetchCount(FetchDescriptor<FixedExpense>())) ?? 0
            modelContext.insert(FixedExpense(name: trimmed, amount: amount,
                                             dueDay: dueDay, emoji: iconAsset, sortOrder: order))
        }
        try? modelContext.save()
    }
}

#Preview { FixedExpenseView() }
