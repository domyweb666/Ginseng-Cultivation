# Handoff: 上架只差多米在網頁填四張表再按送審

> 2026-11-18 19:45。分支 main（整晚分支 work/overnight-20261118-1130 已併入，157317f）。
> 先讀根目錄 `OVERNIGHT.md` 的「早上摘要」，那裡有多米要做的七個步驟。

## 現況
- TestFlight 1.0（34）＝付費造型完整版（M1–M4），主線 run 44288517862 全綠。
- App Store Connect：版本 1.0 文字、截圖、錄影、審核資料、價格、地區都填好，建置 34 已選；12 個內購 READY_TO_SUBMIT、有審核截圖。
- 送審卡住：App 隱私問卷、受管制醫療器材聲明、兩份合規表單（PPM SECURITY、AIGENERATE）只能網頁填。送審單 61910b89 已建（空），`gh workflow run asc.yml --ref main -f mode=submit -f build=34` 會沿用、放版本、掛內購、內購掛不上就不送出。
- 工具：`.github/workflows/asc.yml`（check／fill／media／submit，只准 main）、`ios/ci/asc_release.mjs`、`asc_publish.mjs`、`asc_listing.json`；`iap.yml`（多了 screenshots）；`.vibe/tools/limrun_store.mjs`（Limrun 拍原圖與錄影）、`.vibe/tools/store_shots.py`（照茄記準則合成）。

## 下一步
1. 多米填完四張表後跑 submit，看 log 是不是「送審了：WAITING_FOR_REVIEW」之類的狀態。內購若還是掛不上（FIRST_NON_CONSUMABLE…），請多米在版本頁「App 內購買項目」手動勾 12 個再按送審。
2. 多米在 TestFlight 1.0（34）驗沙盒購買與恢復購買。
3. 安全報告的 8 條建議（最先：RencanApp.swift 加 cloudKitDatabase: .none、ios.yml 手動觸發限 main）。
4. 商品頁截圖補健康 app、小工具兩張（要新 seed／真機）。

## 決策（別再爭）
- App Store 名稱沿用後台的「人蔘修煉：重訓修仙」；關鍵字見 asc_listing.json。
- 審核聯絡資訊放 GitHub secret REVIEW_CONTACT_JSON，不進 repo（repo 公開）。
- 不用多米的 Chrome、不輸入密碼。
- 推 main 的工具或文件 commit 一律帶 [skip ci]，免得多出 TestFlight 版本。
