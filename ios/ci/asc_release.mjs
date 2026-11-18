// 上架用：查與填 App Store Connect 上「人蔘修煉」這個 app 的版本資料（片 J2、J4）。
// 環境變數 MODE：
//   check  只讀：列出 app 資訊、版本、建置、各語系文字、截圖、年齡分級、審核資料、價格與地區、內購狀態。
//          不改任何東西。哪一欄是空的就印「缺」，送審前照這份清單補。
// 之後的模式（填資料、傳截圖、送審）照 check 看到的狀態再加，先查清楚再動手。
// API 的簽章與呼叫在 asc_api.mjs，零套件。
// 用法（環境變數）：ASC_KEY_ID、ASC_ISSUER_ID、ASC_KEY_P8_PATH、BUNDLE_ID、MODE
import { ascClient, env } from "./asc_api.mjs";

const MODES = ["check"];
const mode = env("MODE");
if (!MODES.includes(mode)) {
  throw new Error(`MODE 只能是 ${MODES.join(" 或 ")}，收到 ${mode}`);
}
const bundleId = env("BUNDLE_ID");
const call = ascClient();

/// 讀一個端點；讀不到就印出原因（不吞掉），回 null 讓後面照樣把其他欄位列完。
async function read(label, path) {
  try {
    return await call("GET", path);
  } catch (error) {
    console.log(`  ！讀不到${label}：${error.message.slice(0, 300)}`);
    return null;
  }
}

const show = (label, value) =>
  console.log(`  ${label}：${value === null || value === undefined || value === "" ? "缺" : value}`);

const apps = await call("GET", `/v1/apps?filter[bundleId]=${encodeURIComponent(bundleId)}`);
const app = apps.data[0];
if (!app) {
  throw new Error(`App Store Connect 找不到 bundle id ${bundleId} 的 app`);
}
console.log(`== app：${app.attributes.name}（${app.id}）`);
show("主要語系", app.attributes.primaryLocale);
show("內容版權聲明", app.attributes.contentRightsDeclaration);

console.log("== app 資訊（名稱、副標、隱私政策網址、類別、年齡分級）");
const infos = await read("app 資訊", `/v1/apps/${app.id}/appInfos?include=primaryCategory`);
for (const info of infos?.data ?? []) {
  console.log(`- appInfo ${info.id} 狀態 ${info.attributes.state ?? info.attributes.appStoreState}`);
  show("主要類別", info.relationships?.primaryCategory?.data?.id);
  const locs = await read("app 資訊語系", `/v1/appInfos/${info.id}/appInfoLocalizations`);
  for (const loc of locs?.data ?? []) {
    console.log(`  [${loc.attributes.locale}]`);
    show("  名稱", loc.attributes.name);
    show("  副標", loc.attributes.subtitle);
    show("  隱私政策網址", loc.attributes.privacyPolicyUrl);
  }
  const age = await read("年齡分級", `/v1/appInfos/${info.id}/ageRatingDeclaration`);
  const filled = age?.data
    ? Object.entries(age.data.attributes).filter(([, value]) => value !== null).length
    : 0;
  show("年齡分級已填欄位數", age?.data ? `${filled}/${Object.keys(age.data.attributes).length}` : null);
}

console.log("== 版本");
const versions = await read(
  "版本",
  `/v1/apps/${app.id}/appStoreVersions?limit=10&include=build,appStoreReviewDetail`,
);
for (const version of versions?.data ?? []) {
  const attrs = version.attributes;
  console.log(
    `- ${attrs.platform} ${attrs.versionString}（${version.id}）狀態 ${attrs.appStoreState} / ${attrs.appVersionState ?? ""}`,
  );
  show("  發佈方式", attrs.releaseType);
  show("  版權", attrs.copyright);
  show("  建置", version.relationships?.build?.data?.id);
  const review = await read("審核資料", `/v1/appStoreVersions/${version.id}/appStoreReviewDetail`);
  const detail = review?.data?.attributes;
  show("  審核聯絡人", detail ? (detail.contactEmail ? "有" : null) : null);
  show("  審核備註字數", detail?.notes ? detail.notes.length : null);
  show("  需要示範帳號", detail ? detail.demoAccountRequired : null);
  const locs = await read("版本語系", `/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations`);
  for (const loc of locs?.data ?? []) {
    const la = loc.attributes;
    console.log(`  [${la.locale}]`);
    show("    描述字數", la.description ? la.description.length : null);
    show("    關鍵字", la.keywords);
    show("    支援網址", la.supportUrl);
    show("    行銷網址", la.marketingUrl);
    show("    宣傳文字字數", la.promotionalText ? la.promotionalText.length : null);
    const sets = await read("截圖組", `/v1/appStoreVersionLocalizations/${loc.id}/appScreenshotSets`);
    for (const set of sets?.data ?? []) {
      const shots = await read("截圖", `/v1/appScreenshotSets/${set.id}/appScreenshots`);
      console.log(`    截圖 ${set.attributes.screenshotDisplayType}：${shots?.data?.length ?? "?"} 張`);
    }
    if ((sets?.data ?? []).length === 0) show("    截圖", null);
  }
}

console.log("== 最近的建置");
const builds = await read(
  "建置",
  `/v1/builds?filter[app]=${app.id}&sort=-uploadedDate&limit=5&include=preReleaseVersion`,
);
const preRelease = new Map((builds?.included ?? []).map((item) => [item.id, item.attributes.version]));
for (const build of builds?.data ?? []) {
  const ba = build.attributes;
  const marketing = preRelease.get(build.relationships?.preReleaseVersion?.data?.id) ?? "?";
  console.log(
    `- ${marketing}（${ba.version}）${build.id} 處理 ${ba.processingState}，上傳 ${ba.uploadedDate}，加密聲明 ${ba.usesNonExemptEncryption}，過期 ${ba.expired}`,
  );
}

console.log("== 價格與地區");
const price = await read("價格", `/v1/apps/${app.id}/appPriceSchedule?include=manualPrices`);
show("價格表", price?.data ? `有（手動價格 ${(price.included ?? []).length} 筆）` : null);
const availability = await read("地區", `/v1/apps/${app.id}/appAvailabilityV2`);
show("上架地區設定", availability?.data ? "有" : null);

console.log("== 內購");
const iaps = await read("內購", `/v1/apps/${app.id}/inAppPurchasesV2?limit=200`);
for (const item of iaps?.data ?? []) {
  console.log(`- ${item.attributes.productId} 狀態 ${item.attributes.state}`);
}
console.log("check 模式到這裡，沒有改任何東西");
