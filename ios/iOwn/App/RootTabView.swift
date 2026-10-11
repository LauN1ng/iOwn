import SwiftUI
import SwiftData

/// 4 Tab 骨架：线索 / 洞察 / 资产 / 设置 + 绿 FAB（记一笔；资产页变琥珀 $ 建户）
/// 2026-10-10 v4：负债不再是独立 Tab —— 它并入资产页的「信用账户」，
/// 点进任一信用账户 = 原来的负债页（当期欠款 + 分期 + 还款）。
/// 视觉对照物：site/prototype-v3.html
struct RootTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @State private var selection = 0
    @State private var showAdd = false
    @State private var showAddAccount = false      // M2：资产页 $ FAB → 建户
    @State private var savedInfo: SavedEntryInfo?
    @State private var showSuccess = false
    // E5 分类管理（sheet）
    @State private var showCatManager = false
    // 工资设置页（CI 截图钩子用；首页卡片自身也有入口）
    @State private var showWageSettings = false
    // 添加分期 sheet（CI 截图钩子用；正常入口在信用账户详情页右上角 ＋）
    @State private var showAddInstallment = false

    private let ciArgs = ProcessInfo.processInfo.arguments

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $selection) {
                HomeView().tabItem { Label("线索", systemImage: "list.bullet") }.tag(0)
                InsightView().tabItem { Label("洞察", systemImage: "chart.bar") }.tag(1)
                AssetsView(onOpenInsight: { selection = 1 }).tabItem { Label("资产", systemImage: "banknote") }.tag(2)
                SettingsView().tabItem { Label("设置", systemImage: "gearshape") }.tag(3)
            }
            .tint(Theme.greenText)

            // FAB：线索/洞察/设置 = 绿 +（记一笔）；资产页 = 琥珀 $（建户）
            Button {
                Haptics.tap()
                if selection == 2 {
                    showAddAccount = true
                } else {
                    showAdd = true
                }
            } label: {
                Image(systemName: selection == 2 ? "dollarsign" : "plus")
                    .scaledFont(24, weight: .bold)
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(selection == 2 ? Theme.amber : Theme.green)
                    .clipShape(Circle())
                    // 环形"挖空"：FAB 会盖住滚到该位置的账户行金额，加一圈页面底色描边
                    // 把它读成浮在最上层的一层，而不是和行内文字糊在一起
                    .overlay(Circle().stroke(Theme.bg, lineWidth: 3))
                    .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
            }
            .buttonStyle(PressableButtonStyle(scale: 0.92))
            .accessibilityLabel(selection == 2 ? "添加账户" : "记一笔")
            .accessibilityHint(selection == 2 ? "新建账户" : "快速记一笔账")
            // 切 Tab 时 FAB 换色/换图标：让颜色渐变而非硬切
            .animation(Motion.fade, value: selection)
            .padding(.trailing, 18)
            .padding(.bottom, 76)

            // 成功屏（A4）：覆盖全屏，1.9s 自动返回（CI 截图模式常驻）
            if showSuccess, let info = savedInfo {
                SuccessOverlay(info: info)
                    .transition(.opacity)
                    .task {
                        guard !ciArgs.contains("-ci-show-done") else { return }
                        try? await Task.sleep(nanoseconds: 1_900_000_000)
                        withAnimation(.easeOut(duration: 0.25)) { showSuccess = false }
                    }
            }
        }
        // 半屏 sheet（用户需求：记一笔不盖住主屏，保留背后主页上下文）
        // 0.68 = 阶段2（宫格滑走后）键盘+金额区完整放下的最小比例；可上拖全屏
        // ⚠️ 真机验证点：iOS 26 曾 detents 不生效（当时因此退回 fullScreenCover），iOS 27 待验
        .sheet(isPresented: $showAdd) {
            AddEntrySheet(editing: nil) { info, showOverlay in
                guard showOverlay else { return }   // 再记：sheet 保持打开
                savedInfo = info
                showAdd = false
                withAnimation { showSuccess = true }
            }
            .presentationDetents([.fraction(0.68), .large])
            .presentationDragIndicator(.hidden)   // 自绘 grabber 已有，隐藏系统把手防双条
        }
        .sheet(isPresented: $showAddAccount) {
            AddAccountSheet()
                .presentationDetents([.fraction(0.68), .large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showCatManager) {
            NavigationStack { CategoryManagerView() }
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showWageSettings) {
            WageSettingsView()
        }
        // 添加分期 sheet（截图为半屏，验证两种输入模式换算）
        .sheet(isPresented: $showAddInstallment) {
            AddInstallmentSheet()
                .presentationDetents([.fraction(0.68), .large])
                .presentationDragIndicator(.hidden)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                // 回前台：此处预留自动记账队列消费位（当前自动记账已搁置，待调研后重启）
            }
        }
        .onAppear {
            seedDemoDataIfRequested()
            // 节假日/调休数据静默同步（holiday-cn）：失败静默，不阻塞 UI
            Task { await HolidayStore.shared.syncIfNeeded() }
            // CI 截图钩子：自动打开记一笔 / 直接展示成功屏 / 直达资产页
            if ciArgs.contains("-ci-tab-assets") {
                selection = 2
            }
            // 负债相关钩子：负债已并入资产页的信用账户，统一落到资产页
            if ciArgs.contains("-ci-tab-debt") {
                selection = 2
            }
            // 「按月份」档钩子（同上，负债权重已收敛）
            if ciArgs.contains("-ci-tab-month") {
                selection = 2
            }
            // 洞察页截图钩子
            if ciArgs.contains("-ci-tab-insight") {
                selection = 1
            }
            // E5 分类管理页截图钩子
            if ciArgs.contains("-ci-open-catman") {
                showCatManager = true
            }
            if ciArgs.contains("-ci-show-done") {
                savedInfo = SavedEntryInfo(
                    amount: 12, isOut: true, categoryName: "生活所需",
                    subName: "三餐", mood: .normal, todayCount: 1, streak: 1
                )
                showSuccess = true
            }
            if ciArgs.contains("-ci-open-sheet") {
                showAdd = true
            }
            // 金额页截图钩子：直接进 stage 1（验证金额两位小数 + 账户 chip）
            if ciArgs.contains("-ci-open-amount") {
                showAdd = true
            }
            // 建户半屏 sheet 截图钩子（资产页 + 自动展开 AddAccountSheet）
            if ciArgs.contains("-ci-open-account") {
                selection = 2
                showAddAccount = true
            }
            // 工资设置页截图钩子（到手薪资 + 调休节）
            if ciArgs.contains("-ci-open-wage") {
                showWageSettings = true
            }
            // 添加分期页截图钩子（半屏，验证分期换算 + 两种输入模式）
            if ciArgs.contains("-ci-open-installment") {
                selection = 2
                showAddInstallment = true
            }
        }
        // Dynamic Type：默认限制在标准区间（保护键盘/净资产卡等固定版式）；
        // -ci-large-text 时强制 .xxxLarge，供 CI 截图验证缩放确实生效
        .modifier(TypeSizeCap(forceXXXL: ciArgs.contains("-ci-large-text")))
    }

    /// CI 截图钩子：launch argument "-ci-demo-data" 注入样例数据（仓库无真实数据）
    /// 放在 RootTabView（而非各页 onAppear）：直达任意 tab 的截图都能拿到完整样例
    private func seedDemoDataIfRequested() {
        guard ciArgs.contains("-ci-demo-data") else { return }
        // 工资计时器参数（仅首次未配置时注入样例）
        if UserDefaults.standard.double(forKey: WageKeys.takeHomePay) == 0 {
            WageConfig(takeHomePay: 8000, payday: 15, startHour: 9, startMinute: 0,
                       endHour: 18, endMinute: 0, lunchStartHour: 12, lunchStartMinute: 0,
                       lunchMinutes: 60, workdays: [2, 3, 4, 5, 6],
                       makeupWorkdays: [], extraOffDays: []).save()
        }
        let txCount = (try? modelContext.fetchCount(FetchDescriptor<Tx>())) ?? 0
        guard txCount == 0 else { return }
        let calendar = Calendar.current

        // M2-B3 样例账户（2026-10-10 v4：花呗 / 白条与信用卡同为「信用账户」）
        let accountCount = (try? modelContext.fetchCount(FetchDescriptor<Account>())) ?? 0
        if accountCount == 0 {
            let demoAccounts: [(String, String, Decimal, AccountKind, Int?, Int?, Decimal?)] = [
                ("支付宝", "默认 · 记账自动联动", 12368.20, .alipay, nil, nil, nil),
                ("微信支付", "默认 · 记账自动联动", 3274.35, .wechat, nil, nil, nil),
                ("招商银行", "工资卡 · ··1234", 24500.00, .bankCard, nil, nil, nil),
                ("信用卡", "账单日 2 日", -3600.00, .creditCard, 2, 22, 15000),
                ("花呗", "账单日 1 日", -7000.00, .huabei, 1, 25, 20000),
                ("京东白条", "账单日 1 日", -1800.00, .baitiao, 1, 25, 5000),
            ]
            for (name, brand, balance, kind, billDay, dueDay, limit) in demoAccounts {
                modelContext.insert(Account(name: name, brand: brand, initialBalance: balance,
                                            kind: kind, billDay: billDay, dueDay: dueDay,
                                            creditLimit: limit))
            }
        }

        // 分期样例：挂到对应信用账户（金额自洽：Σ分期剩余本金 ≤ |账户余额|）
        let liabilityCount = (try? modelContext.fetchCount(FetchDescriptor<Liability>())) ?? 0
        if liabilityCount == 0 {
            let accountsNow = (try? modelContext.fetch(FetchDescriptor<Account>())) ?? []
            func accountID(_ k: AccountKind) -> String? { accountsNow.first { $0.kind == k }?.id }
            // (名称, 归属账户类型, 本金, 总期数, 已还期数, 每期费率%, 账单日, 还款日, 图标字, 底色)
            let demoPlans: [(String, AccountKind, Decimal, Int, Int, Decimal, Int, Int, String, UInt32)] = [
                ("信用卡分期", .creditCard, 5310, 12, 5, 0, 2, 22, "信", 0x8E8E93),
                ("手机分期", .huabei, 6000, 12, 3, 0, 1, 25, "机", 0x7F77DD),
                ("耳机分期", .huabei, 1600, 8, 2, 0, 1, 25, "耳", 0x5DCAA5),
                ("会员分期", .huabei, 480, 12, 1, 0, 1, 25, "会", 0xF59E0B),
                ("白条分期", .baitiao, 2400, 6, 2, 0, 1, 25, "白", 0xE24B4A),
            ]
            for (i, d) in demoPlans.enumerated() {
                let (name, accKind, principal, tp, pp, rate, bd, dd, ic, ih) = d
                modelContext.insert(Liability(
                    name: name, kind: .installment, category: .credit,
                    principal: principal, totalPeriods: tp, paidPeriods: pp,
                    feeMode: rate > 0 ? .totalRate : .none, feeValue: rate,
                    billDay: bd, dueDay: dd, startMonth: "",
                    iconChar: ic, iconHex: ih,
                    linkedAccountID: accountID(accKind), sortOrder: i))
            }
        }

        // 固定支出样例（独立模块 —— 不是负债、不进「待还」）
        let fixedCount = (try? modelContext.fetchCount(FetchDescriptor<FixedExpense>())) ?? 0
        if fixedCount == 0 {
            let demoFixed: [(String, Decimal, Int, String)] = [
                ("房租", 1230.50, 1, "🏠"),
                ("视频会员", 25.00, 12, "📺"),
            ]
            for (i, d) in demoFixed.enumerated() {
                modelContext.insert(FixedExpense(name: d.0, amount: d.1,
                                                 dueDay: d.2, emoji: d.3, sortOrder: i))
            }
        }

        let samples: [(String, String, Int, Mood?, TimeInterval)] = [
            ("needs", "meal", 1200, .normal, -2 * 3600),
            ("flexible", "coffee", 990, .satisfied, -1 * 3600),
            ("fixed", "commute", 400, nil, -26 * 3600),
            // 洞察页样例：当月更多天（热力格 / 心情 / 占比有内容）
            ("needs", "grocery", 6800, .satisfied, -2 * 86400),
            ("needs", "daily", 2350, .normal, -3 * 86400),
            ("needs", "meal", 1800, .impulsive, -3 * 86400),
            ("flexible", "fun", 4500, .satisfied, -4 * 86400),
            ("flexible", "snack", 1580, .normal, -5 * 86400),
            ("needs", "medical", 3200, .lesson, -6 * 86400),
            ("fixed", "utility", 12800, .normal, -7 * 86400),
            ("growth", "book", 5900, .satisfied, -8 * 86400),
            ("needs", "meal", 2200, .normal, -9 * 86400),
        ]
        for (catID, subID, cents, mood, offset) in samples {
            modelContext.insert(Tx(
                amount: Decimal(cents) / 100,
                type: .out,
                categoryID: catID,
                subID: subID,
                note: "",
                mood: mood,
                date: calendar.date(byAdding: .second, value: Int(offset), to: .now) ?? .now
            ))
        }

        // 洞察页样例：跨月历史（12 月柱状图 / 今年总支出有内容；仅 CI 演示数据）
        let histories: [(String, String, Int, TimeInterval)] = [
            ("needs", "meal", 186000, -30 * 86400),
            ("fixed", "rent", 320000, -45 * 86400),
            ("flexible", "fun", 98000, -62 * 86400),
            ("needs", "grocery", 142000, -78 * 86400),
            ("travel", "transport", 268000, -95 * 86400),
            ("needs", "meal", 121000, -110 * 86400),
            ("flexible", "coffee", 76000, -128 * 86400),
            ("fixed", "subscription", 45000, -145 * 86400),
            ("bigitem", "digital", 399000, -168 * 86400),
            ("needs", "meal", 134000, -190 * 86400),
        ]
        for (catID, subID, cents, offset) in histories {
            modelContext.insert(Tx(
                amount: Decimal(cents) / 100,
                type: .out,
                categoryID: catID,
                subID: subID,
                note: "",
                date: calendar.date(byAdding: .second, value: Int(offset), to: .now) ?? .now
            ))
        }
        try? modelContext.save()
    }
}

#Preview { RootTabView() }
