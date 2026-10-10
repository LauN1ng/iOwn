import SwiftUI
import SwiftData

/// 固定支出 / 订阅（独立模块，方案 §12 D17）
///
/// 房租、会员这类「每月固定扣、永远不结束」的支出 —— **它不是负债**：
/// 不进「待还总额」、没有期数、不会还完；但会扣掉本月可支配。
struct FixedExpenseView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FixedExpense.sortOrder) private var items: [FixedExpense]

    @State private var showAdd = false
    @State private var editing: FixedExpense?

    private var monthlyTotal: Decimal { items.reduce(Decimal(0)) { $0 + $1.amount } }

    var body: some View {
        ScrollView {
            VStack(spacing: Radius.cardSpacing) {
                hero
                notice
                if items.isEmpty {
                    EmptyStateCard(icon: "📅", title: "还没有固定支出",
                                   hint: "点右上角 ＋ 添加房租、会员等每月固定扣款")
                } else {
                    ForEach(items, id: \.id) { item in row(item) }
                }
                addButton
            }
            .padding(.horizontal, Radius.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 150)
        }
        .background(Theme.bg)
        .navigationTitle("固定支出 / 订阅")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { Haptics.tap(); showAdd = true } label: {
                    Image(systemName: "plus").scaledFont(16, weight: .semibold)
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
    }

    private var hero: some View {
        LinearGradient(colors: [Theme.green, Theme.greenDeep], startPoint: .top, endPoint: .bottom)
            .overlay(alignment: .bottom) {
                Ellipse().fill(Color.white.opacity(0.14))
                    .frame(height: 44).frame(maxWidth: .infinity).offset(y: 34)
            }
            .overlay {
                VStack(alignment: .leading, spacing: 0) {
                    Text("每月固定合计").scaledFont(12).foregroundStyle(.white.opacity(0.88))
                    Text("¥ \(Money.string(dec(monthlyTotal)))")
                        .scaledFont(34, weight: .heavy, design: .rounded)
                        .foregroundStyle(.white).monospacedDigit()
                        .padding(.top, 4)
                    Text("\(items.count) 项 · 每月自动扣，不累计成欠款")
                        .scaledFont(11.5).foregroundStyle(.white.opacity(0.85))
                        .padding(.top, 5)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
            }
            .frame(height: 138)
            .clipShape(RoundedRectangle(cornerRadius: Radius.large))
    }

    private var notice: some View {
        Text("这些是「每月固定扣的持续支出」，不是负债 —— 所以不叫待还、也不会还完；但它们照样会扣掉你的本月可支配。")
            .scaledFont(11.5)
            .foregroundStyle(Theme.blueText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color(hex: 0xEAF1FE))
            .cornerRadius(Radius.medium)
    }

    private func row(_ item: FixedExpense) -> some View {
        Button { Haptics.tap(); editing = item } label: {
            HStack(spacing: 12) {
                Text(item.emoji)
                    .scaledFont(20)
                    .frame(width: 42, height: 42)
                    .background(Theme.iconBg)
                    .cornerRadius(14)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.name).scaledFont(15, weight: .semibold)
                    Text("每月 \(item.dueDay) 日 · 固定").scaledFont(11).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Text("¥\(Money.string(dec(item.amount)))")
                    .scaledFont(15, weight: .semibold).monospacedDigit()
            }
            .padding(14)
            .background(Theme.card)
            .cornerRadius(Radius.medium)
            .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
        }
        .buttonStyle(PressableButtonStyle(scale: 0.985))
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
                .scaledFont(15, weight: .semibold)
                .foregroundStyle(Theme.greenText)
                .frame(maxWidth: .infinity).padding(.vertical, 15)
                .background(Theme.greenSoft).cornerRadius(14)
        }
        .buttonStyle(PressableButtonStyle(scale: 0.985))
        .padding(.top, 4)
    }

    private func dec(_ d: Decimal) -> Double { NSDecimalNumber(decimal: d).doubleValue }
}

/// 新增 / 编辑固定支出项
struct FixedExpenseSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var editing: FixedExpense?

    init(editing: FixedExpense? = nil) { self.editing = editing }

    @State private var name = ""
    @State private var amountStr = ""
    @State private var dueDay = 1
    @State private var emoji = "🏠"

    private let emojis = ["🏠", "📺", "🎵", "📱", "💡", "🚇", "🏋️", "☁️", "📰", "💳"]

    private var amount: Decimal { Decimal(string: amountStr) ?? 0 }
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && amount > 0
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SheetGrabber()
                Text(editing == nil ? "添加固定支出" : "编辑固定支出")
                    .scaledFont(17, weight: .bold)
                    .frame(maxWidth: .infinity)

                field("名称") {
                    TextField("房租 / 视频会员", text: $name)
                        .scaledFont(14)
                        .padding(.horizontal, 13).padding(.vertical, 12)
                        .background(Theme.card).cornerRadius(11)
                }
                field("每月金额") {
                    TextField("如 1230.50", text: $amountStr)
                        .keyboardType(.decimalPad)
                        .scaledFont(14)
                        .padding(.horizontal, 13).padding(.vertical, 12)
                        .background(Theme.card).cornerRadius(11)
                }
                field("每月扣款日") {
                    HStack {
                        Text("\(dueDay) 日").scaledFont(14).monospacedDigit()
                        Spacer()
                        Stepper("", value: $dueDay, in: 1...31).labelsHidden()
                    }
                    .padding(.horizontal, 13).padding(.vertical, 10)
                    .background(Theme.card).cornerRadius(11)
                }
                field("图标") {
                    HStack(spacing: 8) {
                        ForEach(emojis, id: \.self) { e in
                            Button {
                                Haptics.tap(); emoji = e
                            } label: {
                                Text(e)
                                    .scaledFont(17)
                                    .frame(width: 38, height: 38)
                                    .background(emoji == e ? Theme.greenSoft : Theme.card)
                                    .cornerRadius(11)
                                    .overlay(RoundedRectangle(cornerRadius: 11)
                                        .stroke(emoji == e ? Theme.green : Theme.hairline, lineWidth: 1))
                            }
                            .buttonStyle(PressableButtonStyle(scale: 0.94))
                        }
                        Spacer()
                    }
                }

                Button {
                    Haptics.success()
                    save()
                    dismiss()
                } label: {
                    Text(editing == nil ? "添加" : "保存修改")
                        .scaledFont(15, weight: .semibold).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 15)
                        .background(canSave ? Theme.green : Theme.disabled)
                        .cornerRadius(14)
                }
                .buttonStyle(PressableButtonStyle(scale: 0.985))
                .disabled(!canSave)
                .padding(.top, 6)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 30)
        }
        .background(Theme.bg)
        .onAppear {
            guard let item = editing else { return }
            name = item.name
            amountStr = NSDecimalNumber(decimal: item.amount).stringValue
            dueDay = item.dueDay
            emoji = item.emoji
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let item = editing {
            item.name = trimmed
            item.amount = amount
            item.dueDay = dueDay
            item.emoji = emoji
        } else {
            let order = (try? modelContext.fetchCount(FetchDescriptor<FixedExpense>())) ?? 0
            modelContext.insert(FixedExpense(name: trimmed, amount: amount,
                                             dueDay: dueDay, emoji: emoji, sortOrder: order))
        }
        try? modelContext.save()
    }

    @ViewBuilder
    private func field<C: View>(_ label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).scaledFont(11.5).foregroundStyle(.secondary)
            content()
        }
    }
}

#Preview { FixedExpenseView() }
