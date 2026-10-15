import SwiftUI
import SwiftData
import UIKit

/// 添加 / 编辑分期 —— 2026-10-11 改为「**补录账单**」新模型
///
/// **为什么改**：旧模型要求用户知道「本金 + 期数 + 费率」，但用户手上只有账单，
/// 上面写的是「**第 2/12 期 ¥120.03**」。所以改为直接抄账单：
///   · 每笔填「第 x/n 期」+「每期金额」
///   · 首期与其余期**不同**时（尾差 / 手续费一次性收取），点行尾淡色的「＋首期」补一个数
///
/// 界面和之前**几乎一样**，只多了一个几乎看不见的入口 —— 不需要就永远不用理它。
///
/// ⚠️「一共欠多少」**不在这里录** —— 那是账户属性（= 账户余额），用详情页的「调整」对账。
struct AddInstallmentSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Account.name) private var accounts: [Account]

    var editing: Liability?

    @State private var accountID = ""
    @State private var drafts: [PlanDraft] = [PlanDraft()]

    /// 显式 init：@Query 会被 memberwise init 暴露成 `_accounts`，屏蔽掉
    init(defaultAccountID: String? = nil, editing: Liability? = nil) {
        self.editing = editing
        _accountID = State(initialValue: defaultAccountID ?? "")
    }

    private var creditAccounts: [Account] { accounts.filter { $0.kind.isCredit } }
    private var isBatch: Bool { editing == nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SheetGrabber()
                Text(isBatch ? "补录已有的分期" : "编辑分期")
                    .scaledFont(.title, weight: .bold)
                    .frame(maxWidth: .infinity)

                field("归属信用账户") { accountPicker }

                field(isBatch ? "已有的分期 · 账单一行抄一格" : "这一笔") {
                    VStack(spacing: 10) {
                        ForEach(drafts.indices, id: \.self) { i in
                            draftCard(i)
                        }
                    }
                }

                if isBatch {
                    Button {
                        Haptics.tap()
                        drafts.append(PlanDraft())
                    } label: {
                        Text("＋ 再加一笔")
                            .scaledFont(.sm, weight: .semibold)
                            .foregroundStyle(Theme.greenText)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Theme.greenSoft).cornerRadius(12)
                    }
                    .buttonStyle(PressableButtonStyle(scale: 0.985))
                }

                if isBatch { hintCard }

                Button {
                    Haptics.success()
                    save()
                    dismiss()
                } label: {
                    Text(isBatch ? "保存 \(validCount) 笔分期" : "保存修改")
                        .scaledFont(.body, weight: .semibold).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 15)
                        .background(canSave ? Theme.green : Theme.disabled)
                        .cornerRadius(14)
                }
                .buttonStyle(PressableButtonStyle(scale: 0.985))
                .disabled(!canSave)
                .padding(.top, 2)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 30)
        }
        .background(Theme.bg)
        .onAppear(perform: onAppear)
    }

    // MARK: 单笔草稿卡

    private func draftCard(_ i: Int) -> some View {
        let d = drafts[i]
        return VStack(alignment: .leading, spacing: 9) {
            // 第 x / n 期
            HStack(spacing: 6) {
                Text("第").scaledFont(.sm).foregroundStyle(.secondary)
                numField($drafts[i].currentPeriod, width: 32)
                Text("/").scaledFont(.sm).foregroundStyle(.secondary)
                numField($drafts[i].totalPeriods, width: 36)
                Text("期").scaledFont(.sm).foregroundStyle(.secondary)
                Spacer(minLength: 6)
                if isBatch && drafts.count > 1 {
                    Button {
                        Haptics.tap()
                        drafts.remove(at: i)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .scaledFont(.body).foregroundStyle(.tertiary)
                    }
                    .buttonStyle(PressableButtonStyle(scale: 0.9))
                    .accessibilityLabel("删除这一笔")
                }
            }

            // 每期金额
            HStack(spacing: 8) {
                Text("每期").scaledFont(.sm).foregroundStyle(.secondary)
                TextField("0.00", text: $drafts[i].perPeriod)
                    .keyboardType(.decimalPad)
                    .scaledFont(.title, weight: .semibold).monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .accessibilityLabel("每期金额")
                Text("元").scaledFont(.sm).foregroundStyle(.secondary)
            }

            // 备注（可选）
            TextField("备注（可选，如 手机分期）", text: $drafts[i].label)
                .scaledFont(.sm)
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(Theme.iconBg)
                .cornerRadius(8)

            // 首期（默认隐藏 —— 只多一个几乎看不见的入口）
            if d.showFirst {
                optionalRow(label: "首期", text: $drafts[i].firstPeriod) {
                    drafts[i].showFirst = false
                    drafts[i].firstPeriod = ""
                }
                firstHint(d)
            }

            // 合计（默认隐藏）—— 方案 A：填了它就能**反解末期差额**
            if d.showTotal {
                optionalRow(label: "合计", text: $drafts[i].repayTotal) {
                    drafts[i].showTotal = false
                    drafts[i].repayTotal = ""
                }
                totalHint(d)
            }

            // 两个入口并排，只显示还没展开的那个
            if !d.showFirst || !d.showTotal {
                HStack(spacing: 12) {
                    if !d.showFirst {
                        addChip("＋首期", hint: "首期与其余期金额不同时才需要填") {
                            drafts[i].showFirst = true
                        }
                    }
                    if !d.showTotal {
                        addChip("＋合计", hint: "填「合计」可自动算出末期差额（银行分期）") {
                            drafts[i].showTotal = true
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(13)
        .background(Theme.card)
        .cornerRadius(11)
    }

    /// 首期差额判据（直接写进 App，用户不用记规则）
    @ViewBuilder
    private func firstHint(_ d: PlanDraft) -> some View {
        let diff = d.first - d.per
        if diff > 0.005 {
            Text(diff <= 1
                 ? "首期多 ¥\(money(diff)) —— 尾差，花呗 / 白条会这样，不填也行"
                 : "首期多 ¥\(money(diff)) —— 手续费一次性收取，必须填，否则会少算")
                .scaledFont(.xs)
                .foregroundStyle(diff <= 1 ? Color.secondary : Theme.redText)
        } else if d.first > 0 {
            Text("首期与每期一样，可以不填")
                .scaledFont(.xs).foregroundStyle(.secondary)
        }
    }

    /// 合计 → 末期差额（同样是规则写进 App：银行把余数计入最后一期）
    @ViewBuilder
    private func totalHint(_ d: PlanDraft) -> some View {
        let last = d.derivedLast
        if d.repay > 0, d.total > 1, last > 0 {
            let diff = last - d.per
            if abs(diff) > 0.005 {
                Text("末期 = ¥\(money(last))（比每期\(diff > 0 ? "多" : "少") ¥\(money(abs(diff)))）—— 银行分期通常是这个")
                    .scaledFont(.xs).foregroundStyle(Theme.greenText)
            } else {
                Text("末期 = ¥\(money(last))，与每期一致")
                    .scaledFont(.xs).foregroundStyle(.secondary)
            }
        } else if d.repay > 0 {
            Text("合计 = 本金 ＋ 手续费/利息。填了它，末期差额会自动算出来。")
                .scaledFont(.xs).foregroundStyle(.secondary)
        }
    }

    /// 「一行数字」可选入口（首期 / 合计共用）
    private func optionalRow(label: String, text: Binding<String>,
                             onCollapse: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Text(label).scaledFont(.sm).foregroundStyle(.secondary)
            TextField("0.00", text: text)
                .keyboardType(.decimalPad)
                .scaledFont(.body, weight: .semibold).monospacedDigit()
                .multilineTextAlignment(.trailing)
                .accessibilityLabel("\(label)金额")
            Text("元").scaledFont(.sm).foregroundStyle(.secondary)
            Button {
                Haptics.tap()
                onCollapse()
            } label: {
                Text("收起").scaledFont(.xs).foregroundStyle(.secondary)
                    .padding(.horizontal, 8).padding(.vertical, 5)
                    .background(Theme.iconBg).cornerRadius(7)
            }
            .buttonStyle(PressableButtonStyle(scale: 0.95))
        }
    }

    /// 淡色「＋xxx」小胶囊
    private func addChip(_ title: String, hint: String,
                         action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Text(title).scaledFont(.xs).foregroundStyle(.tertiary)
        }
        .buttonStyle(PressableButtonStyle(scale: 0.95))
        .accessibilityHint(hint)
    }

    /// 说明卡：只在补录模式显示，且不啰嗦
    private var hintCard: some View {
        Text("账单写「第 2/12 期 ¥120.03」就填 2、12、120.03。尾差落在首期（花呗 / 白条）填「＋首期」，落在末期（银行）填「＋合计」。「一共欠多少」不用录 —— 用详情页的「调整」对账。")
            .scaledFont(.xs)
            .foregroundStyle(.secondary)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card)
            .cornerRadius(11)
    }

    // MARK: 组件

    @ViewBuilder
    private var accountPicker: some View {
        if creditAccounts.isEmpty {
            Text("还没有信用账户 —— 先到资产页右上角 ＋ 新建一个信用卡 / 花呗 / 白条")
                .scaledFont(.sm).foregroundStyle(.secondary)
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
                            accountIcon(acc)
                            Text(acc.name).scaledFont(.sm)
                            Spacer()
                            if accountID == acc.id {
                                Image(systemName: "checkmark")
                                    .scaledFont(.sm, weight: .semibold)
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

    /// 账户图标（归一化素材：通用 Fluent 3D / 品牌真实 logo）
    private func accountIcon(_ acc: Account) -> some View {
        Group {
            if !acc.icon.asset.isEmpty, UIImage(named: acc.icon.asset) != nil {
                // ⚠️ 彩色贴图：不要加 .renderingMode(.template)
                Image(acc.icon.asset).resizable().scaledToFit()
            } else {
                // 2026-10-15：emoji 兜底层已删 → 落到单字字块（暂时保留）
                Text(acc.kind.logoChar)
                    .scaledFont(.sm, weight: .semibold).foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Color(hex: acc.kind.brandColorHex))
                    .cornerRadius(9)
            }
        }
        .frame(width: 30, height: 30)
        .accessibilityHidden(true)
    }

    private func numField(_ text: Binding<String>, width: CGFloat) -> some View {
        TextField("0", text: text)
            .keyboardType(.numberPad)
            .scaledFont(.body, weight: .semibold).monospacedDigit()
            .multilineTextAlignment(.center)
            .frame(width: width)
            .padding(.vertical, 7)
            .background(Theme.iconBg)
            .cornerRadius(8)
    }

    @ViewBuilder
    private func field<C: View>(_ label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).scaledFont(.xs).foregroundStyle(.secondary)
            content()
        }
    }

    // MARK: 校验 / 载入 / 保存

    private var validCount: Int { drafts.filter(\.valid).count }
    private var canSave: Bool { !accountID.isEmpty && validCount > 0 }

    private func onAppear() {
        if accountID.isEmpty { accountID = creditAccounts.first?.id ?? "" }
        guard let l = editing else { return }
        accountID = l.linkedAccountID ?? accountID
        var d = PlanDraft()
        d.label = l.name
        d.totalPeriods = "\(max(l.totalPeriods, 1))"
        d.currentPeriod = "\(DebtEngine.currentPeriod(l))"
        let per = l.perPeriodAmount > 0 ? l.perPeriodAmount : DebtEngine.perPeriod(l)
        d.perPeriod = NSDecimalNumber(decimal: per).stringValue
        if l.firstPeriodAmount > 0 {
            d.showFirst = true
            d.firstPeriod = NSDecimalNumber(decimal: l.firstPeriodAmount).stringValue
        }
        if l.totalRepayAmount > 0 {
            d.showTotal = true
            d.repayTotal = NSDecimalNumber(decimal: l.totalRepayAmount).stringValue
        }
        drafts = [d]
    }

    private func save() {
        if let l = editing {
            apply(drafts.first ?? PlanDraft(), to: l)
        } else {
            let base = (try? modelContext.fetchCount(FetchDescriptor<Liability>())) ?? 0
            var offset = 0
            for d in drafts where d.valid {
                let name = d.label.trimmingCharacters(in: .whitespaces)
                let l = Liability(
                    name: name.isEmpty ? "分期" : name,
                    kind: .installment, category: .credit,
                    principal: d.totalAmount,
                    totalPeriods: d.total,
                    paidPeriods: min(max(d.cur - 1, 0), d.total),
                    feeMode: .none, feeValue: 0,
                    billDay: 1, dueDay: 25, startMonth: "",
                    iconChar: "分", iconHex: 0x8E8E93,
                    linkedAccountID: accountID, sortOrder: base + offset,
                    perPeriodAmount: d.per,
                    firstPeriodAmount: d.showFirst ? d.first : 0,
                    totalRepayAmount: d.showTotal ? d.repay : 0)
                modelContext.insert(l)
                offset += 1
            }
        }
        try? modelContext.save()
    }

    private func apply(_ d: PlanDraft, to l: Liability) {
        let name = d.label.trimmingCharacters(in: .whitespaces)
        l.name = name.isEmpty ? "分期" : name
        l.totalPeriods = d.total
        l.paidPeriods = min(max(d.cur - 1, 0), d.total)
        l.perPeriodAmount = d.per
        l.firstPeriodAmount = d.showFirst ? d.first : 0
        l.totalRepayAmount = d.showTotal ? d.repay : 0
        l.principal = d.totalAmount
        l.feeModeRaw = FeeMode.none.rawValue
        l.feeValue = 0
        l.linkedAccountID = accountID
    }

    private func money(_ d: Decimal) -> String {
        Money.string(NSDecimalNumber(decimal: d).doubleValue)
    }
}

// MARK: - 录入草稿（一笔分期）

/// 全部字段用 `String` 存（输入中允许空），保存时再解析 —— 避免「空串 → 0」的中间态抖动。
private struct PlanDraft: Identifiable {
    let id = UUID()
    var label = ""
    /// 账单上的「第 x 期」（1-based）
    var currentPeriod = "1"
    var totalPeriods = "12"
    var perPeriod = ""
    var showFirst = false
    var firstPeriod = ""
    // 2026-10-12 方案 A：合计（本金 ＋ 手续费/利息）—— 用来反解末期差额
    var showTotal = false
    var repayTotal = ""

    var cur: Int { max(Int(currentPeriod) ?? 1, 1) }
    var total: Int { max(Int(totalPeriods) ?? 1, 1) }
    var per: Decimal { Decimal(string: perPeriod) ?? 0 }
    var first: Decimal { Decimal(string: firstPeriod) ?? 0 }
    var repay: Decimal { Decimal(string: repayTotal) ?? 0 }

    /// 可保存：期数 ≥ 1 且每期金额 > 0
    var valid: Bool { per > 0 && total >= 1 }

    /// 由「合计」反解的末期金额 —— 与 `DebtEngine.lastAmount` 同一公式
    var derivedLast: Decimal {
        guard total > 1, repay > 0 else { return per }
        let firstAmt = (showFirst && first > 0) ? first : per
        let derived = repay - firstAmt - Decimal(max(total - 2, 0)) * per
        return derived > 0 ? derived : per
    }

    /// 总还款额 —— 填了「合计」就用它，否则「首期 + 其余期（每期）」。
    /// 存进 `principal`，保持旧字段语义。
    var totalAmount: Decimal {
        if showTotal && repay > 0 { return repay }
        let n = Decimal(total)
        let firstAmt = (showFirst && first > 0) ? first : per
        return firstAmt + max(n - 1, 0) * per
    }
}

#Preview { AddInstallmentSheet() }
