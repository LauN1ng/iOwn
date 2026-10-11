import SwiftUI

/// 卡面选择器（照用户参考图的「卡面」页）：2 列网格 + 搜索 + 选中态。
/// 纯选择器，**不在这里做任何写入** —— 选完回填给 `AddAccountSheet`。
struct CardFacePicker: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selection: CardFace

    @State private var query = ""

    private var faces: [CardFace] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return CardFace.allCases }
        return CardFace.allCases.filter { $0.displayName.localizedCaseInsensitiveContains(q) }
    }

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        VStack(spacing: 0) {
            SheetGrabber()

            HStack {
                Button { Haptics.tap(); dismiss() } label: {
                    Text("取消").scaledFont(15).foregroundStyle(.secondary)
                }
                .buttonStyle(PressableButtonStyle(scale: 0.96))
                Spacer()
                Text("卡面").scaledFont(17, weight: .bold)
                Spacer()
                Text("取消").scaledFont(15).opacity(0)   // 占位：让标题保持居中
            }
            .padding(.horizontal, Radius.pagePadding)
            .padding(.top, 4)

            ScrollView {
                VStack(spacing: 16) {
                    search

                    LazyVGrid(columns: columns, spacing: 18) {
                        ForEach(faces, id: \.id) { face in
                            Button {
                                Haptics.tap()
                                selection = face
                                dismiss()
                            } label: {
                                CardFaceThumb(face: face,
                                              selected: face == selection,
                                              width: 150, height: 92)
                            }
                            .buttonStyle(PressableButtonStyle(scale: 0.97))
                            .accessibilityLabel("卡面 \(face.displayName)")
                            .accessibilityValue(face == selection ? "已选中" : "")
                        }
                    }

                    if faces.isEmpty {
                        Text("没有匹配的卡面")
                            .scaledFont(13).foregroundStyle(.secondary)
                            .padding(.top, 30)
                    }
                }
                .padding(.horizontal, Radius.pagePadding)
                .padding(.top, 14)
                .padding(.bottom, 34)
            }
        }
        .background(Theme.bg)
    }

    private var search: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .scaledFont(14)
                .foregroundStyle(.secondary)
            TextField("卡面名称", text: $query)
                .scaledFont(14.5)
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .scaledFont(14)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(PressableButtonStyle(scale: 0.9))
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 11)
        .background(Theme.card)
        .cornerRadius(12)
    }
}

#Preview {
    CardFacePicker(selection: .constant(.classic))
}
