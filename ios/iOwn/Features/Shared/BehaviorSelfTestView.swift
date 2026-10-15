import SwiftUI

/// CI 行为自检结果屏（launch argument `-ci-selftest`）
///
/// 只为「截图回传」存在 —— 把 `BehaviorSelfTest` 的断言结果画成一屏，
/// 让 CI 能用一张截图带回「算得对不对」的证据（CI 点不了 UI）。
/// 不进正常流程，也不出现在任何用户可见路径上。
struct BehaviorSelfTestView: View {
    let results: [SelfTestResult]

    private var passCount: Int { results.filter(\.passed).count }
    private var failCount: Int { results.count - passCount }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                header
                ForEach(results, id: \.name) { r in row(r) }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.bg)
    }

    // MARK: 汇总头

    private var header: some View {
        let allPass = failCount == 0 && !results.isEmpty
        return VStack(alignment: .leading, spacing: 6) {
            Text("行为自检 · Behavior Self-Test")
                .scaledFont(.xs, weight: .semibold)
                .foregroundStyle(.secondary)
            Text(allPass ? "全部通过 \(passCount)/\(results.count)"
                         : "\(failCount) 项失败 · \(passCount)/\(results.count) 通过")
                .scaledFont(.lg, weight: .bold)
                .foregroundStyle(allPass ? Theme.greenText : Theme.redText)
            Text("跑在独立内存容器 · 与 UI 共用 EntryWriter 真实写路径")
                .scaledFont(.micro)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.card)
        .cornerRadius(Radius.large)
        .overlay(RoundedRectangle(cornerRadius: Radius.large)
            .stroke(allPass ? Theme.green : Theme.redText, lineWidth: 1))
        .padding(.bottom, 4)
    }

    // MARK: 单条

    private func row(_ r: SelfTestResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(r.passed ? "✓" : "✗")
                    .scaledFont(.sm, weight: .bold)
                    .foregroundStyle(r.passed ? Theme.greenText : Theme.redText)
                Text(r.name)
                    .scaledFont(.sm, weight: .semibold)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
            }
            HStack(spacing: 4) {
                Text("期望 \(r.expected)")
                Text("·").foregroundStyle(.tertiary)
                Text("实际 \(r.actual)")
                    .foregroundStyle(r.passed ? Color.secondary : Theme.redText)
            }
            .scaledFont(.xs)
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(Theme.card)
        .cornerRadius(Radius.medium)
        .overlay(RoundedRectangle(cornerRadius: Radius.medium)
            .stroke(r.passed ? Theme.hairline : Theme.redText.opacity(0.6), lineWidth: 1))
    }
}
