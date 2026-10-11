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
                    .scaledFont(17, weight: .bold)
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
                            .scaledFont(13.5, weight: .semibold)
                            .foregroundStyle(Theme.greenText)
                            .frame(maxWidth: .infinity).padding(.vertical, 12)
                            .background(Theme.greenSoft).cornerRadius(12)
                    }
                    .buttonStyle(PressableButtonStyle(scale: 0.985))
                }

                hintCard

                Button {
                    Haptics.success()
                    save()
                    dismiss()
                } label: {
                    Text(isBatch ? "保存 \(validCount) 笔分期" : "保存修改")
                        .scaledFont(15, weight: .semibold).foregroundStyle(.white)
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
                Text("第").scaledFont(12.5).foregroundStyle(.secondary)
                numField($drafts[i].currentPeriod, width: 32)
                Text("/").scaledFont(12.5).foregroundStyle(.secondary)
                numField($drafts[i].totalPeriods, width: 36)
                Text("期").scaledFont(12.5).foregroundStyle(.secondary)
                Spacer(minLength: 6)
                if isBatch && drafts.count > 1 {
                    Button {
                        Haptics.tap()
                        drafts.remove(at: i)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .scaledFont(15).foregroundStyle(.tertiary)
                    }
                    .buttonStyle(PressableButtonStyle(scale: 0.9))
                    .accessibilityLabel("删除这一笔")
                }
            }

            // 每期金额
            HStack(spacing: 8) {
                Text("每期").scaledFont(12.5).foregroundStyle(.secondary)
                TextField("0.00", text: $drafts[i].perPeriod)
                    .keyboardType(.decimalPad)
                    .scaledFont(17, weight: .semibold).monospacedDigit()
                    .multilineTextAlignment(.trailing)
                    .accessibilityLabel("每期金额")
                Text("元").scaledFont(12.5).foregroundStyle(.secondary)
            }

            // 备注（可选）
            TextField("备注（可选，如 手机分期）", text: $drafts[i].label)
                .scaledFont(12.5)
                .padding(.horizontal, 10).padding(.vertical, 8)
                .background(Theme.iconBg)
                .cornerRadius(8)

            // 首期（默认隐藏 —— 只多一个几乎看不见的入口）
            if d.showFirst {
                HStack(spacing: 8) {
                    Text("首期").scaledFont(12.5).foregroundStyle(.secondary)
                    TextField("0.00", text: $drafts[i].firstPeriod)
                        .keyboardType(.decimalPad)
                        .scaledFont(15, weight: .semibold).monospacedDigit()
                        .multilineTextAlignment(.trailing)
                    Text("元").scaledFont(12.5).foregroundStyle(.secondary)
                    Button {
                        Haptics.tap()
                        drafts[i].showFirst = false
                        drafts[i].firstPeriod = ""
                    } label: {
                        Text("收起").scaledFont(11).foregroundStyle(.secondary)
                            .padding(.horizontal, 8).padding(.vertical, 5)
                            .background(Theme.iconBg).cornerRadius(7)
                    }
                    .buttonStyle(PressableButtonStyle(scale: 0.95))
                }
                firstHint(d)
            } else {
                Button {
                    Haptics.tap()
                    drafts[i].showFirst = true
                } label: {
                    Text("＋首期").scaledFont(11).foregroundStyle(.tertiary)
                }
                .buttonStyle(PressableButtonStyle(scale: 0.95))
                .accessibilityHint("首期与其余期不同时才需要填")
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
                 ? "首期多 ¥\(money(diff)) —— 尾差（除不尽归首期），不填也行"
                 : "首期多 ¥\(money(diff)) —— 手续费一次性收取，必须填，否则会少算")
                .scaledFont(11)
                .foregroundStyle(diff <= 1 ? Color.secondary : Theme.redText)
        } else if d.first > 0 {
            Text("首期与每期一样，可以不填")
                .scaledFont(11).foregroundStyle(.secondary)
        }
    }

    /// 说明卡：只在补录模式显示，且不啰嗦
    private var hintCard: some View {
        Text("账单写「第 2/12 期 ¥120.03」就填 **2**、**12**、**120.03**。「一共欠多少」不用在这里录 —— 那是账户余额的事，用详情页的「调整」对账。")
            .scaledFont(11.5)
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
                            accountIcon(acc)
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

    /// 账户图标（归一化素材：通用 Fluent 3D / 品牌真实 logo）
    private func accountIcon(_ acc: Account) -> some View {
        Group {
            if !acc.icon.asset.isEmpty, UIImage(named: acc.icon.asset) != nil {
                // ⚠️ 彩色贴图：不要加 .renderingMode(.template)
                Image(acc.icon.asset).resizable().scaledToFit()
            } else if !acc.icon.emoji.isEmpty {
                Text(acc.icon.emoji).scaledFont(15)
            } else {
                Text(acc.kind.logoChar)
                    .scaledFont(13, weight: .semibold).foregroundStyle(.white)
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
            .scaledFont(14, weight: .semibold).monospacedDigit()
            .multilineTextAlignment(.center)
            .frame(width: width)
            .padding(.vertical, 7)
            .background(Theme.iconBg)
            .cornerRadius(8)
    }

    @ViewBuilder
    private func field<C: View>(_ label: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).scaledFont(11.5).foregroundStyle(.secondary)
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
                    firstPeriodAmount: d.showFirst ? d.first : 0)
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

    var cur: Int { max(Int(currentPeriod) ?? 1, 1) }
    var total: Int { max(Int(totalPeriods) ?? 1, 1) }
    var per: Decimal { Decimal(string: perPeriod) ?? 0 }
    var first: Decimal { Decimal(string: firstPeriod) ?? 0 }

    /// 可保存：期数 ≥ 1 且每期金额 > 0
    var valid: Bool { per > 0 && total >= 1 }

    /// 总还款额（首期 + 其余期）—— 存进 `principal`，保持旧字段语义
    var totalAmount: Decimal {
        let n = Decimal(total)
        let firstAmt = (showFirst && first > 0) ? first : per
        return firstAmt + max(n - 1, 0) * per
    }
}

#Preview { AddInstallmentSheet() }
