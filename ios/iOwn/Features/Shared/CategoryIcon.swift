import SwiftUI
import UIKit

// MARK: - 分类 / 心情图标（Microsoft Fluent Emoji 3D）
//
// 图标来源：Microsoft Fluent Emoji（MIT 许可），已入库 Assets.xcassets。
// 清单与命名见 `docs/图标方案-定案-v1.md`：cat_* / sub_* / mood_* / cur_* / state_* / nav_*。
//
// ⚠️ 彩色贴图一律按 original 渲染 —— **不要加 `.renderingMode(.template)`**，
//    否则会被系统强制染成单色，3D 质感与配色全部丢失。
//    （这一点与旧的「单色线性图标」方案正好相反，是本次改造最容易踩的坑。）
//
// 2026-10-15（《设计语言-断层与归并方案-v1》D1）：**删除 emoji 兜底出口**。
//   此前 asset 缺失时会 `Text(fallback)` 回退到 iOS 系统 emoji 字体 —— 那是与 Fluent 3D
//   完全不同的第三种材质（扁平拟物渐变 vs 厚实高光塑料），同屏即露馅，是本轮要清的 C 语族。
//   现在找不到 asset 就渲染**中性灰底占位**，把 C 语族在 UI 层的入口彻底断掉。
//   （数据层的 `emoji:` 字符串保留 —— 它们只用于老数据反查 asset，不再有渲染出口。）

struct CategoryIcon: View {
    /// Asset Catalog 名（如 "cat_coffee" / "sub_rent" / "mood_normal"）
    let asset: String?
    /// 绘制尺寸（pt）
    var size: CGFloat

    var body: some View {
        Group {
            if let asset, UIImage(named: asset) != nil {
                Image(asset)
                    .resizable()
                    .scaledToFit()
            } else {
                // asset 缺失（素材未覆盖的语义 / 无法反查的老数据）→ 中性占位。
                // 不回退 emoji：那是另一种材质，会污染整屏的立体语言。
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .fill(Theme.iconBg)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - 便利构造（让调用点保持一行）

extension CategoryIcon {
    init(_ cat: CategoryDef, size: CGFloat) {
        self.init(asset: cat.iconName, size: size)
    }

    init(_ sub: CategoryDef.SubDef, size: CGFloat) {
        self.init(asset: sub.iconName, size: size)
    }

    init(_ mood: Mood, size: CGFloat) {
        self.init(asset: mood.iconName, size: size)
    }
}
