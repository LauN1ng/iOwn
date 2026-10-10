import SwiftUI
import SwiftData

// MARK: - C1 待确认卡（Spec §2-C1）：解析结果预填 → 可改分类/账户 → 确认入账
// 视觉语言与记一笔一致：SheetGrabber + 半屏 sheet + chip 选中态（绿底白字）

struct AutoConfirmSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Account.name) private var accounts: [Account]

    let bill: PendingBill
    /// 确认后回调（供 RootTabView 播成功屏）
    var onSaved: (SavedEntryInfo) -> Void = { _ in }
    /// 「改细节」：关确认卡 → 带草稿进记一笔
    var onRefine: (PendingBill) -> Void = { _ in }

    @State private var category: CategoryDef?
    @State private var sub: CategoryDef.SubDef?
    @State private var accountID: String?

    private var amount: Decimal { Decimal(bill.amountCents) / 100 }
    private var amountDisplay: String {
        String(format: "%.2f", NSDecimalNumber(decimal: amount).doubleValue)
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetGrabber()

            VStack(alignment: .leading, spacing: 18) {
                // 头部：通道徽标 + 解析说明
                HStack(spacing: 10) {
                    Text(bill.channel.emoji).scaledFont(28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("自动捕获一笔支出").scaledFont(17, weight: .bold)
                        Text("\(bill.channel.label)\(bill.merchant.isEmpty ? "" : " · \(bill.merchant)")")
                            .scaledFont(12)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.top, 4)

                // 金额大字（绿，视觉基准 §4.2）
                Text("¥\(amountDisplay)")
                    .scaledFont(40, weight: .bold)
                    .foregroundStyle(Theme.greenText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 6)

                // 分类选择：大类 chip 行 + 子类 chip 行
                VStack(alignment: .leading, spacing: 10) {
                    chipRow(CategoryPresets.all, selectedID: category?.id) { cat in
                        category = cat
                        sub = cat.subs.first
                    }
                    if let cat = category, !cat.subs.isEmpty {
                        chipRow(cat.subs, selectedID: sub?.id) { sub = $0 }
                    }
                }

                // 账户 chip 行（默认按通道 preferred kind 匹配）
                VStack(alignment: .leading, spacing: 8) {
                    Text("账户").scaledFont(12).foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        accountChip(nil, label: "不挂账户")
                        ForEach(accounts) { acc in
                            accountChip(acc.id, label: acc.name)
                        }
                    }
                }

                HStack(spacing: 12) {
                    Button {
                        Haptics.tap()
                        PendingBillStore.discard(bill)
                        dismiss()
                    } label: {
                        Text("忽略")
                            .scaledFont(16, weight: .semibold)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(Theme.disabled, in: RoundedRectangle(cornerRadius: Radius.medium))
                    }
                    .accessibilityLabel("忽略这笔自动记账")

                    Button {
                        confirm()
                    } label: {
                        Text("记下来 ✓")
                            .scaledFont(16, weight: .bold)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(Theme.green, in: RoundedRectangle(cornerRadius: Radius.medium))
                    }
                    .accessibilityLabel("确认入账")
                }

                Button {
                    Haptics.tap()
                    PendingBillStore.discard(bill)
                    let b = bill
                    dismiss()
                    onRefine(b)
                } label: {
                    Text("改细节（备注/心情/日期）")
                        .scaledFont(13)
                        .foregroundStyle(Theme.greenText)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, Radius.pagePadding)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.bg)
        .onAppear {
            if category == nil {
                category = CategoryPresets.category(id: bill.suggestedCategoryID) ?? CategoryPresets.all[1]
                sub = category?.subs.first { $0.id == bill.suggestedSubID } ?? category?.subs.first
            }
            if accountID == nil {
                accountID = defaultAccountID()
            }
        }
    }

    // MARK: 子组件

    private func chipRow<T: Identifiable>(_ items: [T], selectedID: String?,
                                          action: @escaping (T) -> Void) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items) { item in
                    let selected = (item.id as? String) == selectedID
                    Button {
                        Haptics.tap()
                        action(item)
                    } label: {
                        chipLabel(for: item, selected: selected)
                    }
                    .buttonStyle(PressableButtonStyle(scale: 0.94))
                }
            }
        }
    }

    private func chipLabel<T: Identifiable>(for item: T, selected: Bool) -> some View {
        let text: String
        if let cat = item as? CategoryDef {
            text = "\(cat.emoji) \(cat.name)"
        } else if let s = item as? CategoryDef.SubDef {
            text = "\(s.emoji) \(s.name)"
        } else {
            text = "?"
        }
        return Text(text)
            .scaledFont(14, weight: selected ? .bold : .regular)
            .foregroundStyle(selected ? .white : Theme.greenText)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(selected ? Theme.green : Theme.greenSoft,
                        in: Capsule())
    }

    private func accountChip(_ id: String?, label: String) -> some View {
        let selected = accountID == id
        return Button {
            Haptics.tap()
            accountID = id
        } label: {
            Text(label)
                .scaledFont(13, weight: selected ? .bold : .regular)
                .foregroundStyle(selected ? .white : Theme.greenText)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(selected ? Theme.green : Theme.greenSoft, in: Capsule())
        }
        .buttonStyle(PressableButtonStyle(scale: 0.94))
    }

    // MARK: 逻辑

    private func defaultAccountID() -> String? {
        // 通道偏好类型优先；无对应账户则不挂
        let preferred = accounts.first { $0.kind == bill.channel.preferredAccountKind }
        return preferred?.id
    }

    private func confirm() {
        Haptics.success()
        let tx = Tx(amount: amount, type: .out,
                    categoryID: category?.id ?? "needs",
                    subID: sub?.id,
                    note: bill.merchant.isEmpty ? "自动记账 · \(bill.channel.label)" : bill.merchant,
                    mood: nil,
                    accountID: accountID,
                    date: bill.date,
                    source: .autoNotification)
        modelContext.insert(tx)
        try? modelContext.save()
        PendingBillStore.discard(bill)
        let info = SavedEntryInfo(amount: amount, isOut: true,
                                  categoryName: category?.name ?? "",
                                  subName: sub?.name ?? "",
                                  mood: nil, todayCount: 1, streak: 1)
        dismiss()
        onSaved(info)
    }
}
