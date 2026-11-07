# 憑證、金鑰、保險箱：你要親手做的那半小時

這份是片 A1 的操作說明。做完之後，GitHub 的機器就能用你的名義簽 app、送 TestFlight。整個流程一年重做一次（憑證到期那天），所以每一步都寫到不用懂憑證是什麼也能照做。

先講三件事：

- 所有產生出來的檔案放 `E:\人篸修煉-secrets\`，這個資料夾在 repo 外面。repo 裡永遠不能有 .key、.csr、.cer、.p12、.p8，`.gitignore` 跟 pre-commit hook 都會擋，但你也不要手動複製進來。
- 密碼不要寫進任何檔案、不要貼到對話裡。要用到的時候只貼進 GitHub 的 Secrets 欄位。
- 我（AI）不會替你登入 Apple 或 Limrun，也不會碰你的密碼跟金鑰。卡住就截圖那一頁給我看，我告訴你下一步。

指令都在 Git Bash 貼。Git Bash 的路徑寫法是 `/e/人篸修煉-secrets`，不是 `E:\`。

## 第一段：刻私章（私鑰）跟申請單

打開 Git Bash，貼：

```bash
mkdir -p /e/人篸修煉-secrets && cd /e/人篸修煉-secrets
```

```bash
openssl genrsa -out rencan.key 2048
```

```bash
openssl req -new -key rencan.key -out rencan.csr -subj "/CN=Ginseng Cultivation/C=TW"
```

資料夾裡應該多兩個檔：`rencan.key`（私章，永遠留在你電腦）和 `rencan.csr`（申請單，等一下交給 Apple）。

## 第二段：請 Apple 蓋章（Apple Distribution 憑證）

1. 瀏覽器開 https://developer.apple.com/account/resources/certificates/list
2. 按藍色的「+」。
3. 選「Apple Distribution」，Continue。
4. 「Choose File」選 `E:\人篸修煉-secrets\rencan.csr`，Continue。
5. 按「Download」，存成 `E:\人篸修煉-secrets\distribution.cer`。

一個帳號最多三張 Apple Distribution 憑證。這張就夠，不要重複建。

## 第三段：把私章跟 Apple 的章合成一個檔（.p12）

回 Git Bash（還在 `/e/人篸修煉-secrets`）貼：

```bash
openssl x509 -in distribution.cer -inform DER -out distribution.pem
```

```bash
openssl pkcs12 -export -inkey rencan.key -in distribution.pem -out rencan.p12 -name "Apple Distribution" -keypbe PBE-SHA1-3DES -certpbe PBE-SHA1-3DES -macalg sha1
```

它會問你兩次密碼（Enter Export Password、Verifying）。自己設一個，記在你平常放密碼的地方。這個密碼等一下要貼進 GitHub 的 `APPLE_DIST_P12_PASSWORD`。

那三個加密參數是為了 macOS 的鑰匙圈吃得下，不是裝飾，別拿掉。

成功的話沒有任何錯誤訊息，資料夾多一個 `rencan.p12`。

## 第四段：登記 App ID

1. 開 https://developer.apple.com/account/resources/identifiers/list
2. 按「+」，選「App IDs」，Continue；選「App」，Continue。
3. Description 填 `Rencan`。
4. Bundle ID 選「Explicit」，填 `org.domyweb.rencan`。
5. 往下捲到 Capabilities，勾兩個：**HealthKit**、**App Groups**。
6. Continue，Register。

回到清單應該看得到 `org.domyweb.rencan`。

接著 App Group 本身也要登記一次：

1. 同一頁按「+」，這次選「App Groups」，Continue。
2. Description 填 `Rencan Group`，Identifier 填 `group.org.domyweb.rencan`。
3. Continue，Register。

然後回到 Identifiers 清單點 `org.domyweb.rencan`，App Groups 那列按「Configure」，勾 `group.org.domyweb.rencan`，Save。

## 第五段：App Store Connect 的「代送件」鑰匙（API 金鑰）

1. 開 https://appstoreconnect.apple.com/access/integrations/api
2. 如果看到「Request Access」就按下去同意條款（只有第一次）。
3. 在「Team Keys」按「+」（Generate API Key）。
4. Name 填 `rencan-ci`，Access 選 **App Manager**。Generate。
5. 這一列會出現「Download API Key」，**只能下載一次**，存到 `E:\人篸修煉-secrets\`，檔名長得像 `AuthKey_ABC123DEFG.p8`。
6. 抄下這一列的 **Key ID**（十碼），還有這一頁上方的 **Issuer ID**（一長串有連字號的）。這兩個不是秘密等級的東西，但也只貼進 GitHub Secrets。

## 第六段：在 App Store Connect 建 app 記錄

1. 開 https://appstoreconnect.apple.com/apps
2. 按「+」，New App。
3. Platforms 勾 iOS。
4. Name 填 `人蔘修煉`。這個名字在整個 App Store 要獨一無二，如果它說被用了，先填 `人蔘修煉：重訓修仙`，之後上架前可以再改。
5. Primary Language 選「Chinese (Traditional)」。
6. Bundle ID 選 `org.domyweb.rencan`（第四段登記的那個）。
7. SKU 填 `rencan-ios`。
8. User Access 選 Full Access。Create。

## 第七段：讓你的手機收得到 TestFlight

1. 同一個 app 進去，上方分頁選「TestFlight」。
2. 左邊「Internal Testing」按「+」，群組名填 `內部`，勾「Enable automatic distribution」，Create。
3. 群組裡按「+」加測試員，選你自己的 Apple 帳號。
4. iPhone 裝 App Store 裡的「TestFlight」app，用同一個 Apple 帳號登入。之後每次 GitHub 綠燈，十幾分鐘內 TestFlight 會跳出新版本。

## 第八段：把七樣東西放進 GitHub 的保險箱

先在 Git Bash 把兩個檔轉成一串文字（轉完直接進剪貼簿，貼到 GitHub 就好）：

```bash
base64 -w0 /e/人篸修煉-secrets/rencan.p12 | clip
```

然後開 https://github.com/domyweb666/Ginseng-Cultivation/settings/secrets/actions ，按「New repository secret」，Name 填 `APPLE_DIST_P12_BASE64`，Secret 欄按 Ctrl+V 貼上，Add secret。

接著一個一個加，名字要一字不差：

| Name | 貼什麼 |
|---|---|
| `APPLE_DIST_P12_BASE64` | 上面那條指令轉出來的（已經貼了） |
| `APPLE_DIST_P12_PASSWORD` | 第三段你設的 .p12 密碼 |
| `APPLE_TEAM_ID` | 開 https://developer.apple.com/account ，往下捲到 Membership details 的 Team ID（十碼） |
| `ASC_KEY_ID` | 第五段抄的 Key ID |
| `ASC_ISSUER_ID` | 第五段抄的 Issuer ID |
| `ASC_KEY_P8_BASE64` | 跑下面這條再 Ctrl+V |
| `LIM_API_KEY` | 第九段 |

`ASC_KEY_P8_BASE64` 的轉法（檔名換成你第五段下載的那個）：

```bash
base64 -w0 /e/人篸修煉-secrets/AuthKey_ABC123DEFG.p8 | clip
```

加完清單應該有 7 個名字。少一個，GitHub Actions 跑到那一步會紅，紅燈紀錄會寫出缺哪個。

## 第九段：Limrun（AI 自己看畫面用的雲端 iPhone）

你 2026-11-07 已經換了一個有點數的 Limrun 帳號。這台電腦上的舊金鑰還是前一個帳號的，要換掉：

1. 用新帳號開 https://console.limrun.com ，找 API Keys，建一把新的，名稱 `rencan`，複製。
2. 開 `C:\Users\fcharlie\.lim\config.yaml`，把 `api-key:` 後面那串換成新的，存檔。
3. 到 GitHub 的 Secrets 加 `LIM_API_KEY`，貼同一把。

之後我在 Claude Code 裡跑 `.vibe/tools/limrun_check.mjs` 就會用它開模擬器、截圖、刪機器，每次十分鐘內。模擬器每分鐘 2 點，Entry 方案 500 點一個月，大約夠四小時。

## 第十段：最後確認

在 `E:\人篸修煉` 跑：

```bash
git status --short
```

不應該出現任何 .key、.csr、.cer、.pem、.p12、.p8。全部都在 `E:\人篸修煉-secrets\`，那個資料夾你自己備份一份到安全的地方（私章掉了就得整套重做）。

做到這裡 A1 就完成了，跟我說一聲，我 push 上去讓生產線跑第一次。

## 一年後憑證到期

Apple Distribution 憑證有效一年。到期前 Apple 會寄信。重做第一段到第三段（可以沿用 `rencan.key`，只重做 CSR、憑證、.p12），然後更新 `APPLE_DIST_P12_BASE64` 跟 `APPLE_DIST_P12_PASSWORD` 兩個 secret。API 金鑰不會過期，除非你自己撤銷。

## 常見紅燈

- 「No signing certificate "iOS Distribution" found」：.p12 沒匯進鑰匙圈。多半是 `APPLE_DIST_P12_PASSWORD` 打錯，或第三段沒加那三個加密參數。
- 「Provisioning profile ... doesn't include the com.apple.developer.healthkit entitlement」：第四段 App ID 沒勾 HealthKit 或 App Groups，回去勾完再重跑。
- 「App Store Connect 找不到 bundle id」：第六段沒建 app 記錄。
- 「Limrun 400 NoSubscription」：第九段用到舊帳號的金鑰，或新帳號點數用完。
