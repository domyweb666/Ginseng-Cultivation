# 人蔘修煉

把重訓變成修仙的 iPhone 網頁 app。

- **境界**：用體組成算 FFMI（去脂體重 ÷ 身高²，含身高校正），從煉氣到渡劫，每個境界分初、中、後期。體脂要在 10–18% 才算根基穩固。
- **功法**：深蹲、硬舉、臥推、肩推、划船、引體向上，各是一門功法。用估計 1RM ÷ 體重分成入門到化境。
- **宗門身分**：同時看修煉天數和曾達到的最高境界。實力夠但天數不夠是客卿，天數夠但境界還沒跟上是執事。
- **突破紀錄**：記下每次進入新期別的日期和花費的時間。
- 破紀錄、功法升階、宗門晉升、境界突破都有全螢幕動畫。

## 使用

單一 `index.html`，不需要建置。資料存在瀏覽器的 localStorage，只留在這台裝置上。

開啟 GitHub Pages（Settings → Pages → Deploy from a branch → `main` / root）後，用 iPhone Safari 打開網址，按「分享 → 加入主畫面」就能當 app 用。

## 檔案

- `index.html`：整個 app
- `img/r0.webp` – `img/r6.webp`：煉氣到渡劫的立繪
- `img/elder.webp`：宗門晉升圖
- `img/icon.webp`、`img/apple-touch-icon.png`、`img/icon-*.png`：圖示
- `manifest.webmanifest`：加入主畫面用的設定
