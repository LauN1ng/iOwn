import SwiftUI
import UIKit

// MARK: - 分类 / 心情图标（Microsoft Fluent Emoji 3D）
//
// 图标来源：Microsoft Fluent Emoji（MIT 许可），已入库 Assets.xcassets。
// 清单与命名见 `docs/图标方案-定案-v1.md`：cat_* / sub_* / mood_*。
// 找不到 asset 时（例如用户自建的二级分类 `custom-xxxx`）自动退回 emoji 字符。
//
// ⚠️ 彩色贴图一律按 original 渲染 —— **不要加 `.renderingMode(.template)`**，
//    否则会被系统强制染成单色，3D 质感与配色全部丢失。
//    （这一点与旧的「单色线性图标」方案正好相反，是本次改造最容易踩的坑。）

struct CategoryIcon: View {
    /// Asset Catalog 名（如 "cat_coffee" / "sub_rent" / "mood_normal"）
    let asset: String?
    /// 找不到 asset 时的 emoji 兜底
    let fallback: String
    /// 绘制尺寸（pt），图片与 emoji 共用
    var size: CGFloat

    var body: some View {
        Group {
            if let asset, UIImage(named: asset) != nil {
                Image(asset)
                    .resizable()
                    .scaledToFit()
            } else {
                Text(fallback)
                    .scaledFont(size * 0.82)   // emoji 字形视觉尺寸略小于磅值，按比例补偿
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - 便利构造（让调用点保持一行）

extension CategoryIcon {
    init(_ cat: CategoryDef, size: CGFloat) {
        self.init(asset: cat.iconName, fallback: cat.emoji, size: size)
    }

    init(_ sub: CategoryDef.SubDef, size: CGFloat) {
        self.init(asset: sub.iconName, fallback: sub.emoji, size: size)
    }

    init(_ mood: Mood, size: CGFloat) {
        self.init(asset: mood.iconName, fallback: mood.emoji, size: size)
    }
}
