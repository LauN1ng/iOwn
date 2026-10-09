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
/// 视觉对照：site/prototype.html #entry；验收：点 FAB 到保存 ≤3 秒
struct AddEntrySheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Account.name) private var accounts: [Account]
    var onSaved: (SavedEntryInfo, Bool) -> Void   // (结果, 是否展示成功屏)；再记=false 只入库
    var editing: Tx? = nil                        // 非 nil = 编辑该笔（B2 改账）

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

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(hex: 0xD9DDD6))
                .frame(width: 40, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 4)

            if stage == 0 { stageGrid } else { stageAmount }
            Spacer(minLength: 0)
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
        let v = NSDecimalNumber(decimal: tx.amount).doubleValue
        amountStr = v == v.rounded() && v < 1_000_000
            ? String(Int(v))
            : String(format: "%.2f", v)
        stage = 1
    }

    // MARK: 阶段 1：分类宫格

    private var stageGrid: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("支出").font(.system(size: 20, weight: .bold))
                    .foregroundStyle(isOut ? Theme.green : Color.secondary.opacity(0.4))
                    .onTapGesture { isOut = true }
                Text("收入").font(.system(size: 20, weight: .bold))
                    .foregroundStyle(!isOut ? Theme.green : Color.secondary.opacity(0.4))
                    .onTapGesture { isOut = false }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .background(Theme.card)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                Image(systemName: "gearshape").foregroundStyle(.tertiary) // TODO(M3-A5) 分类管理入口
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 16) {
                ForEach(CategoryPresets.all) { cat in
                    Button {
                        category = cat
                        sub = cat.subs.first
                        withAnimation(.easeOut(duration: 0.18)) { stage = 1 }
                    } label: {
                        VStack(spacing: 8) {
                            Text(cat.emoji).font(.system(size: 34))
                            Text(cat.name).font(.system(size: 12.5, weight: .medium))
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.card)
                        .cornerRadius(Radius.medium)
                    }
                    .buttonStyle(.plain)
                }
                CellButton(emoji: "＋", name: "添加") {} // TODO(M3-A5) 自定义大类
            }

            HStack {
                Text("⚡ 快捷分类")
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(Theme.green)
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
                Button { withAnimation(.easeOut(duration: 0.15)) { stage = 0 } } label: {
                    Image(systemName: "arrow.left").font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                }
                Text(category?.name ?? "")
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                Text(sub?.name ?? "")
                    .font(.system(size: 22, weight: .bold))
                Spacer()
                if editing == nil {
                    Button { saveAndContinue() } label: {
                        Text("再记").font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.green)
                            .padding(.horizontal, 12).padding(.vertical, 7)
                            .background(Theme.greenSoft)
                            .cornerRadius(9)
                    }
                }
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .background(Theme.card)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, Radius.pagePadding)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(category?.subs ?? []) { s in
                        Button { sub = s } label: {
                            HStack(spacing: 6) {
                                Text(s.emoji).font(.system(size: 16))
                                Text(s.name).font(.system(size: 13.5, weight: .medium))
                            }
                            .padding(.horizontal, 14).padding(.vertical, 9)
                            .background(sub?.id == s.id ? Theme.green : Theme.card)
                            .foregroundStyle(sub?.id == s.id ? Color.white : Color.primary)
                            .cornerRadius(Radius.small)
                        }
                        .buttonStyle(.plain)
                    }
                    ChipLabel(emoji: "＋", name: "添加")  // TODO(M3-A5) 自定义二级
                    ChipLabel(emoji: "⚙", name: "设置")
                }
                .padding(.horizontal, Radius.pagePadding)
            }
            .padding(.top, 14)

            Text("¥ \(amountDisplay)")
                .font(.system(size: 42, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.green)
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 18)

            HStack(spacing: 12) {
                TextField("备注", text: $note)
                    .font(.system(size: 14))
                Button {
                    mood = mood?.next() ?? .normal   // 心情轮换（A3）：nil→😐→🥰→🤯→😤→nil
                } label: {
                    Text(mood.map { "\($0.emoji) \($0.label)" } ?? "心情＋")
                        .font(.system(size: 12))
                        .foregroundStyle(mood == nil ? Color.secondary : Color.primary)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Theme.bg)
                        .cornerRadius(999)
                }
                .buttonStyle(.plain)
                Image(systemName: "plus.circle.dashed").foregroundStyle(.tertiary) // 附件预留
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
                            Button { selectedAccountID = selected ? nil : acc.id } label: {
                                HStack(spacing: 6) {
                                    Text(acc.kind.logoChar)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(.white)
                                        .frame(width: 18, height: 18)
                                        .background(Color(hex: acc.kind.brandColorHex))
                                        .cornerRadius(5)
                                    Text(acc.name).font(.system(size: 12.5, weight: .medium))
                                }
                                .padding(.horizontal, 10).padding(.vertical, 7)
                                .background(selected ? Theme.green : Theme.card)
                                .foregroundStyle(selected ? Color.white : Color.primary)
                                .cornerRadius(999)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Radius.pagePadding)
                }
                .padding(.top, 10)
            }

            keypad
                .padding(.horizontal, Radius.pagePadding)
                .padding(.top, 14)
                .padding(.bottom, 20)
        }
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
                        if !amountStr.isEmpty { amountStr.removeLast() }
                    }
                    keyButton("今天", style: .today, size: CGSize(width: colW, height: keyH)) { date = .now }
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
                .font(.system(size: label == "✓" ? 22 : 19, weight: .bold))
                .frame(width: size.width, height: size.height)
                .background(backgroundColor(style))
                .foregroundStyle(foregroundColor(style))
                .cornerRadius(Radius.medium)
        }
        .buttonStyle(.plain)
    }

    private func backgroundColor(_ s: KeyStyle) -> Color {
        switch s {
        case .normal: Theme.card
        case .danger: Color(hex: 0xFDECEB)
        case .today: Theme.greenSoft
        case .okActive(let active): active ? Theme.green : Color(hex: 0xE3E6E0)
        }
    }

    private func foregroundColor(_ s: KeyStyle) -> Color {
        switch s {
        case .normal: .primary
        case .danger: Theme.red
        case .today: Theme.green
        case .okActive(let active): active ? .white : Color(hex: 0xAEB4AC)
        }
    }

    private func tap(_ k: String) {
        switch k {
        case "＋−":
            isOut.toggle()
        case ".":
            // 进小数模式：空串视为 "0."
            guard !amountStr.contains(".") else { return }
            amountStr = amountStr.isEmpty ? "0." : amountStr + "."
        default:
            guard let d = k.first, d.isNumber else { return }
            if amountStr.contains(".") {
                // 小数位最多两位
                let decPart = amountStr.split(separator: ".").last
                guard (decPart?.count ?? 0) < 2, amountStr.count < 12 else { return }
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
                source: .manual
            )
            modelContext.insert(tx)
        }
        try? modelContext.save()
        return info
    }

    /// ✓ 保存：入库 → 关 sheet → 成功屏（A4）
    private func saveAndDismiss() {
        guard let info = save() else { return }
        onSaved(info, true)
    }

    /// 再记：连续快记——入库后回到宫格，金额/备注清空，不弹成功屏
    private func saveAndContinue() {
        _ = save()
        amountStr = ""; note = ""; mood = nil; date = .now
        withAnimation(.easeOut(duration: 0.18)) { stage = 0 }
    }

    // MARK: 统计

    static func countToday(_ context: ModelContext) -> Int {
        let start = Calendar.current.startOfDay(for: .now)
        let descriptor = FetchDescriptor<Tx>(predicate: #Predicate { $0.date >= start })
        return (try? context.fetch(descriptor).count) ?? 0
    }

    static func streakDays(_ context: ModelContext) -> Int {
        let all = (try? context.fetch(FetchDescriptor<Tx>())) ?? []
        var days = Set(all.map { Calendar.current.startOfDay(for: $0.date) })
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
                Text(emoji).font(.system(size: 34))
                Text(name).font(.system(size: 12.5, weight: .medium)).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.card)
            .cornerRadius(Radius.medium)
        }
        .buttonStyle(.plain)
    }
}

private struct ChipLabel: View {
    let emoji: String
    let name: String
    var body: some View {
        HStack(spacing: 6) {
            Text(emoji).font(.system(size: 16))
            Text(name).font(.system(size: 13.5, weight: .medium))
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
        .background(Theme.card)
        .foregroundStyle(.secondary)
        .cornerRadius(Radius.small)
    }
}
