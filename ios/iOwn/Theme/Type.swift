import SwiftUI

// MARK: - 字号阶梯（视觉 §4.1 收口 · 2026-10-15）
//
// 规则：`scaledFont(pt:)` **只允许出现在本文件 + keyButton 动态 pt 场景**，
// 业务代码一律走 `scaledFont(.body, weight: .medium)` 之类。
// 改动流程：新增档位 → 改本枚举 → 全局 build 报错定位 → 逐处确认。
//
// - `display` 档不跟随 Dynamic Type（视觉主导：大数字、配图标题、净资产卡），
//   走 `Font.system(size:)` 直接固定，避免大数字撑爆版式。
// - Dynamic Type 缩放行为由 `scaledFont` 修饰器统一接管；
//   根视图已 `.dynamicTypeSize(.xSmall...xxxLarge)`，上限 xxxLarge。

enum Type {
    case micro, xs, sm, body, title, lg, xl, display

    /// 视觉稿基准 pt（中等字号下的渲染尺寸；Dynamic Type 在上下限之间线性缩放）
    var pt: Double {
        switch self {
        case .micro:   10
        case .xs:      11
        case .sm:      13
        case .body:    15
        case .title:   17
        case .lg:      22
        case .xl:      28
        case .display: 42
        }
    }

    /// `display` 不跟随 Dynamic Type（视觉主导）
    var scales: Bool { self != .display }
}
