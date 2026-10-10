import SwiftUI
import SwiftData

/// B1 手动建户（也用于编辑账户）：类型宫格（品牌色块）+ 名称 + 备注 + 初始余额 + 信用额度/账单日
/// 验收：建户 <30 秒——选类型即自动填默认名，信用账户才出额度/账单日字段
struct AddAccountSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var txs: [Tx]

    var editing: Account?          // nil = 新建；非 nil = 编辑（id/关联不变）

    @State private var kind: AccountKind = .cash
    @State private var name = ""
    @State private var brand = ""
    @State private var balanceStr = ""    // 现金类：余额；信用卡：当前已用（正数，存为负）
    @State private var limitStr = ""
    @State private var billDay = 5
    @State private var dueDay = 25
    @State private var didPickKind = false

    private var balanceValue: Decimal {
        guard let v = Double(balanceStr), v.isFinite else { return 0 }
        return Decimal(abs(v))
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetGrabber()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    kindGrid
                    formFields
                    if editing != nil { deleteSection }
                }
                .padding(.horizontal, Radius.pagePadding)
                .padding(.bottom, 30)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.bg)
        .onAppear(perform: prefillIfNeeded)
    }

    // MARK: 头部

    private var header: some View {
        HStack {
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
            .buttonStyle(PressableButtonStyle(scale: 0.9))
            .accessibilityLabel("关闭")
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
        .padding(.top, 6)
    }

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
            && (editing != nil || !balanceStr.isEmpty)
    }

    // MARK: 类型宫格

    private var kindGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("类型").scaledFont(13, weight: .semibold).foregroundStyle(.secondary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                ForEach(AccountKind.pickerOrder, id: \.rawValue) { k in
                    Button {
                        Haptics.tap()
                        kind = k
                        didPickKind = true
                        if name.isEmpty || name == kind.defaultName { name = k.defaultName }
                        if !k.isCredit { limitStr = "" }
                    } label: {
                        VStack(spacing: 6) {
                            Text(k.logoChar)
                                .scaledFont(17, weight: .bold)
                                .foregroundStyle(.white)
                                .frame(width: 40, height: 40)
                                .background(Color(hex: k.brandColorHex))
                                .cornerRadius(12)
                                .accessibilityHidden(true)   // 装饰：类型名已念出
                            Text(k.defaultName)
                                .scaledFont(11, weight: .medium)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                        }
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(kind == k ? Theme.greenSoft : Theme.card)
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.medium)
                                .stroke(kind == k ? Theme.green : .clear, lineWidth: 1.5)
                        )
                        .cornerRadius(Radius.medium)
                    }
                    .buttonStyle(PressableButtonStyle())
                    .disabled(editing != nil)   // 编辑时类型不可改（余额推导依赖类型口径）
                }
            }
        }
    }

    // MARK: 表单

    private var formFields: some View {
        VStack(alignment: .leading, spacing: 14) {
            fieldRow(label: "名称") {
                TextField(kind.defaultName, text: $name)
                    .scaledFont(15, weight: .semibold)
                    .multilineTextAlignment(.trailing)
            }
            fieldRow(label: "备注") {
                TextField("工资卡 · ··1234（可空）", text: $brand)
                    .scaledFont(14)
                    .multilineTextAlignment(.trailing)
            }
            fieldRow(label: kind.isCredit ? "当前已用" : "初始余额") {
                HStack(spacing: 4) {
                    Text("¥").scaledFont(14, weight: .semibold).foregroundStyle(.secondary)
                    TextField(kind.isCredit ? "0" : "0.00", text: $balanceStr)
                        .keyboardType(.decimalPad)
                        .scaledFont(15, weight: .bold)
                        .multilineTextAlignment(.trailing)
                        .monospacedDigit()
                }
            }
            if kind.isCredit {
                fieldRow(label: "信用额度") {
                    HStack(spacing: 4) {
                        Text("¥").scaledFont(14, weight: .semibold).foregroundStyle(.secondary)
                        TextField("15000", text: $limitStr)
                            .keyboardType(.decimalPad)
                            .scaledFont(15, weight: .bold)
                            .multilineTextAlignment(.trailing)
                            .monospacedDigit()
                    }
                }
                fieldRow(label: "账单日") {
                    Picker("", selection: $billDay) {
                        ForEach(1...28, id: \.self) { Text("\($0) 日").tag($0) }
                    }
                    .pickerStyle(.menu)
                    .tint(.primary)
                }
                fieldRow(label: "还款日") {
                    Picker("", selection: $dueDay) {
                        ForEach(1...28, id: \.self) { Text("\($0) 日").tag($0) }
                    }
                    .pickerStyle(.menu)
                    .tint(.primary)
                }
                Text("已用金额将记为负债（余额为负），剩余额度 = 额度 - 已用；账单日与还款日分开记录")
                    .scaledFont(11.5)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .background(Theme.card)
        .cornerRadius(Radius.large)
    }

    private func fieldRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(label).scaledFont(14.5, weight: .medium)
            Spacer()
            content()
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

    // MARK: 预填 / 保存

    private func prefillIfNeeded() {
        guard let acc = editing else {
            name = kind.defaultName
            return
        }
        kind = acc.kind
        name = acc.name
        brand = acc.brand
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
            // 编辑不改 initialBalance（改余额请用转账/调整交易，保持推导口径干净）
        } else {
            // 信用卡：已用为正数输入，存为负向负债（B4）
            let initial = kind.isCredit ? -balanceValue : balanceValue
            let acc = Account(name: trimmed, brand: brand, initialBalance: initial,
                              kind: kind, billDay: kind.isCredit ? billDay : nil,
                              dueDay: kind.isCredit ? dueDay : nil,
                              creditLimit: limit)
            modelContext.insert(acc)
        }
        try? modelContext.save()
        dismiss()
    }
}
