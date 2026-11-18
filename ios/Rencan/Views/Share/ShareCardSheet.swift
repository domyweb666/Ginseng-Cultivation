import Photos
import RencanCore
import SwiftData
import SwiftUI

/// 這一頁自己的版面常數（照 .uiux/介面選項-2026-11-19/分享流程預覽.html 第 1 支手機）。
private enum Metrics {
    /// 卡片預覽縮成幾倍：360×640 的卡在手機上放得下、下面還看得到道號那一欄
    static let previewScale: CGFloat = 0.7
    static let previewSize = CGSize(width: 360 * previewScale, height: 640 * previewScale)
    /// 卡片的影子
    static let cardShadowRadius: CGFloat = 14
    static let cardShadowY: CGFloat = 8
    static let cardShadowOpacity: Double = 0.18
    /// 表單卡片的左右內距、道號輸入框的寬
    static let cardInset: CGFloat = 16
    static let nameFieldWidth: CGFloat = 180
}

/// 修煉卡頁（2026-11-19 多米選甲版）：卡片預覽、道號、要不要顯示體脂，底下「存到相簿」「分享」。
/// 分享交給系統的分享面板：卡的圖加一句話（多米選 A），LINE、訊息會收到兩則，IG 限動只吃圖。
/// 存到相簿只要「加入照片」的權限，看不到使用者的相簿。
struct ShareCardSheet: View {
    @Environment(AppFlow.self) private var flow
    @Environment(StoreService.self) private var store
    @Environment(PurchaseService.self) private var purchases
    @Query private var settingsRows: [UserSettings]
    let digest: Digest

    @State private var daoName = ""
    @State private var showsBodyFat = true
    /// 照目前的道號與開關做好的 1080×1920 圖；內容一改就重做
    @State private var rendered: UIImage?
    /// 卡片下面那一句：存好了、或為什麼沒存成
    @State private var notice: String?
    @State private var isSaving = false

    private var content: ShareCardContent? {
        ShareCardContent(
            digest: digest,
            style: purchases.effective(settingsRows.first?.portraitStyle ?? .original),
            daoName: daoName,
            showsBodyFat: showsBodyFat
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            SheetHeader(title: "修煉卡", dismissLabel: "關閉")
            if let content {
                ScrollView {
                    VStack(spacing: RencanLayout.sectionSpacing) {
                        preview(content)
                        form
                        if let notice {
                            Text(notice)
                                .font(RencanType.footnote)
                                .foregroundStyle(Color.rencan.textSecondary)
                                .accessibilityIdentifier("share-card-notice")
                        }
                    }
                    .padding(.horizontal, RencanLayout.screenMargin)
                    .padding(.bottom, RencanLayout.sectionSpacing)
                }
                buttons(content)
                    .task(id: content) {
                        rendered = ShareCard.render(content)
                    }
            } else {
                // 入口在沒量過時是藏起來的；萬一還是打開了，講清楚要先做什麼
                Text("量過一次體組成，就有修煉卡可以分享。")
                    .font(RencanType.body)
                    .foregroundStyle(Color.rencan.textSecondary)
                    .padding(RencanLayout.screenMargin)
                Spacer()
            }
        }
        .background(Color.rencan.canvas)
        .onAppear {
            daoName = settingsRows.first?.daoName ?? ""
        }
        .onDisappear {
            saveDaoName()
        }
    }

    private func preview(_ content: ShareCardContent) -> some View {
        ShareCard(content: content)
            .scaleEffect(Metrics.previewScale)
            .frame(width: Metrics.previewSize.width, height: Metrics.previewSize.height)
            .shadow(
                color: Color.rencan.shadow.opacity(Metrics.cardShadowOpacity),
                radius: Metrics.cardShadowRadius, y: Metrics.cardShadowY
            )
            .padding(.top, RencanLayout.itemSpacing)
    }

    /// 道號（選填、打過會記住）與體脂開關。
    private var form: some View {
        VStack(spacing: 0) {
            HStack(spacing: RencanLayout.groupSpacing) {
                Text("道號")
                    .font(RencanType.body)
                Spacer()
                TextField("取一個道號", text: $daoName)
                    .font(RencanType.termBody)
                    .multilineTextAlignment(.trailing)
                    .frame(width: Metrics.nameFieldWidth)
                    .submitLabel(.done)
                    .onSubmit(saveDaoName)
                    .onChange(of: daoName) { _, newValue in
                        if newValue.count > ShareCardContent.daoNameLimit {
                            daoName = String(newValue.prefix(ShareCardContent.daoNameLimit))
                        }
                    }
                    .accessibilityIdentifier("share-card-dao-name")
            }
            .frame(minHeight: RencanLayout.rowHeight)
            RowDivider()
            Toggle(isOn: $showsBodyFat) {
                Text("顯示體脂")
                    .font(RencanType.body)
            }
            .tint(Color.rencan.accent)
            .frame(minHeight: RencanLayout.rowHeight)
            .accessibilityIdentifier("share-card-body-fat")
        }
        .padding(.horizontal, Metrics.cardInset)
        .background(
            Color.rencan.surface,
            in: RoundedRectangle(cornerRadius: RencanLayout.cardCornerRadius)
        )
    }

    private func buttons(_ content: ShareCardContent) -> some View {
        HStack(spacing: RencanLayout.groupSpacing) {
            Button("存到相簿") {
                Task { await saveToPhotos() }
            }
            .buttonStyle(RencanSecondaryButtonStyle())
            .disabled(rendered == nil || isSaving)
            .accessibilityIdentifier("share-card-save")
            if let rendered {
                let image = Image(uiImage: rendered)
                ShareLink(
                    item: image,
                    subject: Text("修煉卡"),
                    message: Text(content.shareMessage),
                    preview: SharePreview("修煉卡", image: image)
                ) {
                    Text("分享")
                }
                .buttonStyle(RencanPrimaryButtonStyle())
                .simultaneousGesture(TapGesture().onEnded(saveDaoName))
                .accessibilityIdentifier("share-card-share")
            } else {
                Button("分享") {}
                    .buttonStyle(RencanPrimaryButtonStyle())
                    .disabled(true)
            }
        }
        .padding(.horizontal, RencanLayout.screenMargin)
        .padding(.vertical, RencanLayout.itemSpacing)
        .background(Color.rencan.canvas)
    }

    /// 道號打過一次就記住，下次打開不用再打。沒變就不寫資料庫。
    private func saveDaoName() {
        guard daoName != (settingsRows.first?.daoName ?? "") else { return }
        do {
            try store.setDaoName(daoName)
        } catch {
            flow.showError(error)
        }
    }

    /// 存一張 1080×1920 的圖到相簿。第一次會問要不要讓 app 加入照片；沒答應就講怎麼打開。
    private func saveToPhotos() async {
        guard let rendered else { return }
        isSaving = true
        defer { isSaving = false }
        saveDaoName()
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            notice = "沒有存到相簿。到「設定」讓人蔘修煉可以加入照片，再試一次。"
            return
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: rendered)
            }
            notice = "已存到相簿"
        } catch {
            notice = "沒有存成功，請再試一次。"
        }
    }
}

/// 頁首右上角的分享圖示（2026-11-19 多米選「一」：境界頁、分析頁同一個位置）。點了打開修煉卡頁。
struct ShareCardButton: View {
    @Environment(AppFlow.self) private var flow

    var body: some View {
        Button {
            flow.sheet = .shareCard
        } label: {
            Image(systemName: "square.and.arrow.up")
                .font(RencanType.tabIcon)
                .foregroundStyle(Color.rencan.strong)
                .frame(minWidth: RencanLayout.tapTarget, minHeight: RencanLayout.tapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("分享修煉卡")
        .accessibilityIdentifier("share-card-open")
    }
}
