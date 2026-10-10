import SwiftUI
import SwiftData

/// 负债页（负债与可支配-方案-v1）
/// 结构：绿色重卡（待还总额+进度）+ 按项目/按月份 分段 + 本月还款合计
/// 视觉对照：site/prototype-debt.html #debt
struct DebtView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Liability.sortOrder) private var liabilities: [Liability]

    @State private var showAdd = false
    @State private var editing: Liability?
    @State private var mode = 0            // 0 按项目 / 1 按月份
    @State private var confirmPaying: Liability?
    @State private var showSettle = false
    // CI 截图钩子：初始进「按月份」档
    private let ciArgs = ProcessInfo.processInfo.arguments

    private var creditList: [Liability] { liabilities.filter { $0.category == .credit } }
    private var fixedList: [Liability] { liabilities.filter { $0.category == .fixedExpense } }
    private var totalRemaining: Decimal { DebtEngine.totalRemaining(liabilities) }
    private var dueThisMonth: Decimal {
        liabilities.reduce(Decimal(0)) { $0 + DebtEngine.dueThisMonth($1) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Radius.cardSpacing) {
                    heroCard
                    if liabilities.isEmpty {
                        EmptyStateCard(icon: "💳", title: "还没有负债",
                                       hint: "点右上角 ＋ 建档，一次录入自动滚动")
                    } else {
                        segPicker
                        if mode == 0 { projectView } else { monthView }
                        settleButton
                    }
                }
                .padding(.horizontal, Radius.pagePadding)
                .padding(.top, 8)
                .padding(.bottom, 150)
            }
            .background(Theme.bg)
            .navigationTitle("负债")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Haptics.tap(); showAdd = true } label: {
                        Image(systemName: "plus").scaledFont(16, weight: .semibold)
                    }
                    .accessibilityLabel("新建负债")
                }
            }
        }
        .sheet(isPresented: $showAdd) {
            AddLiabilitySheet()
                .presentationDetents([.fraction(0.68), .large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(item: $editing) { l in
            AddLiabilitySheet(editing: l)
                .presentationDetents([.fraction(0.68), .large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(item: $confirmPaying) { l in
            PayConfirmCard(liability: l)
                .presentationDetents([.height(360)])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showSettle) {
            SettleView()
                .presentationDetents([.large])
        }
        .onAppear {
            if ciArgs.contains("-ci-tab-month") { mode = 1 }
        }
    }

    // MARK: 绿色重卡

    private var heroCard: some View {
        LinearGradient(colors: [Theme.green, Theme.greenDeep], startPoint: .top, endPoint: .bottom)
            .overlay(alignment: .bottom) {
                Ellipse().fill(Color.white.opacity(0.14))
                    .frame(height: 44).frame(maxWidth: .infinity).offset(y: 34)
            }
            .overlay {
                VStack(alignment: .leading, spacing: 0) {
                    Text("待还总额（本金+手续费）")
                        .scaledFont(12).foregroundStyle(.white.opacity(0.88))
                    Text("¥ \(Money.string(dec(totalRemaining)))")
                        .scaledFont(34, weight: .heavy, design: .rounded)
                        .foregroundStyle(.white).monospacedDigit()
                        .padding(.top, 4)
                    Text(summaryLine)
                        .scaledFont(11.5).foregroundStyle(.white.opacity(0.85))
                        .padding(.top, 5)

                    HStack(spacing: 10) {
                        heroCol("本月应还", "¥\(Money.string(dec(dueThisMonth)))")
                        heroCol("已还", "¥\(Money.string(dec(paidTotal)))")
                    }
                    .padding(.top, 14)

                    HStack {
                        Text("总进度 \(Int(overallProgress * 100))%")
                        Spacer()
                        Text("剩余 \(remainingPeriodsTotal) 期")
                    }
                    .scaledFont(11).foregroundStyle(.white.opacity(0.9))
                    .padding(.top, 12)
                }
                .padding(18)
            }
            .frame(height: 196)
            .clipShape(RoundedRectangle(cornerRadius: Radius.large))
    }

    private func heroCol(_ k: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(k).scaledFont(10.5).foregroundStyle(.white.opacity(0.85))
            Text(v).scaledFont(15, weight: .bold).foregroundStyle(.white).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 11).padding(.vertical, 9)
        .background(Color.white.opacity(0.15))
        .cornerRadius(12)
    }

    private var paidTotal: Decimal {
        liabilities.reduce(Decimal(0)) { sum, l in
            guard l.kind == .installment else { return sum }
            return sum + DebtEngine.perPeriod(l) * Decimal(l.paidPeriods)
        }
    }
    private var overallProgress: Double {
        let total = liabilities.filter { $0.kind == .installment }.reduce(0) { $0 + $1.totalPeriods }
        let paid = liabilities.filter { $0.kind == .installment }.reduce(0) { $0 + $1.paidPeriods }
        guard total > 0 else { return 0 }
        return Double(paid) / Double(total)
    }
    private var remainingPeriodsTotal: Int {
        liabilities.reduce(0) { $0 + DebtEngine.remainingPeriods($1) }
    }
    private var summaryLine: String {
        "共 \(liabilities.count) 项" + (lastEndMonth.map { " · 全部还完约在 \($0)" } ?? "")
    }
    private var lastEndMonth: String? {
        let maxLeft = liabilities.filter { $0.kind == .installment }
            .map { DebtEngine.remainingPeriods($0) }.max() ?? 0
        guard maxLeft > 0 else { return nil }
        let cal = Calendar.current
        let d = cal.date(byAdding: .month, value: maxLeft, to: .now) ?? .now
        let f = DateFormatter(); f.dateFormat = "yyyy 年 M 月"
        return f.string(from: d)
    }

    // MARK: 分段

    private var segPicker: some View {
        HStack(spacing: 6) {
            segBtn("按项目", 0)
            segBtn("按月份", 1)
        }
        .padding(4)
        .background(Color(hex: 0xEDEDEB))
        .cornerRadius(12)
    }
    private func segBtn(_ t: String, _ v: Int) -> some View {
        Button {
            Haptics.tap()
            withAnimation(Motion.fade) { mode = v }
        } label: {
            Text(t)
                .scaledFont(12.5, weight: .medium)
                .foregroundStyle(mode == v ? .primary : .secondary)
                .frame(maxWidth: .infinity).padding(.vertical, 8)
                .background(mode == v ? Theme.card : Color.clear)
                .cornerRadius(9)
                .shadow(color: .black.opacity(mode == v ? 0.06 : 0), radius: 2, y: 1)
        }
        .buttonStyle(PressableButtonStyle(scale: 0.98))
    }

    // MARK: 按项目

    private var projectView: some View {
        VStack(spacing: 14) {
            if !creditList.isEmpty {
                groupSection("信用类", creditList,
                             total: creditList.reduce(Decimal(0)) { $0 + DebtEngine.dueThisMonth($1) },
                             headerNote: "本月应还")
            }
            if !fixedList.isEmpty {
                groupSection("固定支出", fixedList,
                             total: fixedList.reduce(Decimal(0)) { $0 + DebtEngine.dueThisMonth($1) },
                             headerNote: "每月自动 · 不计负债")
            }
            HStack {
                Text("本月还款合计").scaledFont(13.5, weight: .semibold)
                Spacer()
                Text("¥ \(Money.string(dec(dueThisMonth)))")
                    .scaledFont(13.5, weight: .semibold).monospacedDigit()
            }
            .padding(.top, 4)
        }
    }

    private func groupSection(_ title: String, _ list: [Liability],
                              total: Decimal, headerNote: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Text(title).scaledFont(13, weight: .semibold)
                Spacer()
                Text("\(headerNote) ¥ \(Money.string(dec(total)))")
                    .scaledFont(11.5).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
            ForEach(list, id: \.id) { l in
                liabilityRow(l)
            }
        }
    }

    private func liabilityRow(_ l: Liability) -> some View {
        Button { Haptics.tap(); editing = l } label: {
            HStack(spacing: 12) {
                Text(l.iconChar)
                    .scaledFont(15, weight: .semibold).foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Color(hex: l.iconHex))
                    .cornerRadius(12)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(l.name).scaledFont(14, weight: .semibold)
                        kindPill(l)
                    }
                    Text(subLine(l)).scaledFont(11).foregroundStyle(.secondary)
                    if l.kind == .installment {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color(hex: 0xF0F0EE)).frame(height: 5)
                                Capsule().fill(Theme.green)
                                    .frame(width: max(geo.size.width * DebtEngine.progress(l), 0), height: 5)
                            }
                        }
                        .frame(height: 5)
                        .padding(.top, 5)
                    }
                }
                Spacer(minLength: 8)
                Text("¥\(Money.string(dec(DebtEngine.dueThisMonth(l))))")
                    .scaledFont(15, weight: .semibold).monospacedDigit()
            }
            .padding(14)
            .background(Theme.card)
            .cornerRadius(Radius.medium)
            .shadow(color: .black.opacity(0.04), radius: 3, y: 1)
        }
        .buttonStyle(PressableButtonStyle(scale: 0.985))
        .contextMenu {
            Button {
                Haptics.tap(); confirmPaying = l
            } label: {
                Label("标记已还款", systemImage: "checkmark.circle")
            }
            Button {
                Haptics.tap(); editing = l
            } label: {
                Label("编辑", systemImage: "pencil")
            }
            Button(role: .destructive) {
                Haptics.tap()
                modelContext.delete(l)
                try? modelContext.save()
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
        .accessibilityHint("打开负债详情，长按可标记还款")
    }

    @ViewBuilder
    private func kindPill(_ l: Liability) -> some View {
        let (bg, fg): (Color, Color) = {
            switch l.category {
            case .credit: return (Color(hex: 0xFCF3E2), Color(hex: 0x8A5A0B))
            case .fixedExpense: return (Color(hex: 0xEAF1FE), Theme.blueText)
            }
        }()
        Text(l.kind == .installment ? "分期 \(l.totalPeriods) 期" : l.kind.label)
            .scaledFont(10, weight: .medium).foregroundStyle(fg)
            .padding(.horizontal, 6).padding(.vertical, 1.5)
            .background(bg).cornerRadius(6)
    }

    private func subLine(_ l: Liability) -> String {
        switch l.kind {
        case .installment:
            return "还款日 \(l.dueDay) 日 · 第 \(l.paidPeriods)/\(l.totalPeriods) 期"
        case .currentBill:
            return "还款日 \(l.dueDay) 日 · 本月账单"
        case .fixed:
            return "每月 \(l.dueDay) 日 · 固定"
        }
    }

    // MARK: 按月份（未来 12 个月预测）

    private var monthView: some View {
        let pay = Decimal(WageConfig.load().takeHomePay)
        let fc = DebtEngine.forecast(takeHomePay: pay, liabilities: liabilities, months: 12)
        let maxV = fc.map { $0.1 }.max() ?? 1
        return VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                Text("未来 12 个月").scaledFont(12.5, weight: .semibold)
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(fc, id: \.0) { item in
                        VStack(spacing: 4) {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(item.0 == 0 ? Theme.green
                                      : (item.1 > (fc.first?.1 ?? 0) ? Theme.greenDeep : Color(hex: 0xC9CDD1)))
                                .frame(height: barHeight(item.1, maxV: maxV))
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .frame(height: 130)
                Text("柱高 = 当月可支配（到手 − 应还）。柱子越长，越松。\n每根柱子随债务还完自动升高，不用手动改。")
                    .scaledFont(11).foregroundStyle(.secondary)
                    .lineSpacing(3)
            }
            .padding(16)
            .background(Theme.card)
            .cornerRadius(Radius.large)

            VStack(alignment: .leading, spacing: 9) {
                Text("逐月明细").scaledFont(13, weight: .semibold).padding(.horizontal, 4)
                ForEach(Array(fc.enumerated()), id: \.offset) { idx, item in
                    if idx == 0 || idx == fc.count - 1 || monthHasChange(fc, idx) {
                        monthRow(offset: item.0, disposable: item.1, due: item.2,
                                 first: fc.first?.1 ?? 0)
                    }
                }
            }
        }
    }

    private func monthHasChange(_ fc: [(Int, Decimal, Decimal)], _ idx: Int) -> Bool {
        guard idx > 0 else { return false }
        return fc[idx].1 != fc[idx - 1].1
    }

    private func monthRow(offset: Int, disposable: Decimal, due: Decimal, first: Decimal) -> some View {
        let cal = Calendar.current
        let d = cal.date(byAdding: .month, value: offset, to: .now) ?? .now
        let f = DateFormatter(); f.dateFormat = "yyyy 年 M 月"
        let looser = disposable > first
        return HStack(spacing: 12) {
            Text(offset == 0 ? "本月" : f.string(from: d))
                .scaledFont(12.5, weight: .semibold)
                .foregroundStyle(.secondary)
                .frame(width: 78, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text("应还 ¥\(Money.string(dec(due)))").scaledFont(11).foregroundStyle(.secondary)
            }
            Spacer()
            Text("¥\(Money.string(dec(disposable)))")
                .scaledFont(15, weight: .semibold).monospacedDigit()
                .foregroundStyle(looser ? Theme.greenText : .primary)
        }
        .padding(14)
        .background(Theme.card)
        .cornerRadius(Radius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.medium)
                .stroke(offset == 0 ? Theme.green : .clear, lineWidth: offset == 0 ? 1.5 : 0)
        )
    }

    // MARK: 结算入口

    private var settleButton: some View {
        Button { Haptics.tap(); showSettle = true } label: {
            Text("本月全部还款")
                .scaledFont(15, weight: .semibold).foregroundStyle(.white)
                .frame(maxWidth: .infinity).padding(.vertical, 15)
                .background(Theme.green)
                .cornerRadius(14)
                .shadow(color: Theme.green.opacity(0.32), radius: 10, y: 5)
        }
        .buttonStyle(PressableButtonStyle(scale: 0.985))
        .padding(.top, 6)
    }

    private func dec(_ d: Decimal) -> Double { NSDecimalNumber(decimal: d).doubleValue }

    /// 柱高：value / max × 120，最低 6pt
    private func barHeight(_ value: Decimal, maxV: Decimal) -> CGFloat {
        let ratio = dec(value) / max(dec(maxV), 1)
        return CGFloat(max(ratio * 120, 6))
    }
}

#Preview { DebtView() }
