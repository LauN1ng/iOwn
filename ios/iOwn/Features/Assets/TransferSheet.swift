import SwiftUI
import SwiftData

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
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(hex: 0xD9DDD6))
                .frame(width: 40, height: 5)
                .padding(.top, 8)
                .padding(.bottom, 4)

            VStack(spacing: 18) {
                header

                // 转出 → 转入
                HStack(spacing: 12) {
                    accountPicker(selection: $fromID, excluding: toID, label: "转出")
                    Image(systemName: "arrow.right")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.green)
                    accountPicker(selection: $toID, excluding: fromID, label: "转入")
                }

                // 金额
                VStack(spacing: 6) {
                    Text("金额").font(.system(size: 12.5)).foregroundStyle(.secondary)
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text("¥").font(.system(size: 22, weight: .bold)).foregroundStyle(Theme.green)
                        TextField("0.00", text: $amountStr)
                            .keyboardType(.decimalPad)
                            .font(.system(size: 40, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.green)
                            .multilineTextAlignment(.center)
                            .monospacedDigit()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 22)
                .background(Theme.card)
                .cornerRadius(Radius.large)

                Text("转账在流水里不计收支，仅移动余额")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.tertiary)

                Spacer(minLength: 0)

                Button {
                    save()
                } label: {
                    Text("完成转账")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(canSave ? Theme.green : Color(hex: 0xE3E6E0))
                        .cornerRadius(Radius.medium)
                }
                .buttonStyle(.plain)
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
            Spacer()
            Text("转账").font(.system(size: 17, weight: .bold))
            Spacer()
            Color.clear.frame(width: 31, height: 31)   // 占位保持标题居中
        }
        .padding(.top, 6)
    }

    private func accountPicker(selection: Binding<String?>, excluding: String?, label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 12)).foregroundStyle(.secondary)
            Menu {
                ForEach(accounts.filter { $0.id != excluding }, id: \.id) { acc in
                    Button {
                        selection.wrappedValue = acc.id
                    } label: {
                        Label(acc.name, systemImage: "creditcard")
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Text(selection.wrappedValue.flatMap { id in
                        accounts.first { $0.id == id }?.name
                    } ?? "选择账户")
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(Theme.card)
                .cornerRadius(Radius.small)
            }
            .tint(.primary)
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
