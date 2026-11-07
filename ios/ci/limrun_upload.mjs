// 把模擬器版 .app 的 zip 上傳到 Limrun 的 Asset Storage（交付圖 d13）。
// 用法：LIM_API_KEY=... node limrun_upload.mjs <zip 路徑> <資產名稱>
// 只上傳建置檔，不含任何使用者資料；金鑰只從環境變數讀，不印出來（安全標準類別 9）。
import { statSync } from "node:fs";
import Limrun from "@limrun/api";

const [zipPath, assetName] = process.argv.slice(2);
if (!zipPath || !assetName) {
  console.error("用法：node limrun_upload.mjs <zip 路徑> <資產名稱>");
  process.exit(2);
}
if (!process.env.LIM_API_KEY) {
  console.error("缺 LIM_API_KEY：GitHub Secrets 要有這一把，見 ios/ci/README.md 第九段");
  process.exit(2);
}
const sizeBytes = statSync(zipPath).size;
if (sizeBytes === 0) {
  console.error("zip 是空的，模擬器版建置可能失敗了：" + zipPath);
  process.exit(1);
}

const lim = new Limrun({ apiKey: process.env.LIM_API_KEY });
// 七天後自動刪，Limrun 那邊不會一直堆舊版
const asset = await lim.assets.getOrUpload({
  path: zipPath,
  name: assetName,
  platform: "ios",
  kind: "App",
  ttl: "168h",
});
console.log(`Limrun 資產已就緒：${asset.name}（id ${asset.id}，${Math.round(sizeBytes / 1024)} KB）`);
