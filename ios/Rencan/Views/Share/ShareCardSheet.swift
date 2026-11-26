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

/// 記著道號輸入框（不持有它，頁面關掉就放手）。
private final class NameFieldBox {
    weak var field: UITextField?
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
    /// 打超過字數上限、多的字被拿掉之後，欄位下面那一句提醒要不要出現
    @State private var showsNameLimitHint = false
    /// 道號輸入框在 UIKit 那一層的本體，只用來問它是不是還在選字
    @State private var nameField = NameFieldBox()
    @State private var showsBodyFat = true
    /// 照目前的道號與開關做好的 1080×1920 圖；內容一改，停手一下才重做
    @State private var rendered: UIImage?
    /// rendered 是照哪一份內容畫的。跟現在的內容不一樣，就是最新那張還沒畫好
    @State private var renderedContent: ShareCardContent?
    /// 卡片下面那一句：存好了、或為什麼沒存成
    @State private var notice: String?
    @State private var isSaving = false

    /// 內容改了停手多久才重畫。打道號時每按一個鍵內容就變一次，每次都在主執行緒畫一張
    /// 1080×1920 的圖，舊手機打字會黏（2026-11-26 性能審查）。
    private static let renderPauseSeconds = 0.3

    private var content: ShareCardContent? {
        ShareCardContent(
            digest: digest,
            style: purchases.effective(settingsRows.first?.portraitStyle ?? .original),
            // 注音選字中，欄位裡會暫時多出幾個注音符號（見 trimDaoName）；卡上永遠只畫上限以內的字
            daoName: String(daoName.prefix(ShareCardContent.daoNameLimit)),
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
                        await render(content)
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
            nameRow
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

    /// 道號那一列：左邊標題、右邊輸入框。打超過上限時，下面多一句提醒。
    private var nameRow: some View {
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
                    // 兩個時機都看一次：系統的通知和 daoName 寫回來誰先誰後不一定
                    // （只在通知那一刻看，CI 上第九個字進來時 daoName 還是舊的，沒截到也沒提醒）
                    .onReceive(Self.textChanges) { note in
                        nameField.field = note.object as? UITextField
                        trimDaoName()
                    }
                    .onChange(of: daoName) { _, _ in trimDaoName() }
                    .accessibilityIdentifier("share-card-dao-name")
            }
            .frame(minHeight: RencanLayout.rowHeight)
            if showsNameLimitHint {
                limitHint
            }
        }
    }

    private var limitHint: some View {
        Text("道號最多 \(ShareCardContent.daoNameLimit) 個字")
            .font(RencanType.footnote)
            .foregroundStyle(Color.rencan.destructive)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.bottom, RencanLayout.groupSpacing)
            .accessibilityValue(fieldWatchNote)
            .accessibilityIdentifier("share-card-dao-name-limit")
    }

    /// 檢查線用：輸入框的通知有沒有接到。沒接到的話「選字中不截字」那一段不會有作用，測試要擋下來。
    /// 上架的版本是空字串，旁白不會多唸東西。
    private var fieldWatchNote: String {
        #if DEBUG
            return nameField.field == nil ? "沒接到輸入框" : "有接到輸入框"
        #else
            return ""
        #endif
    }

    /// 輸入框的字每變一次就通知一次（注音還在選字時也會）。這一頁只有道號一個輸入框。
    private static let textChanges = NotificationCenter.default.publisher(
        for: UITextField.textDidChangeNotification
    )

    private func buttons(_ content: ShareCardContent) -> some View {
        HStack(spacing: RencanLayout.groupSpacing) {
            Button("存到相簿") {
                Task { await saveToPhotos() }
            }
            .buttonStyle(RencanSecondaryButtonStyle())
            .disabled(rendered == nil || isSaving)
            .accessibilityIdentifier("share-card-save")
            // 最新那張還沒畫好時不給分享，免得分享出去的是改之前的卡
            if let rendered, renderedContent == content {
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

    /// 剛打開還沒有圖時馬上畫，按鈕不用空等；之後內容改了，停手一下才畫，被下一次修改取消就不畫。
    private func render(_ content: ShareCardContent) async {
        if rendered != nil {
            guard await Task.pause(seconds: ShareCardSheet.renderPauseSeconds) else { return }
        }
        rendered = ShareCard.render(content)
        renderedContent = content
    }

    /// 道號超過上限就把多的字拿掉，並在欄位下面提醒一句；刪到上限以內提醒就收起來。
    /// 注音、拼音還在選字時不能動欄位的字：一動，選到一半的字會變成一串注音符號，
    /// 已經打了六七個字的人就打不出最後一個字。所以等選完字（輸入框沒有 markedText）再算、再截。
    private func trimDaoName() {
        guard nameField.field?.markedTextRange == nil else { return }
        let limit = ShareCardContent.daoNameLimit
        if daoName.count > limit {
            daoName = String(daoName.prefix(limit))
            showsNameLimitHint = true
        } else if daoName.count < limit {
            showsNameLimitHint = false
        }
    }

    /// 道號打過一次就記住，下次打開不用再打。沒變就不寫資料庫。存之前再截一次，上限以外的字不進資料庫。
    private func saveDaoName() {
        if daoName.count > ShareCardContent.daoNameLimit {
            daoName = String(daoName.prefix(ShareCardContent.daoNameLimit))
        }
        guard daoName != (settingsRows.first?.daoName ?? "") else { return }
        do {
            try store.setDaoName(daoName)
        } catch {
            flow.showError(error)
        }
    }

    /// 存一張 1080×1920 的圖到相簿。第一次會問要不要讓 app 加入照片；沒答應就講怎麼打開。
    private func saveToPhotos() async {
        guard let content else { return }
        isSaving = true
        defer { isSaving = false }
        saveDaoName()
        // 打完字馬上按的話，最新那張還在等停手：當下照最新的內容現畫一張，存的一定是看到的那張卡
        guard let image = renderedContent == content ? rendered : ShareCard.render(content) else {
            notice = "沒有存成功，請再試一次。"
            return
        }
        let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        guard status == .authorized || status == .limited else {
            notice = "沒有存到相簿。到「設定」讓人蔘修煉可以加入照片，再試一次。"
            return
        }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
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
