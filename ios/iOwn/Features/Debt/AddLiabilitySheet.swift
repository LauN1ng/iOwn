import SwiftUI
import SwiftData

/// 建档 / 编辑负债（负债与可支配-方案-v1 D4/D9/D10）
/// 三种形态：分期 / 当期账单 / 固定金额
/// 分期时：期数选择自动带出平台标准费率、可手改；实时换算每期金额 + 真实年化
/// 两个关键日期：账单日（银行汇总本期）与 还款日（最后期限）分开醒目展示
struct AddLiabilitySheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Account.name) private var accounts: [Account]

    var editing: Liability?

    /// 显式 init（@Query 会被 memberwise init 暴露 → 屏蔽）
    init(editing: Liability? = nil) { self.editing = editing }

    // 表单状态
    @State private var category = LiabilityCategory.credit
    @State private var name = ""
    @State private var kind = LiabilityKind.installment
    @State private var principalStr = ""
    @State private var periods = 12
    @State private var paidPeriods = 0
    @State private var feeMode = FeeMode.totalRate
    @State private var feeValue: Double = 8.8
    @State private var billDay = 1
    @State private var dueDay = 25
    @State private var iconChar = "花"
    @State private var iconHex: UInt32 = 0x7F77DD
    @State private var linkedAccountID: String?

    private var principal: Decimal { Decimal(principalStr.isEmpty ? "0" : principalStr) ?? 0 }

    /// 临时构造一个 Liability 供引擎试算
    private var draft: Liability {
        Liability(name: name.isEmpty ? "未命名" : name, kind: kind, category: category,
                  principal: principal, totalPeriods: kind == .installment ? periods : 0,
                  paidPeriods: paidPeriods, feeMode: feeMode,
                  feeValue: Decimal(feeValue), billDay: billDay, dueDay: dueDay,
                  iconChar: iconChar, iconHex: iconHex, linkedAccountID: linkedAccountID)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SheetGrabber()
                Text(editing == nil ? "新建负债 / 固定支出" : "编辑负债")
                    .scaledFont(17, weight: .bold)
                    .frame(maxWidth: .infinity)

                field("类型") {
                    HStack(spacing: 6) {
                        catBtn("信用负债", .credit)
                        catBtn("固定支出", .fixedExpense)
                    }
                    .padding(4).background(Color(hex: 0xEDEDEB)).cornerRadius(12)
                }

                field("名称") { textInput($name, placeholder: "花呗") }

                field("账户类型（决定怎么算）") {
                    HStack(spacing: 8) {
                        kindChip("分期", .installment)
                        kindChip("当期账单", .currentBill)
                        kindChip("固定金额", .fixed)
                    }
                }

                field(kind == .fixed ? "每月金额" : "本金 / 当前欠款") {
                    textInput($principalStr, placeholder: "1800.00", keyboard: .decimalPad)
                }

                if kind == .installment {
                    divisorSection
                } else {
                    field("已还期数") { numberStepper($paidPeriods) }
                }

                dateSection

                field("图标") {
                    HStack(spacing: 8) {
                        ForEach(iconPresets, id: \.0) { p in
                            Button {
                                Haptics.tap(); iconChar = p.0; iconHex = p.1
                            } label: {
                                Text(p.0)
                                    .scaledFont(15, weight: .semibold).foregroundStyle(.white)
                                    .frame(width: 40, height: 40)
                                    .background(Color(hex: p.1))
                                    .cornerRadius(12)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(iconChar == p.0 ? Theme.green : .clear, lineWidth: 2)
                                    )
                            }
                            .buttonStyle(PressableButtonStyle(scale: 0.94))
                        }
                        Spacer()
                    }
                }

                if !accounts.isEmpty {
                    field("关联账户 · 还款时自动扣减") {
                        VStack(spacing: 0) {
                            ForEach(accounts, id: \.id) { acc in
                                Button {
                                    Haptics.tap()
                                    linkedAccountID = (linkedAccountID == acc.id) ? nil : acc.id
                                } label: {
                                    HStack(spacing: 10) {
                                        Text(acc.kind.logoChar)
                                            .scaledFont(13, weight: .semibold).foregroundStyle(.white)
                                            .frame(width: 30, height: 30)
                                            .background(Color(hex: acc.kind.brandColorHex))
                                            .cornerRadius(9)
                                        Text(acc.name).scaledFont(13.5)
                                        Spacer()
                                        if linkedAccountID == acc.id {
                                            Image(systemName: "checkmark")
                                                .scaledFont(13, weight: .semibold)
                                                .foregroundStyle(Theme.green)
                                        }
                                    }
                                    .padding(.horizontal, 13).padding(.vertical, 10)
                                }
                                .buttonStyle(PressableButtonStyle(scale: 0.99))
                                if acc.id != accounts.last?.id {
                                    Divider().padding(.leading, 53)
                                }
                            }
                        }
                        .background(Theme.card).cornerRadius(11)
                    }
                }

                saveButton
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 30)
        }
        .background(Theme.bg)
        .onAppear { loadIfEditing() }
    }

    // MARK: 分期专属区（D9：非分期时整块不出现在这里；D10：费率随期数带出可改）

    private var divisorSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            field("分期期数") {
                HStack(spacing: 8) {
                    ForEach([3, 6, 12, 24], id: \.self) { n in periodChip(n) }
                }
            }

            field("手续费率 · 按平台标准自动带出，可改") {
                HStack {
                    Text(feeMode == .none ? "免息" : "\(feeMode.label)")
                        .scaledFont(13).foregroundStyle(.secondary)
                    Spacer()
                    Text(feeMode == .none ? "0%" : String(format: "%.2f%%", feeValue))
                        .scaledFont(14, weight: .semibold).monospacedDigit()
                }
                .padding(.horizontal, 13).padding(.vertical, 12)
                .background(Theme.card).cornerRadius(11)

                HStack(spacing: 7) {
                    feeChip("免息", .none, 0)
                    feeChip("12 期 8.8%", .totalRate, 8.8)
                    feeChip("年化 15.86%", .apr, 15.86)
                }
                .padding(.top, 8)
            }

            calcCard
        }
    }

    private var calcCard: some View {
        let per = DebtEngine.perPeriod(draft)
        let fee = DebtEngine.totalFee(draft)
        let apr = DebtEngine.apr(draft)
        return VStack(alignment: .leading, spacing: 5) {
            if feeMode == .none {
                Text("免息分期，每期应还 (本金)÷\(periods) = ")
                + Text("¥\(Money.string(dec(per)))").bold()
            } else {
                Text("本金 ¥\(Money.string(dec(principal))) × \(String(format: "%.2f", feeValue))% = 手续费 ")
                + Text("¥\(Money.string(dec(fee)))").bold()
                Text("每期应还 (本金+手续费)÷\(periods) = ")
                + Text("¥\(Money.string(dec(per)))").bold().foregroundColor(Theme.greenText)
                Text("实际年化约 ")
                + Text("\(String(format: "%.2f", dec(apr)))%").bold()
                + Text("（手续费按原始本金计，≠名义费率）")
            }
        }
        .scaledFont(12)
        .foregroundStyle(Color(hex: 0x6B4A0C))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(hex: 0xFAEEDA))
        .cornerRadius(11)
    }

    // MARK: 两个关键日期（D8：分开醒目）

    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("两个关键日期 · 决定这笔算哪期账单")
                .scaledFont(11.5).foregroundStyle(.secondary)
            HStack(spacing: 12) {
                dayCard(title: "账单日", day: $billDay,
                        color: Theme.blueText, note: "银行汇总本期消费\n之后消费计入下期")
                dayCard(title: "还款日", day: $dueDay,
                        color: Color(hex: 0x8A5A0B), note: "最后还款期限\n到期弹卡提醒")
            }
        }
    }

    private func dayCard(title: String, day: Binding<Int>, color: Color, note: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).scaledFont(11, weight: .semibold).foregroundStyle(color)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(day.wrappedValue)")
                    .scaledFont(22, weight: .bold).monospacedDigit()
                Text("日").scaledFont(13).foregroundStyle(.secondary)
                Spacer()
                Stepper("", value: day, in: 1...31)
                    .labelsHidden()
            }
            Text(note).scaledFont(10.5).foregroundStyle(.secondary).lineSpacing(2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.hairline, lineWidth: 1))
    }

    // MARK: 保存

    private var saveButton: some View {
        Button {
            Haptics.success()
            save()
            dismiss()
        } label: {
            Text(editing == nil ? "建档完成" : "保存修改")
                .scaledFont(15, weight: .semibold).foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 15)
                .background(canSave ? Theme.green : Theme.disabled)
                .cornerRadius(14)
        }
        .buttonStyle(PressableButtonStyle(scale: 0.985))
        .disabled(!canSave)
        .padding(.top, 6)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && principal > 0
    }

    private func save() {
        if let l = editing {
            l.name = name.trimmingCharacters(in: .whitespaces)
            l.kindRaw = kind.rawValue; l.categoryRaw = category.rawValue
            l.principal = principal
            l.totalPeriods = kind == .installment ? periods : 0
            l.paidPeriods = paidPeriods
            l.feeModeRaw = feeMode.rawValue; l.feeValue = Decimal(feeValue)
            l.billDay = billDay; l.dueDay = dueDay
            l.iconChar = iconChar; l.iconHex = iconHex
            l.linkedAccountID = linkedAccountID
        } else {
            let l = Liability(name: name.trimmingCharacters(in: .whitespaces), kind: kind,
                              category: category, principal: principal,
                              totalPeriods: kind == .installment ? periods : 0,
                              paidPeriods: paidPeriods, feeMode: feeMode,
                              feeValue: Decimal(feeValue), billDay: billDay, dueDay: dueDay,
                              iconChar: iconChar, iconHex: iconHex,
                              linkedAccountID: linkedAccountID, sortOrder: liabilitiesCount())
            modelContext.insert(l)
        }
        try? modelContext.save()
    }

    private func liabilitiesCount() -> Int {
        (try? modelContext.fetchCount(FetchDescriptor<Liability>())) ?? 0
    }

    private func loadIfEditing() {
        guard let l = editing else { return }
        category = l.category; name = l.name; kind = l.kind
        principalStr = NSDecimalNumber(decimal: l.principal).stringValue
        periods = l.totalPeriods == 0 ? 12 : l.totalPeriods
        paidPeriods = l.paidPeriods
        feeMode = l.feeMode; feeValue = NSDecimalNumber(decimal: l.feeValue).doubleValue
        billDay = l.billDay; dueDay = l.dueDay
        iconChar = l.iconChar; iconHex = l.iconHex; linkedAccountID = l.linkedAccountID
    }

    // MARK: 组件

    private var iconPresets: [(String, UInt32)] {
        [("花", 0x7F77DD), ("信", 0xD4537E), ("白", 0xE24B4A), ("房", 0x4A8CF7), ("债", 0x8E8E93)]
    }

    private func catBtn(_ t: String, _ v: LiabilityCategory) -> some View {
        Button { Haptics.tap(); category = v } label: {
            Text(t).scaledFont(12.5, weight: .medium)
                .foregroundStyle(category == v ? .primary : .secondary)
                .frame(maxWidth: .infinity).padding(.vertical, 8)
                .background(category == v ? Theme.card : .clear).cornerRadius(9)
        }
        .buttonStyle(PressableButtonStyle(scale: 0.98))
    }

    private func kindChip(_ t: String, _ v: LiabilityKind) -> some View {
        Button { Haptics.tap(); kind = v } label: {
            Text(t).scaledFont(12.5)
                .foregroundStyle(kind == v ? Theme.greenText : .secondary)
                .padding(.horizontal, 13).padding(.vertical, 8)
                .background(kind == v ? Theme.greenSoft : Theme.card)
                .cornerRadius(9)
                .overlay(RoundedRectangle(cornerRadius: 9)
                    .stroke(kind == v ? Theme.green : Theme.hairline, lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle(scale: 0.96))
    }

    /// 期数 chip：点选后自动按平台标准带出费率（D10）
    private func periodChip(_ n: Int) -> some View {
        let on = periods == n
        return Button {
            Haptics.tap()
            periods = n
            if feeMode == .totalRate { feeValue = standardRate(n) }
            else if feeMode == .apr { feeValue = standardRate(n) * 24 / Double(n + 1) }
        } label: {
            Text("\(n)").scaledFont(13, weight: .medium)
                .foregroundStyle(on ? Theme.greenText : .secondary)
                .frame(width: 46, height: 40)
                .background(on ? Theme.greenSoft : Theme.card).cornerRadius(9)
                .overlay(RoundedRectangle(cornerRadius: 9)
                    .stroke(on ? Theme.green : Theme.hairline, lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle(scale: 0.94))
    }

    private func feeChip(_ t: String, _ m: FeeMode, _ v: Double) -> some View {
        let on = feeMode == m
        return Button {
            Haptics.tap(); feeMode = m; feeValue = v
            if m == .totalRate { feeValue = standardRate(periods) }
        } label: {
            Text(t).scaledFont(12)
                .foregroundStyle(on ? Theme.greenText : .secondary)
                .padding(.horizontal, 11).padding(.vertical, 7)
                .background(on ? Theme.greenSoft : Theme.card).cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .stroke(on ? Theme.green : Theme.hairline, lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle(scale: 0.95))
    }

    /// 花呗标准档：3期2.5% / 6期4.5% / 9期6.5% / 12期8.8%
    private func standardRate(_ n: Int) -> Double {
        switch n {
        case 3: 2.5; case 6: 4.5; case 9: 6.5; case 12: 8.8; case 24: 15.6
        default: 8.8
        }
    }

    private func numberStepper(_ v: Binding<Int>) -> some View {
        HStack {
            Text("\(v.wrappedValue) 期").scaledFont(14).monospacedDigit()
            Spacer()
            Stepper("", value: v, in: 0...120).labelsHidden()
        }
        .padding(.horizontal, 13).padding(.vertical, 10)
        .background(Theme.card).cornerRadius(11)
    }

    @ViewBuilder
    private func textInput(_ text: Binding<String>, placeholder: String,
                           keyboard: UIKeyboardType = .default) -> some View {
        TextField(placeholder, text: text)
            .keyboardType(keyboard)
            .scaledFont(14)
            .padding(.horizontal, 13).padding(.vertical, 12)
            .background(Theme.card).cornerRadius(11)
    }

    @ViewBuilder
    private func field<C: View>(_ label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).scaledFont(11.5).foregroundStyle(.secondary)
            content()
        }
    }

    private func dec(_ d: Decimal) -> Double { NSDecimalNumber(decimal: d).doubleValue }
}

#Preview { AddLiabilitySheet() }
