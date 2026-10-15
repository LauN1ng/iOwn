import SwiftUI
import SwiftData
import UIKit

/// B2 转账：账户间移动资金，不计收支（流水中类型 .transfer 净额为 0）
/// 入口：资产页底部"转账"胶囊按钮
struct TransferSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Account.name) private var accounts: [Account]

    @State private var fromID: String?
    @State private var toID: String?
    @State private var amountStr = ""

    private var from: Account? { accounts.first { $0.id == fromID } }
    private var to: Account? { accounts.first { $0.id == toID } }

    private var amountValue: Decimal {
        guard let v = Double(amountStr), v.isFinite, v > 0 else { return 0 }
        return Decimal(v)
    }

    private var canSave: Bool {
        guard let f = from, let t = to else { return false }
        return f.id != t.id && amountValue > 0
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetGrabber()

            VStack(spacing: 18) {
                header

                // 转出 → 转入
                HStack(spacing: 12) {
                    accountPicker(selection: $fromID, excluding: toID, label: "转出")
                    Image(systemName: "arrow.right")
                        .scaledFont(.body, weight: .bold)
                        .foregroundStyle(Theme.greenText)
                    accountPicker(selection: $toID, excluding: fromID, label: "转入")
                }

                // 金额
                VStack(spacing: 6) {
                    Text("金额").scaledFont(.sm).foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("¥").scaledFont(.lg, weight: .bold).foregroundStyle(Theme.greenText)
                        TextField("0.00", text: $amountStr)
                            .keyboardType(.decimalPad)
                            .scaledFont(.display, weight: .heavy, design: .rounded)
                            .foregroundStyle(Theme.greenText)
                            .multilineTextAlignment(.center)
                            .monospacedDigit()
                            .tracking(-0.5)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 22)
                .background(Theme.card)
                .cornerRadius(Radius.large)

                Text("转账在流水里不计收支，仅移动余额")
                    .scaledFont(.xs)
                    .foregroundStyle(.tertiary)

                Spacer(minLength: 0)

                Button {
                    save()
                } label: {
                    Text("完成转账")
                        .scaledFont(.title, weight: .bold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(canSave ? Theme.green : Theme.disabled)
                        .cornerRadius(Radius.medium)
                }
                .buttonStyle(PressableButtonStyle(scale: 0.97))
                .disabled(!canSave)
                .padding(.bottom, 24)
            }
            .padding(.horizontal, Radius.pagePadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.bg)
        .onAppear {
            if fromID == nil { fromID = accounts.first { !$0.kind.isCredit }?.id }
            if toID == nil { toID = accounts.first { $0.id != fromID }?.id }
        }
    }

    private var header: some View {
        HStack {
            Button {
                Haptics.tap()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .scaledFont(.body, weight: .semibold)
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .background(Theme.card)
                    .clipShape(Circle())
            }
            .buttonStyle(PressableButtonStyle(scale: 0.9))
            .accessibilityLabel("关闭")
            Spacer()
            Text("转账").scaledFont(.title, weight: .bold)
            Spacer()
            Color.clear.frame(width: 31, height: 31)   // 占位保持标题居中
        }
        .padding(.top, 6)
    }

    private func accountPicker(selection: Binding<String?>, excluding: String?, label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).scaledFont(.sm).foregroundStyle(.secondary)
            Menu {
                ForEach(accounts.filter { $0.id != excluding }, id: \.id) { acc in
                    Button {
                        selection.wrappedValue = acc.id
                    } label: {
                        // 2026-10-15：`creditcard` SF Symbol → 该账户自己的 Fluent 3D 图标
                        Label {
                            Text(acc.name)
                        } icon: {
                            if !acc.icon.asset.isEmpty, UIImage(named: acc.icon.asset) != nil {
                                Image(acc.icon.asset)
                                    .renderingMode(.original)
                                    .resizable().scaledToFit().frame(width: 20, height: 20)
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(selection.wrappedValue.flatMap { id in
                        accounts.first { $0.id == id }?.name
                    } ?? "选择账户")
                        .scaledFont(.body, weight: .semibold)
                        .lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .scaledFont(.micro, weight: .bold)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(Theme.card)
                .cornerRadius(Radius.small)
            }
            .tint(.primary)
            .accessibilityHint("双击选择\(label)账户")
        }
        .frame(maxWidth: .infinity)
    }

    private func save() {
        guard let f = from, let t = to, f.id != t.id, amountValue > 0 else { return }
        let tx = Tx(amount: amountValue, type: .transfer, categoryID: "transfer",
                    accountID: f.id, toAccountID: t.id)
        modelContext.insert(tx)
        try? modelContext.save()
        dismiss()
    }
}
