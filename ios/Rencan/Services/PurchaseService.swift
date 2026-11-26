import Foundation
import Observation
import StoreKit

/// 內購出錯時給使用者看的話。系統的訊息不原樣給人看（跟 HealthError 同一個做法）。
enum PurchaseError: LocalizedError, Equatable {
    /// 讀不到 App Store 的商品：沒網路、商店暫時不通、商品還沒上架
    case storeUnavailable
    /// 付款沒有完成
    case purchaseFailed
    /// Apple 回來的交易驗證不過。當作沒買，不套用造型
    case unverified
    /// 要家長同意（購買前先問）。核准後 Apple 會通知，app 自己套用
    case pending
    /// 恢復購買沒有完成
    case restoreFailed

    var message: String {
        switch self {
        case .storeUnavailable:
            return "連不上 App Store，稍後再試"
        case .purchaseFailed:
            return "這次沒有買成，沒有扣款"
        case .unverified:
            return "這筆購買驗證不過，請按恢復購買"
        case .pending:
            return "等待核准，核准後會自動換上"
        case .restoreFailed:
            return "沒有恢復成功，請再試一次"
        }
    }

    var errorDescription: String? { message }
}

/// 付費造型的內購（組塊 M3，.vibe/付費造型計畫.md）。買、恢復購買、查買過什麼都走這裡。
///
/// 安全標準（付費出錯倒向鎖住）：
/// - 買過什麼只認 Apple 驗證過、沒被撤銷的交易（`Transaction.currentEntitlements`）。
///   app 不在本機存「已購買」旗標，換手機、重裝、退款都以 Apple 那邊為準。
/// - 讀不到、驗證不過、出任何錯都當作沒買：畫面顯示鎖，境界碑顯示原版。
/// - 價格字串一律用 Apple 給的 `displayPrice`，app 裡不寫死價格。
///
/// UI 測試模式（-rencanUITest，只有 Debug 版有）不碰 App Store：價格用固定字串、
/// 買了直接算有，`-rencanOwn` 可以先給幾種（UITestSupport）。Release 版這條路走不到。
@MainActor
@Observable
final class PurchaseService {
    /// 產品 ID 的前綴，後面接造型代碼（PortraitStyle.rawValue）。跟 ios/ci/iap_products.json 一字不差。
    static let productPrefix = "org.domyweb.rencan.style."
    /// 全套十一種
    static let bundleProductID = productPrefix + "all"
    /// 十二個商品：十一種單買加全套
    static let allProductIDs: [String] =
        PortraitStyle.allCases.compactMap(\.productID) + [bundleProductID]

    /// Apple 驗證過、還有效的商品
    private(set) var ownedProductIDs: Set<String> = []
    /// 產品 ID → Apple 給的價格字串（例如 NT$120）
    private(set) var displayPrices: [String: String] = [:]
    /// 上次讀商品沒讀齊。選造型頁看這個顯示「連不上 App Store」、購買鍵不能按
    private(set) var isStoreUnavailable = false

    @ObservationIgnored private var products: [String: Product] = [:]
    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    /// 這種造型能不能用。原版免費；買了單一種或全套都算有。
    func owns(_ style: PortraitStyle) -> Bool {
        guard let productID = style.productID else { return true }
        return ownedProductIDs.contains(productID) || ownedProductIDs.contains(Self.bundleProductID)
    }

    /// 設定裡存的造型如果沒買（或退款了），畫面一律顯示原版。
    func effective(_ style: PortraitStyle) -> PortraitStyle {
        owns(style) ? style : .original
    }

    /// 十一種都有了，選造型頁就不再顯示全套與購買鍵。
    var ownsEverything: Bool {
        PortraitStyle.allCases.allSatisfy(owns)
    }

    /// 開始聽 Apple 推過來的交易：別台裝置買的、家長核准的、退款撤銷的。app 一打開就要聽，
    /// 不然這些交易會一直等著沒人處理。只開一次。
    func start() {
        guard updatesTask == nil, !UITestSupport.isUITest else { return }
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                // 驗證不過的交易不 finish、不算數，下一次 currentEntitlements 也不會有它（倒向鎖住）。
                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
                await self.refreshEntitlements()
            }
        }
    }

    /// 讀價格與買過的東西。app 回到前景、打開選造型頁時各叫一次。
    /// 讀不到價格不往上丟：選造型頁照 isStoreUnavailable 顯示「連不上 App Store」，
    /// 已買的照 Apple 給的算（這段不需要網路）。
    func refresh() async {
        if UITestSupport.isUITest {
            applyTestStore()
            return
        }
        do {
            let found = try await Product.products(for: Self.allProductIDs)
            var byID: [String: Product] = [:]
            for product in found {
                byID[product.id] = product
            }
            products = byID
            displayPrices = products.mapValues(\.displayPrice)
            isStoreUnavailable = products.count != Self.allProductIDs.count
        } catch {
            isStoreUnavailable = true
        }
        await refreshEntitlements()
    }

    /// 買一個商品。買到回 true；使用者自己按取消回 false（不算錯，畫面什麼都不說）。
    func purchase(_ productID: String) async throws -> Bool {
        if UITestSupport.isUITest {
            ownedProductIDs.insert(productID)
            return true
        }
        guard let product = products[productID] else { throw PurchaseError.storeUnavailable }
        let result: Product.PurchaseResult
        do {
            result = try await product.purchase()
        } catch {
            throw PurchaseError.purchaseFailed
        }
        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else {
                throw PurchaseError.unverified
            }
            await transaction.finish()
            await refreshEntitlements()
            return ownedProductIDs.contains(productID)
        case .userCancelled:
            return false
        case .pending:
            throw PurchaseError.pending
        @unknown default:
            throw PurchaseError.purchaseFailed
        }
    }

    /// 恢復購買（審核規範 3.1.1 要有）：叫 Apple 重新同步一次，再照驗證過的交易重算。
    func restore() async throws {
        if UITestSupport.isUITest { return }
        do {
            try await AppStore.sync()
        } catch {
            throw PurchaseError.restoreFailed
        }
        await refreshEntitlements()
    }

    /// 只收 Apple 驗證過、沒被撤銷（退款）、而且是這十二個商品之一的交易。
    private func refreshEntitlements() async {
        var owned: Set<String> = []
        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement,
                transaction.revocationDate == nil,
                Self.allProductIDs.contains(transaction.productID)
            else { continue }
            owned.insert(transaction.productID)
        }
        // 一樣就不重新指定：@Observable 一指定就通知，回前景時最外層會白白重畫一次。
        guard owned != ownedProductIDs else { return }
        ownedProductIDs = owned
    }

    /// UI 測試用的假商店：價格寫死、已買的看啟動參數。只有 isUITest（Debug 版）會走到。
    private func applyTestStore() {
        var prices: [String: String] = [:]
        for productID in Self.allProductIDs {
            prices[productID] =
                productID == Self.bundleProductID
                ? UITestSupport.testBundlePrice : UITestSupport.testSinglePrice
        }
        displayPrices = prices
        isStoreUnavailable = false
        if ownedProductIDs.isEmpty {
            ownedProductIDs = Set(UITestSupport.ownedStyleCodes.map { Self.productPrefix + $0 })
        }
    }
}

extension PortraitStyle {
    /// 單買這種造型的產品 ID。原版免費，沒有。
    var productID: String? {
        self == .original ? nil : PurchaseService.productPrefix + rawValue
    }
}
