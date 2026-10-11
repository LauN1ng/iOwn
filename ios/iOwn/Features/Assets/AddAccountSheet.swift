import SwiftUI
import SwiftData
import UIKit

/// 手动建户 / 编辑账户（2026-10-11 照用户参考图「添加支付方式」重做）
///
/// 结构：卡面预览（+ 更换卡面）→ 类型 → 图标 / 名称 / 备注 / 卡号后四位
///      → 初始余额 / 币种 → 记账时可选择 →（信用类）额度 / 账单日 / 还款日。
/// 卡面卡片即 Fluent 3D `CardFace`，与卡堆、账户详情页同一套视觉。
struct AddAccountSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var txs: [Tx]

    var editing: Account?          // nil = 新建；非 nil = 编辑（id/关联不变）

    @State private var kind: AccountKind = .cash
    @State private var name = ""
    @State private var brand = ""
    @State private var cardLast4 = ""
    @State private var balanceStr = ""
    @State private var limitStr = ""
    @State private var billDay = 5
    @State private var dueDay = 25
    @State private var cardFace: CardFace = .goldHoneycomb
    @State private var icon: AccountIcon = .none
    @State private var isSelectable = true

    @State private var showFacePicker = false
    @State private var showIconPicker = false

    private let ciArgs = ProcessInfo.processInfo.arguments

    private var balanceValue: Decimal {
        guard let v = Double(balanceStr), v.isFinite else { return 0 }
        return Decimal(abs(v))
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetGrabber()
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    preview
                    kindRow
                    basicSection
                    balanceSection
                    selectableSection
                    if kind.isCredit { creditSection }
                    if editing != nil { deleteSection }
                }
                .padding(.horizontal, Radius.pagePadding)
                .padding(.bottom, 34)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.bg)
        .onAppear(perform: onAppear)
        .sheet(isPresented: $showFacePicker) {
            CardFacePicker(selection: $cardFace)
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showIconPicker) {
            AccountIconPicker(selection: $icon)
                .presentationDetents([.fraction(0.45), .large])
                .presentationDragIndicator(.hidden)
        }
    }

    // MARK: 头部（照参考图：取消 / 标题 / 保存）

    private var header: some View {
        HStack {
            Button {
                Haptics.tap()
                dismiss()
            } label: {
                Text("取消").scaledFont(15).foregroundStyle(.secondary)
            }
            .buttonStyle(PressableButtonStyle(scale: 0.96))
            .accessibilityLabel("取消")

            Spacer()
            Text(editing == nil ? "添加账户" : "编辑账户")
                .scaledFont(17, weight: .bold)
            Spacer()

            Button {
                save()
            } label: {
                Text("保存")
                    .scaledFont(14, weight: .semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(canSave ? Theme.green : Theme.disabled)
                    .cornerRadius(999)
            }
            .buttonStyle(PressableButtonStyle(scale: 0.95))
            .disabled(!canSave)
        }
        .padding(.horizontal, Radius.pagePadding)
        .padding(.top, 6)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: 卡面预览 + 更换卡面

    private var preview: some View {
        VStack(spacing: 12) {
            CardFront(name: name.isEmpty ? kind.defaultName : name,
                      amountText: "¥" + Money.string(NSDecimalNumber(decimal: balanceValue).doubleValue),
                      face: cardFace,
                      iconName: icon.asset,
                      logoChar: kind.logoChar,
                      height: 168,
                      cornerRadius: Radius.large)

            Button { Haptics.tap(); showFacePicker = true } label: {
                Text("更换卡面")
                    .scaledFont(13.5, weight: .semibold)
                    .foregroundStyle(Theme.greenText)
                    .padding(.horizontal, 20).padding(.vertical, 9)
                    .overlay(Capsule().stroke(Theme.greenText, lineWidth: 1.2))
                    .clipShape(Capsule())
            }
            .buttonStyle(PressableButtonStyle(scale: 0.96))
            .accessibilityLabel("更换卡面")
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }

    // MARK: 类型（信用语义依赖它，必须保留）

    private var kindRow: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("类型").scaledFont(12.5, weight: .semibold).foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(AccountKind.pickerOrder, id: \.rawValue) { k in
                        Button {
                            Haptics.tap()
                            kind = k
                            if name.isEmpty || name == kind.defaultName { name = k.defaultName }
                            cardFace = k.defaultCardFace
                            icon = k.defaultIcon
                            if !k.isCredit { limitStr = "" }
                        } label: {
                            HStack(spacing: 5) {
                                if UIImage(named: k.defaultIcon.asset) != nil {
                                    Image(k.defaultIcon.asset)
                                        .resizable().scaledToFit().frame(width: 17, height: 17)
                                }
                                Text(k.defaultName).scaledFont(13, weight: .semibold)
                            }
                            .foregroundStyle(kind == k ? Color.white : Color.primary)
                            .padding(.horizontal, 13).padding(.vertical, 8)
                            .background(kind == k ? Theme.green : Theme.card)
                            .cornerRadius(999)
                        }
                        .buttonStyle(PressableButtonStyle(scale: 0.96))
                        .disabled(editing != nil)   // 编辑时类型不可改（余额推导依赖类型口径）
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
        }
    }

    // MARK: 图标 / 名称 / 备注 / 卡号后四位

    private var basicSection: some View {
        formCard {
            row("图标") {
                Button { Haptics.tap(); showIconPicker = true } label: {
                    HStack(spacing: 6) {
                        if icon != .none, UIImage(named: icon.asset) != nil {
                            Image(icon.asset).resizable().scaledToFit().frame(width: 22, height: 22)
                        }
                        Text(icon.displayName).scaledFont(14).foregroundStyle(.secondary)
                        Text("›").scaledFont(15).foregroundStyle(.tertiary)
                    }
                }
                .buttonStyle(PressableButtonStyle(scale: 0.97))
                .accessibilityLabel("选择图标，当前 \(icon.displayName)")
            }
            divider
            row("名称") {
                TextField(kind.defaultName, text: $name)
                    .scaledFont(15, weight: .semibold)
                    .multilineTextAlignment(.trailing)
            }
            divider
            row("备注") {
                TextField("可选", text: $brand)
                    .scaledFont(14)
                    .multilineTextAlignment(.trailing)
            }
            divider
            row("卡号后四位") {
                TextField("可选", text: $cardLast4)
                    .keyboardType(.numberPad)
                    .scaledFont(14)
                    .multilineTextAlignment(.trailing)
                    .onChange(of: cardLast4) { _, newValue in
                        if newValue.count > 4 { cardLast4 = String(newValue.prefix(4)) }
                    }
            }
        }
    }

    // MARK: 初始余额 / 币种

    private var balanceSection: some View {
        formCard {
            row(kind.isCredit ? "当前已用" : "初始余额") {
                HStack(spacing: 4) {
                    Text("¥").scaledFont(14, weight: .semibold).foregroundStyle(.secondary)
                    TextField(kind.isCredit ? "0" : "0.00", text: $balanceStr)
                        .keyboardType(.decimalPad)
                        .scaledFont(15, weight: .bold)
                        .multilineTextAlignment(.trailing)
                        .monospacedDigit()
                }
            }
            divider
            row("币种") {
                Text("🇨🇳 人民币").scaledFont(14).foregroundStyle(.secondary)
            }
        }
    }

    // MARK: 记账时可选择

    private var selectableSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            formCard {
                HStack {
                    Text("记账时可选择").scaledFont(14.5, weight: .medium)
                    Spacer()
                    Toggle("", isOn: $isSelectable)
                        .labelsHidden()
                        .tint(Theme.green)
                }
                .padding(.vertical, 2)
            }
            Text("关闭后，记账选择支付方式时不再显示它。")
                .scaledFont(11.5).foregroundStyle(.tertiary)
                .padding(.horizontal, 4)
        }
    }

    // MARK: 信用类专属

    @ViewBuilder
    private var creditSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            formCard {
                row("信用额度") {
                    HStack(spacing: 4) {
                        Text("¥").scaledFont(14, weight: .semibold).foregroundStyle(.secondary)
                        TextField("15000", text: $limitStr)
                            .keyboardType(.decimalPad)
                            .scaledFont(15, weight: .bold)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                    }
                }
                divider
                row("账单日") {
                    Picker("", selection: $billDay) {
                        ForEach(1...28, id: \.self) { Text("\($0) 日").tag($0) }
                    }
                    .pickerStyle(.menu)
                    .tint(.primary)
                }
                divider
                row("还款日") {
                    Picker("", selection: $dueDay) {
                        ForEach(1...28, id: \.self) { Text("\($0) 日").tag($0) }
                    }
                    .pickerStyle(.menu)
                    .tint(.primary)
                }
            }
            Text("已用金额将记为负债（余额为负），剩余额度 = 额度 - 已用；账单日与还款日分开记录")
                .scaledFont(11.5).foregroundStyle(.tertiary)
                .padding(.horizontal, 4)
        }
    }

    // MARK: 删除（编辑模式）

    private var deleteSection: some View {
        let referenced = txs.contains { $0.accountID == editing?.id || $0.toAccountID == editing?.id }
        return VStack(spacing: 8) {
            Button {
                if let acc = editing {
                    Haptics.tap()
                    modelContext.delete(acc)
                    try? modelContext.save()
                    dismiss()
                }
            } label: {
                Text("删除账户")
                    .scaledFont(14.5, weight: .semibold)
                    .foregroundStyle(referenced ? Theme.disabledText : Theme.redText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Theme.card)
                    .cornerRadius(Radius.medium)
            }
            .buttonStyle(PressableButtonStyle(scale: 0.97))
            .disabled(referenced)
            if referenced {
                Text("该账户有关联交易，暂不能删除（B2：余额推导依赖交易关联）")
                    .scaledFont(11.5)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: 表单构件

    private func formCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) { content() }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Theme.card)
            .cornerRadius(Radius.large)
    }

    private func row<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 8) {
            Text(label).scaledFont(14.5, weight: .medium)
            Spacer(minLength: 8)
            content()
        }
        .padding(.vertical, 10)
    }

    private var divider: some View {
        Rectangle().fill(Theme.hairline).frame(height: 1)
    }

    // MARK: 预填 / 保存

    private func onAppear() {
        prefillIfNeeded()
        // CI 截图钩子：直接展开卡面选择器
        if ciArgs.contains("-ci-open-face") { showFacePicker = true }
    }

    private func prefillIfNeeded() {
        guard let acc = editing else {
            name = kind.defaultName
            cardFace = kind.defaultCardFace
            icon = kind.defaultIcon
            return
        }
        kind = acc.kind
        name = acc.name
        brand = acc.brand
        cardLast4 = acc.cardLast4
        cardFace = acc.cardFace
        icon = acc.icon
        isSelectable = acc.isSelectable
        billDay = acc.billDay ?? 5
        dueDay = acc.dueDay ?? 25
        let bal = NSDecimalNumber(decimal: acc.initialBalance).doubleValue
        balanceStr = bal == 0 ? "" : String(format: "%.2f", abs(bal))
        if let limit = acc.creditLimit {
            limitStr = NSDecimalNumber(decimal: limit).doubleValue == 0
                ? "" : String(format: "%.2f", NSDecimalNumber(decimal: limit).doubleValue)
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let limit = kind.isCredit ? Decimal(Double(limitStr) ?? 0) : nil

        if let acc = editing {
            acc.name = trimmed
            acc.brand = brand
            acc.kind = kind
            acc.creditLimit = limit
            acc.billDay = kind.isCredit ? billDay : nil
            acc.dueDay = kind.isCredit ? dueDay : nil
            acc.cardFaceRaw = cardFace.rawValue
            acc.iconRaw = icon.rawValue
            acc.cardLast4 = cardLast4
            acc.isSelectable = isSelectable
            // 编辑不改 initialBalance（改余额请用转账/调整交易，保持推导口径干净）
        } else {
            // 信用卡：已用为正数输入，存为负向负债（B4）
            let initial = kind.isCredit ? -balanceValue : balanceValue
            let acc = Account(name: trimmed, brand: brand, initialBalance: initial,
                              kind: kind, billDay: kind.isCredit ? billDay : nil,
                              dueDay: kind.isCredit ? dueDay : nil,
                              creditLimit: limit,
                              cardFace: cardFace, icon: icon,
                              cardLast4: cardLast4, isSelectable: isSelectable)
            modelContext.insert(acc)
        }
        try? modelContext.save()
        dismiss()
    }
}

// MARK: - 账户图标选择器

private struct AccountIconPicker: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: AccountIcon

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        VStack(spacing: 0) {
            SheetGrabber()
            Text("选择图标").scaledFont(17, weight: .bold).padding(.top, 6)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(AccountIcon.pickerOrder, id: \.rawValue) { ic in
                        Button {
                            Haptics.tap()
                            selection = ic
                            dismiss()
                        } label: {
                            VStack(spacing: 6) {
                                ZStack {
                                    Circle()
                                        .fill(ic == selection ? Theme.greenSoft : Theme.card)
                                        .frame(width: 56, height: 56)
                                    if ic == .none {
                                        Text("无").scaledFont(14, weight: .semibold).foregroundStyle(.secondary)
                                    } else if UIImage(named: ic.asset) != nil {
                                        // ⚠️ 彩色 Fluent 贴图：不要加 .renderingMode(.template)
                                        Image(ic.asset).resizable().scaledToFit().frame(width: 38, height: 38)
                                    } else {
                                        Text(ic.emoji).scaledFont(30)
                                    }
                                }
                                .overlay(
                                    Circle().stroke(ic == selection ? Theme.green : Color.clear, lineWidth: 2)
                                )
                                Text(ic.displayName)
                                    .scaledFont(11.5)
                                    .foregroundStyle(ic == selection ? Theme.greenText : .secondary)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(PressableButtonStyle(scale: 0.95))
                    }
                }
                .padding(Radius.pagePadding)
            }
        }
        .background(Theme.bg)
    }
}
