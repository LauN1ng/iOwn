import SwiftUI
import SwiftData

// MARK: - 保存结果（供成功屏 A4 使用）

struct SavedEntryInfo {
    let amount: Decimal
    let isOut: Bool
    let categoryName: String
    let subName: String
    let mood: Mood?
    let todayCount: Int
    let streak: Int
}

/// 记一笔两段式 sheet（A1）：①意图分类宫格 ②二级分类横滑 + 4 列键盘
/// M2-B2：账户选择 chip（余额自动联动）+ editing 模式（点流水改账，原地更新）
/// v1.3 动效：宫格↔金额改为可中断的 push 位移转场；键盘/宫格/chips 全部加按下反馈 + 触觉
/// 视觉对照：site/prototype.html #entry；验收：点 FAB 到保存 ≤3 秒
struct AddEntrySheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \Account.name) private var accounts: [Account]
    @Query private var liabilities: [Liability]
    var onSaved: (SavedEntryInfo, Bool) -> Void   // (结果, 是否展示成功屏)；再记=false 只入库
    var editing: Tx? = nil                        // 非 nil = 编辑该笔（B2 改账）

    /// 显式 init：@Query 等包装属性会被 memberwise init 暴露成 `_accounts` 参数，屏蔽掉
    init(editing: Tx? = nil,
         onSaved: @escaping (SavedEntryInfo, Bool) -> Void) {
        self.editing = editing
        self.onSaved = onSaved
    }

    @State private var stage = 0               // 0 宫格 / 1 金额
    @State private var category: CategoryDef?
    @State private var sub: CategoryDef.SubDef?
    @State private var amountStr = ""          // 金额输入串（从个位起输，"." 后最多两位）
    @State private var isOut = true
    @State private var note = ""
    @State private var mood: Mood?
    @State private var date = Date.now
    @State private var selectedAccountID: String?   // B2：nil = 不挂账户
    @State private var prefilled = false
    // D18：信用支付时选「全额下期 / 分期 N 期」
    @State private var payFull = true              // true = 全额下期；false = 分期
    @State private var installmentPeriods = 12

    /// 当前金额（分）；空串/非法 = 0
    private var amountCents: Int {
        guard !amountStr.isEmpty, let v = Double(amountStr), v.isFinite, v > 0 else { return 0 }
        return Int((v * 100).rounded())
    }

    /// 金额显示串：始终两位小数（视觉基准 §4.2「金额大字绿 ¥0.00」）
    /// 空 → 0.00；整数输入 50 → 50.00；小数位输入中 21.9 → 21.90
    private var amountDisplay: String {
        guard !amountStr.isEmpty else { return "0.00" }
        guard let dot = amountStr.firstIndex(of: ".") else { return amountStr + ".00" }
        let intPart = String(amountStr[amountStr.startIndex..<dot])
        let decPart = String(amountStr[amountStr.index(after: dot)...])
        return intPart + "." + decPart.padding(toLength: 2, withPad: "0", startingAt: 0)
    }

    private let keyH: CGFloat = 54
    private let gap: CGFloat = 10

    // MARK: 信用支付联动（D18）

    private var selectedAccount: Account? { accounts.first { $0.id == selectedAccountID } }
    private var isCreditSelected: Bool { selectedAccount?.kind.isCredit == true }

    /// 花呗标准档总费率（与负债模块同一套口径）
    private func standardRate(_ n: Int) -> Double {
        switch n {
        case 3: 2.5; case 6: 4.5; case 9: 6.5; case 12: 8.8; case 24: 15.6
        default: 8.8
        }
    }

    private var installmentHint: String {
        let amount = Decimal(amountCents) / 100
        let rate = Decimal(standardRate(installmentPeriods))
        let total = amount + amount * rate / 100
        let per = total / Decimal(max(installmentPeriods, 1))
        let apr = DebtEngine.aprFromTotalRate(ratePercent: rate, periods: installmentPeriods)
        return "每期 ¥\(Money.string(dec(per))) · 实际年化 \(String(format: "%.2f", dec(apr)))%"
    }

    /// 本次记一笔的付款方式
    private var paymentMethod: PayMethod {
        guard isOut, isCreditSelected else { return .normal }
        return payFull ? .creditFull : .creditInstallment
    }

    /// 落地负债：只有「分期」才新建计划；全额下期靠账户余额自动进当期欠款。
    /// 编辑已有分期笔时同步本金，避免与 Tx 金额漂移。
    private func syncLiability(for tx: Tx) {
        guard let acc = selectedAccount, acc.kind.isCredit else { return }
        guard tx.payMethod == .creditInstallment else { return }
        if let id = tx.liabilityID, let existing = liabilities.first(where: { $0.id == id }) {
            existing.principal = tx.amount
            if !tx.note.isEmpty { existing.name = tx.note }
        } else {
            _ = LiabilityLinker.apply(tx: tx, account: acc, periods: installmentPeriods,
                                      feeRate: Decimal(standardRate(installmentPeriods)),
                                      context: modelContext)
        }
    }

    private func dec(_ d: Decimal) -> Double { NSDecimalNumber(decimal: d).doubleValue }

    var body: some View {
        VStack(spacing: 0) {
            SheetGrabber()

            // 两阶段在 ZStack 内重叠，转场期间不会互相顶开导致布局跳动
            ZStack(alignment: .top) {
                if stage == 0 {
                    stageGrid.transition(reduceMotion ? AnyTransition.opacity : AnyTransition.push(from: .leading))
                } else {
                    stageAmount.transition(reduceMotion ? AnyTransition.opacity : AnyTransition.push(from: .trailing))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.bg)
        .onAppear {
            prefillForEditing()
            // CI 截图钩子（自读启动参数，避免改动 memberwise init 签名）
            if editing == nil, ProcessInfo.processInfo.arguments.contains("-ci-open-amount") {
                category = CategoryPresets.all.first
                sub = category?.subs.first
                amountStr = "21.9"
                stage = 1
            }
        }
    }

    /// 阶段切换：带方向感知的位移转场（减弱动效时退化为短淡入，不锁输入、可被再点打断）
    private func go(to newStage: Int) {
        withAnimation(reduceMotion ? Motion.reduceFallback : Motion.stage) { stage = newStage }
    }

    /// B2 改账预填：直接进金额页（阶段 2），分类/金额/备注/心情/账户/日期全部带出
    private func prefillForEditing() {
        guard !prefilled, let tx = editing else { return }
        prefilled = true
        isOut = tx.type == .out
        category = CategoryPresets.category(id: tx.categoryID)
        sub = category?.subs.first { $0.id == tx.subID }
        note = tx.note
        mood = tx.mood
        date = tx.date
        selectedAccountID = tx.accountID
        // D18：回填付款方式（分期笔的期数从关联负载取）
        payFull = tx.payMethod != .creditInstallment
        if let id = tx.liabilityID,
           let plan = liabilities.first(where: { $0.id == id }), plan.totalPeriods > 1 {
            installmentPeriods = plan.totalPeriods
        }
        let v = NSDecimalNumber(decimal: tx.amount).doubleValue
        amountStr = v == v.rounded() && v < 1_000_000
            ? String(Int(v))
            : String(format: "%.2f", v)
        stage = 1
    }

    // MARK: 阶段 1：分类宫格

    private var stageGrid: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 16) {
                Text("支出").scaledFont(20, weight: .bold)
                    .foregroundStyle(isOut ? Theme.greenText : Color.secondary.opacity(0.4))
                    .contentShape(Rectangle())
                    .onTapGesture { isOut = true }
                    .accessibilityAddTraits(isOut ? [.isButton, .isSelected] : .isButton)
                    .accessibilityLabel("支出")
                Text("收入").scaledFont(20, weight: .bold)
                    .foregroundStyle(!isOut ? Theme.greenText : Color.secondary.opacity(0.4))
                    .contentShape(Rectangle())
                    .onTapGesture { isOut = false }
                    .accessibilityAddTraits(!isOut ? [.isButton, .isSelected] : .isButton)
                    .accessibilityLabel("收入")
                Spacer()
                Button {
                    Haptics.tap()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .scaledFont(15, weight: .semibold)
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .background(Theme.card)
                        .clipShape(Circle())
                }
                .buttonStyle(PressableButtonStyle(scale: 0.92))
                .accessibilityLabel("关闭")
                Image(systemName: "gearshape").foregroundStyle(.tertiary) // TODO(M3-A5) 分类管理入口
                    .accessibilityHidden(true)                            // 未接线：不进无障碍树
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 16) {
                ForEach(CategoryPresets.all) { cat in
                    Button {
                        Haptics.tap()
                        category = cat
                        sub = cat.subs.first
                        go(to: 1)
                    } label: {
                        VStack(spacing: 8) {
                            Text(cat.emoji).scaledFont(34).accessibilityHidden(true)  // 装饰：名称已念出
                            Text(cat.name).scaledFont(12.5, weight: .medium)
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.card)
                        .cornerRadius(Radius.medium)
                    }
                    .buttonStyle(PressableButtonStyle())
                }
                CellButton(emoji: "＋", name: "添加") {} // TODO(M3-A5) 自定义大类
                    .accessibilityHint("自定义大类，后续版本开放")
            }

            HStack {
                Text("⚡ 快捷分类")
                    .scaledFont(13.5, weight: .semibold)
                    .foregroundStyle(Theme.greenText)
                Spacer()
                Text("›").foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(Theme.card)
            .cornerRadius(Radius.medium)
        }
        .padding(.horizontal, Radius.pagePadding)
        .padding(.bottom, 20)
    }

    // MARK: 阶段 2：金额 + 键盘

    private var stageAmount: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Button {
                    Haptics.tap()
                    go(to: 0)
                } label: {
                    Image(systemName: "arrow.left").scaledFont(16, weight: .semibold)
                        .foregroundStyle(.primary)
                }
                .buttonStyle(PressableButtonStyle(scale: 0.9))
                .accessibilityLabel("返回分类选择")
                Text(category?.name ?? "")
                    .scaledFont(12).foregroundStyle(.secondary)
                Text(sub?.name ?? "")
                    .scaledFont(22, weight: .bold)
                Spacer()
                if editing == nil {
                    Button {
                        Haptics.tap()
                        saveAndContinue()
                    } label: {
                        Text("再记").scaledFont(13, weight: .semibold)
                            .foregroundStyle(Theme.greenText)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(Theme.greenSoft)
                            .cornerRadius(9)
                    }
                    .buttonStyle(PressableButtonStyle(scale: 0.94))
                    .accessibilityHint("保存这一笔并继续记下一笔")
                }
                Button {
                    Haptics.tap()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .scaledFont(15, weight: .semibold)
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .background(Theme.card)
                        .clipShape(Circle())
                }
                .buttonStyle(PressableButtonStyle(scale: 0.92))
                .accessibilityLabel("关闭")
            }
            .padding(.horizontal, Radius.pagePadding)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(category?.subs ?? []) { s in
                        Button {
                            Haptics.tap()
                            sub = s
                        } label: {
                            HStack(spacing: 6) {
                                Text(s.emoji).scaledFont(16).accessibilityHidden(true)
                                Text(s.name).scaledFont(13.5, weight: .medium)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .background(sub?.id == s.id ? Theme.green : Theme.card)
                            .foregroundStyle(sub?.id == s.id ? Color.white : Color.primary)
                            .cornerRadius(Radius.small)
                        }
                        .buttonStyle(PressableButtonStyle(scale: 0.94))
                        .accessibilityAddTraits(sub?.id == s.id ? [.isButton, .isSelected] : .isButton)
                    }
                    ChipLabel(emoji: "＋", name: "添加")  // TODO(M3-A5) 自定义二级
                        .accessibilityHint("自定义二级分类，后续版本开放")
                    ChipLabel(emoji: "⚙", name: "设置")
                        .accessibilityHint("二级分类设置，后续版本开放")
                }
                .padding(.horizontal, Radius.pagePadding)
            }
            .padding(.top, 14)

            Text("¥ \(amountDisplay)")
                .scaledFont(42, weight: .heavy, design: .rounded)
                .foregroundStyle(Theme.greenText)
                .monospacedDigit()
                .tracking(-0.5)                       // 大字收紧字距（apple-design §15）
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 18)

            HStack(spacing: 12) {
                TextField("备注", text: $note)
                    .scaledFont(14)
                    .accessibilityLabel("备注")
                Button {
                    Haptics.tap()
                    mood = mood?.next() ?? .normal   // 心情轮换（A3）：nil→😐→🥰→🤯→😤→nil
                } label: {
                    Text(mood.map { "\($0.emoji) \($0.label)" } ?? "心情＋")
                        .scaledFont(12)
                        .foregroundStyle(mood == nil ? Color.secondary : Color.primary)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Theme.bg)
                        .cornerRadius(999)
                }
                .buttonStyle(PressableButtonStyle(scale: 0.94))
                .accessibilityLabel(mood.map { "心情：\($0.label)" } ?? "添加心情")
                .accessibilityHint("点按轮换心情")
                Image(systemName: "plus.circle.dashed").foregroundStyle(.tertiary) // 附件预留
                    .accessibilityHidden(true)                                      // 未接线
            }
            .padding(12)
            .background(Theme.card)
            .cornerRadius(Radius.medium)
            .padding(.horizontal, Radius.pagePadding)

            // B2 账户联动：选账户 → 余额自动扣减/增加
            if !accounts.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(accounts, id: \.id) { acc in
                            let selected = selectedAccountID == acc.id
                            Button {
                                Haptics.tap()
                                selectedAccountID = selected ? nil : acc.id
                            } label: {
                                HStack(spacing: 6) {
                                    Text(acc.kind.logoChar)
                                        .scaledFont(11, weight: .bold)
                                        .foregroundStyle(.white)
                                        .frame(width: 18, height: 18)
                                        .background(Color(hex: acc.kind.brandColorHex))
                                        .cornerRadius(5)
                                        .accessibilityHidden(true)   // 装饰：账户名已念出
                                    Text(acc.name).scaledFont(12.5, weight: .medium)
                                }
                                .padding(.horizontal, 10).padding(.vertical, 7)
                                .background(selected ? Theme.green : Theme.card)
                                .foregroundStyle(selected ? Color.white : Color.primary)
                                .cornerRadius(999)
                            }
                            .buttonStyle(PressableButtonStyle(scale: 0.94))
                            .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
                        }
                    }
                    .padding(.horizontal, Radius.pagePadding)
                }
                .padding(.top, 10)
            }

            // D18：选了「信用类账户」才出现付款方式 —— 全额下期不建负债；
            // 选分期则保存时自动在该账户名下生成一笔分期计划
            if isCreditSelected && isOut {
                VStack(alignment: .leading, spacing: 8) {
                    Text("付款方式").scaledFont(11.5).foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        payChip("全额下期", on: payFull) { payFull = true }
                        ForEach([3, 6, 12, 24], id: \.self) { n in
                            payChip("\(n) 期", on: !payFull && installmentPeriods == n) {
                                payFull = false
                                installmentPeriods = n
                            }
                        }
                    }
                    if !payFull {
                        Text(installmentHint)
                            .scaledFont(11).foregroundStyle(Theme.blueText)
                    }
                }
                .padding(.horizontal, Radius.pagePadding)
                .padding(.top, 12)
            }

            keypad
                .padding(.horizontal, Radius.pagePadding)
                .padding(.top, 14)
                .padding(.bottom, 20)
        }
    }

    // MARK: 付款方式 chip（信用账户专用）

    private func payChip(_ t: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            Text(t).scaledFont(12.5)
                .foregroundStyle(on ? Theme.greenText : .secondary)
                .padding(.horizontal, 13).padding(.vertical, 8)
                .background(on ? Theme.greenSoft : Theme.card)
                .cornerRadius(9)
                .overlay(RoundedRectangle(cornerRadius: 9)
                    .stroke(on ? Theme.green : Theme.hairline, lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle(scale: 0.96))
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: 4 列键盘：白键 / 红⌫ / 今天 / ✓（灰→绿）

    private var keypad: some View {
        GeometryReader { geo in
            let colW = (geo.size.width - gap * 3) / 4
            HStack(spacing: gap) {
                VStack(spacing: gap) {
                    keyRow(["1", "2", "3"], colW)
                    keyRow(["4", "5", "6"], colW)
                    keyRow(["7", "8", "9"], colW)
                    keyRow([".", "0", "＋−"], colW)
                }
                VStack(spacing: gap) {
                    keyButton("⌫", style: .danger, size: CGSize(width: colW, height: keyH)) {
                        Haptics.key()
                        if !amountStr.isEmpty { amountStr.removeLast() }
                    }
                    keyButton("今天", style: .today, size: CGSize(width: colW, height: keyH)) {
                        Haptics.tap()
                        date = .now
                    }
                    keyButton("✓", style: .okActive(amountCents > 0), size: CGSize(width: colW, height: keyH * 2 + gap)) { saveAndDismiss() }
                }
            }
            .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(height: keyH * 4 + gap * 3)
    }

    private func keyRow(_ keys: [String], _ width: CGFloat) -> some View {
        HStack(spacing: gap) {
            ForEach(keys, id: \.self) { k in
                keyButton(k, style: .normal, size: CGSize(width: width, height: keyH)) { tap(k) }
            }
        }
    }

    private enum KeyStyle {
        case normal, danger, today
        case okActive(Bool)
    }

    private func keyButton(_ label: String, style: KeyStyle, size: CGSize, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .scaledFont(label == "✓" ? 22 : 19, weight: .bold)
                .frame(width: size.width, height: size.height)
                .background(backgroundColor(style))
                .foregroundStyle(foregroundColor(style))
                .cornerRadius(Radius.medium)
        }
        .buttonStyle(PressableButtonStyle(scale: 0.93))
        .accessibilityLabel(Self.keyAccessibilityLabel(label))
    }

    /// 键盘键位的 VoiceOver 名称（符号键必须翻译，否则只念出符号本身）
    private static func keyAccessibilityLabel(_ label: String) -> String {
        switch label {
        case "⌫": "删除"
        case "✓": "完成并保存"
        case "今天": "日期改为今天"
        case "＋−": "切换收入或支出"
        default: label
        }
    }

    private func backgroundColor(_ s: KeyStyle) -> Color {
        switch s {
        case .normal: Theme.card
        case .danger: Theme.dangerSoft
        case .today: Theme.greenSoft
        case .okActive(let active): active ? Theme.green : Theme.disabled
        }
    }

    private func foregroundColor(_ s: KeyStyle) -> Color {
        switch s {
        case .normal: .primary
        case .danger: Theme.redText
        case .today: Theme.greenText
        case .okActive(let active): active ? .white : Theme.disabledText
        }
    }

    private func tap(_ k: String) {
        Haptics.key()
        switch k {
        case "＋−":
            isOut.toggle()
        case ".":
            // 进小数模式：空串视为 "0."
            guard !amountStr.contains(".") else { return }
            amountStr = amountStr.isEmpty ? "0." : amountStr + "."
        default:
            guard let d = k.first, d.isNumber else { return }
            if let dot = amountStr.firstIndex(of: ".") {
                // 小数位最多两位（注意：split 会丢空子串，"21." 的空小数部会误判为 2 位）
                let decCount = amountStr.distance(from: amountStr.index(after: dot), to: amountStr.endIndex)
                guard decCount < 2, amountStr.count < 12 else { return }
                amountStr += k
            } else {
                // 整数位：首位 0 直接替换，上限 ¥1,000,000
                if amountStr == "0" { amountStr = k }
                else { guard amountStr.count < 7 else { return }; amountStr += k }
            }
        }
    }

    // MARK: 保存

    /// 入库（或原地更新编辑笔）并返回结果信息；是否弹成功屏由调用方决定
    @discardableResult
    private func save() -> SavedEntryInfo? {
        guard amountCents > 0, let category else { return nil }
        let info = SavedEntryInfo(
            amount: Decimal(amountCents) / 100,
            isOut: isOut,
            categoryName: category.name,
            subName: sub?.name ?? (isOut ? "支出" : "收入"),
            mood: mood,
            todayCount: Self.countToday(modelContext),
            streak: Self.streakDays(modelContext)
        )

        let method = paymentMethod
        if let tx = editing {
            // B2 改账：原地更新字段；余额为推导值，无需手动回滚
            tx.amount = Decimal(amountCents) / 100
            tx.type = isOut ? .out : .in
            tx.categoryID = category.id
            tx.subID = sub?.id
            tx.note = note
            tx.mood = mood
            tx.accountID = selectedAccountID
            tx.date = date
            tx.payMethodRaw = method.rawValue      // D18
            syncLiability(for: tx)
        } else {
            let tx = Tx(
                amount: Decimal(amountCents) / 100,
                type: isOut ? .out : .in,
                categoryID: category.id,
                subID: sub?.id,
                note: note,
                mood: mood,
                accountID: selectedAccountID,   // B2：挂账户 → 余额自动联动
                date: date,
                source: .manual,
                payMethod: method               // D18：信用支付 / 分期
            )
            modelContext.insert(tx)
            syncLiability(for: tx)              // 分期时自动在账户名下建一笔计划
        }
        try? modelContext.save()
        return info
    }

    /// ✓ 保存：入库 → 关 sheet → 成功屏（A4）
    private func saveAndDismiss() {
        guard let info = save() else { return }
        Haptics.success()          // 与成功屏同帧触发
        onSaved(info, true)
    }

    /// 再记：连续快记——入库后回到宫格，金额/备注清空，不弹成功屏
    private func saveAndContinue() {
        _ = save()
        amountStr = ""; note = ""; mood = nil; date = .now
        go(to: 0)
    }

    // MARK: 统计

    static func countToday(_ context: ModelContext) -> Int {
        let start = Calendar.current.startOfDay(for: .now)
        let descriptor = FetchDescriptor<Tx>(predicate: #Predicate { $0.date >= start })
        return (try? context.fetch(descriptor).count) ?? 0
    }

    static func streakDays(_ context: ModelContext) -> Int {
        let all = (try? context.fetch(FetchDescriptor<Tx>())) ?? []
        let days = Set(all.map { Calendar.current.startOfDay(for: $0.date) })
        guard !days.isEmpty else { return 0 }
        var streak = 0
        var day = Calendar.current.startOfDay(for: .now)
        while days.contains(day) {
            streak += 1
            guard let prev = Calendar.current.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return streak
    }
}

// MARK: - 小组件

extension Mood {
    /// nil → 😐 → 🥰 → 🤯 → 😤 → nil 轮换
    func next() -> Mood? {
        switch self {
        case .normal: .satisfied
        case .satisfied: .impulsive
        case .impulsive: .lesson
        case .lesson: nil
        }
    }
}

private struct CellButton: View {
    let emoji: String
    let name: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Text(emoji).scaledFont(34).accessibilityHidden(true)
                Text(name).scaledFont(12.5, weight: .medium).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.card)
            .cornerRadius(Radius.medium)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

private struct ChipLabel: View {
    let emoji: String
    let name: String
    var body: some View {
        HStack(spacing: 6) {
            Text(emoji).scaledFont(16).accessibilityHidden(true)
            Text(name).scaledFont(13.5, weight: .medium)
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .background(Theme.card)
        .foregroundStyle(.secondary)
        .cornerRadius(Radius.small)
    }
}
