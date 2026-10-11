import SwiftUI
import SwiftData

/// 添加 / 编辑一笔分期（方案 §12 D12：两种输入模式）
///
/// ① 我知道本金：填 本金 + 期数 + 费率 → 自动摊平每期（适合新发生的分期）
/// ② 我只知道每期：填 每期金额 + 还剩几期 → 不用反推本金（适合把 Excel 老账搬进来）
///
/// 落库统一为 Liability：perPeriod 由 (principal + 手续费) / 期数 推导，
/// 模式 ② 则令 principal = 每期 × 剩余期数、费率为 0。
struct AddInstallmentSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Account.name) private var accounts: [Account]

    var editing: Liability?

    @State private var accountID = ""
    @State private var label = ""
    @State private var mode = 0                 // 0 = 我知道本金 / 1 = 我只知道每期
    @State private var principalStr = ""
    @State private var perPeriodStr = ""
    @State private var periods = 12
    @State private var paidPeriods = 0
    @State private var remainPeriods = 6
    @State private var feeMode = FeeMode.totalRate
    @State private var feeValue: Double = 8.8

    /// 显式 init：@Query 会被 memberwise init 暴露成 `_accounts`，屏蔽掉
    init(defaultAccountID: String? = nil, editing: Liability? = nil) {
        self.editing = editing
        _accountID = State(initialValue: defaultAccountID ?? "")
    }

    private var creditAccounts: [Account] { accounts.filter { $0.kind.isCredit } }
    private var principal: Decimal { Decimal(string: principalStr) ?? 0 }
    private var perPeriodInput: Decimal { Decimal(string: perPeriodStr) ?? 0 }

    /// 试算用的临时对象（走同一个 DebtEngine，保证与详情页口径一致）
    private var draft: Liability {
        Liability(name: label.isEmpty ? "分期" : label, kind: .installment, category: .credit,
                  principal: effectivePrincipal,
                  totalPeriods: effectivePeriods,
                  paidPeriods: paidPeriods,
                  feeMode: mode == 0 ? feeMode : .none,
                  feeValue: mode == 0 ? Decimal(feeValue) : 0,
                  billDay: 1, dueDay: 25,
                  linkedAccountID: accountID.isEmpty ? nil : accountID)
    }

    private var effectivePrincipal: Decimal {
        mode == 0 ? principal : perPeriodInput * Decimal(max(remainPeriods, 0))
    }
    private var effectivePeriods: Int {
        mode == 0 ? periods : remainPeriods
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SheetGrabber()
                Text(editing == nil ? "添加分期" : "编辑分期")
                    .scaledFont(17, weight: .bold)
                    .frame(maxWidth: .infinity)

                field("归属信用账户") { accountPicker }
                field("备注（可选）") { textInput($label, placeholder: "如 手机分期") }
                field("你手上有什么信息？") {
                    HStack(spacing: 6) {
                        modeBtn("我知道本金", 0)
                        modeBtn("我只知道每期", 1)
                    }
                    .padding(4).background(Color(hex: 0xEDEDEB)).cornerRadius(12)
                }

                if mode == 0 {
                    field("本金 / 当前欠款") {
                        textInput($principalStr, placeholder: "如 1800（必填）", keyboard: .decimalPad)
                    }
                    field("分期期数") {
                        HStack(spacing: 8) {
                            ForEach([3, 6, 12, 24], id: \.self) { n in periodChip(n) }
                        }
                    }
                    field("手续费率 · 按平台标准自动带出，也可直接改") {
                        feeRow
                        HStack(spacing: 7) {
                            feeChip("免息", .none, 0)
                            feeChip("标准档 \(rateText(periods))%", .totalRate, standardRate(periods))
                            feeChip("年化 \(aprText(periods))%", .apr, standardRateApr(periods))
                        }
                        .padding(.top, 8)
                    }
                    field("已还期数（历史老账填这里）") {
                        stepperRow("\(paidPeriods) 期", value: $paidPeriods, range: 0...120)
                    }
                } else {
                    field("每期金额") {
                        textInput($perPeriodStr, placeholder: "如 547.49（必填）", keyboard: .decimalPad)
                    }
                    field("还剩几期") {
                        stepperRow("\(remainPeriods) 期", value: $remainPeriods, range: 1...120)
                    }
                }

                calcCard

                Button {
                    Haptics.success()
                    save()
                    dismiss()
                } label: {
                    Text(editing == nil ? "保存分期" : "保存修改")
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
        .onAppear(perform: onAppear)
    }

    // MARK: 试算卡

    private var calcCard: some View {
        let per = DebtEngine.perPeriod(draft)
        let fee = DebtEngine.totalFee(draft)
        let apr = DebtEngine.apr(draft)
        return VStack(alignment: .leading, spacing: 5) {
            if mode == 0 && feeMode == .none {
                Text("免息分期，每期应还 本金 ÷ \(periods) = ")
                + Text("¥\(Money.string(dec(per)))").bold()
            } else if mode == 1 {
                Text("每期 ")
                + Text("¥\(Money.string(dec(per)))").bold()
                + Text(" × 剩 \(remainPeriods) 期 = 剩余 ")
                + Text("¥\(Money.string(dec(fee + per * Decimal(max(remainPeriods, 0)))))").bold()
            } else {
                Text("本金 ¥\(Money.string(dec(principal))) × \(String(format: "%.2f", dec(DebtEngine.nominalRate(draft))))% = 手续费 ")
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

    // MARK: 组件

    @ViewBuilder
    private var accountPicker: some View {
        if creditAccounts.isEmpty {
            Text("还没有信用账户 —— 先到资产页右上角 ＋ 新建一个信用卡 / 花呗 / 白条")
                .scaledFont(12.5).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(Theme.card).cornerRadius(11)
        } else {
            VStack(spacing: 0) {
                ForEach(creditAccounts, id: \.id) { acc in
                    Button {
                        Haptics.tap()
                        accountID = acc.id
                    } label: {
                        HStack(spacing: 10) {
                            Text(acc.kind.logoChar)
                                .scaledFont(13, weight: .semibold).foregroundStyle(.white)
                                .frame(width: 30, height: 30)
                                .background(Color(hex: acc.kind.brandColorHex))
                                .cornerRadius(9)
                            Text(acc.name).scaledFont(13.5)
                            Spacer()
                            if accountID == acc.id {
                                Image(systemName: "checkmark")
                                    .scaledFont(13, weight: .semibold)
                                    .foregroundStyle(Theme.green)
                            }
                        }
                        .padding(.horizontal, 13).padding(.vertical, 10)
                    }
                    .buttonStyle(PressableButtonStyle(scale: 0.99))
                    if acc.id != creditAccounts.last?.id {
                        Divider().padding(.leading, 53)
                    }
                }
            }
            .background(Theme.card).cornerRadius(11)
        }
    }

    private var feeRow: some View {
        HStack(spacing: 6) {
            Text(feeMode == .none ? "免息" : feeMode.label)
                .scaledFont(13).foregroundStyle(.secondary)
            Spacer()
            if feeMode == .none {
                Text("0%").scaledFont(14, weight: .semibold).foregroundStyle(.secondary)
            } else {
                TextField("0", value: $feeValue,
                          format: .number.precision(.fractionLength(0...2)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .scaledFont(14, weight: .semibold)
                    .frame(width: 76)
                    .accessibilityLabel("费率数值")
                Text("%").scaledFont(14, weight: .semibold).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 13).padding(.vertical, 12)
        .background(Theme.card).cornerRadius(11)
    }

    private func modeBtn(_ t: String, _ v: Int) -> some View {
        Button { Haptics.tap(); mode = v } label: {
            Text(t).scaledFont(12.5, weight: .medium)
                .foregroundStyle(mode == v ? .primary : .secondary)
                .frame(maxWidth: .infinity).padding(.vertical, 8)
                .background(mode == v ? Theme.card : .clear).cornerRadius(9)
        }
        .buttonStyle(PressableButtonStyle(scale: 0.98))
    }

    private func periodChip(_ n: Int) -> some View {
        let on = periods == n
        return Button {
            Haptics.tap()
            periods = n
            if feeMode == .totalRate { feeValue = standardRate(n) }
            else if feeMode == .apr { feeValue = standardRateApr(n) }
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

    private func stepperRow(_ text: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        HStack {
            Text(text).scaledFont(14).monospacedDigit()
            Spacer()
            Stepper("", value: value, in: range).labelsHidden()
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

    // MARK: 标准档与换算（与 AddLiabilitySheet 同源口径）

    /// 花呗标准档：3期2.5% / 6期4.5% / 9期6.5% / 12期8.8% / 24期15.6%
    private func standardRate(_ n: Int) -> Double {
        switch n {
        case 3: 2.5; case 6: 4.5; case 9: 6.5; case 12: 8.8; case 24: 15.6
        default: 8.8
        }
    }
    private func rateText(_ n: Int) -> String { String(format: "%.2f", standardRate(n)) }
    private func standardRateApr(_ n: Int) -> Double {
        dec(DebtEngine.aprFromTotalRate(ratePercent: Decimal(standardRate(n)), periods: n))
    }
    private func aprText(_ n: Int) -> String { String(format: "%.2f", standardRateApr(n)) }

    // MARK: 载入 / 保存

    private var canSave: Bool {
        guard !accountID.isEmpty else { return false }
        return mode == 0 ? (principal > 0 && periods > 1)
                         : (perPeriodInput > 0 && remainPeriods > 0)
    }

    private func onAppear() {
        if accountID.isEmpty { accountID = creditAccounts.first?.id ?? "" }
        guard let l = editing else { return }
        accountID = l.linkedAccountID ?? accountID
        label = l.name
        mode = 0
        principalStr = NSDecimalNumber(decimal: l.principal).stringValue
        periods = l.totalPeriods == 0 ? 12 : l.totalPeriods
        paidPeriods = l.paidPeriods
        feeMode = l.feeMode
        feeValue = NSDecimalNumber(decimal: l.feeValue).doubleValue
    }

    private func save() {
        let name = label.trimmingCharacters(in: .whitespaces).isEmpty ? "分期"
                 : label.trimmingCharacters(in: .whitespaces)
        let principalValue = effectivePrincipal
        let periodCount = effectivePeriods
        let fm: FeeMode = mode == 0 ? feeMode : .none
        let fv: Decimal = mode == 0 ? Decimal(feeValue) : 0
        let paid = mode == 0 ? paidPeriods : 0

        if let l = editing {
            l.name = name
            l.principal = principalValue
            l.totalPeriods = periodCount
            l.paidPeriods = min(paid, periodCount)
            l.feeModeRaw = fm.rawValue
            l.feeValue = fv
            l.linkedAccountID = accountID
        } else {
            let order = (try? modelContext.fetchCount(FetchDescriptor<Liability>())) ?? 0
            modelContext.insert(Liability(
                name: name, kind: .installment, category: .credit,
                principal: principalValue, totalPeriods: periodCount,
                paidPeriods: min(paid, periodCount),
                feeMode: fm, feeValue: fv,
                billDay: 1, dueDay: 25, startMonth: "",
                iconChar: "分", iconHex: 0x8E8E93,
                linkedAccountID: accountID, sortOrder: order))
        }
        try? modelContext.save()
    }

    private func dec(_ d: Decimal) -> Double { NSDecimalNumber(decimal: d).doubleValue }
}

#Preview { AddInstallmentSheet() }
