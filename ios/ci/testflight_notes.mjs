// 等 App Store Connect 把剛上傳的建置處理完，然後填 TestFlight 的「測試內容」說明
// （標準清單 A2：使用者在 TestFlight 要看到「骨架版：三個空頁」那一行，知道空殼不是壞掉）。
// API 的簽章與呼叫在 asc_api.mjs，零套件。
// 用法（環境變數）：ASC_KEY_ID、ASC_ISSUER_ID、ASC_KEY_P8_PATH、BUNDLE_ID、BUILD_NUMBER、TESTFLIGHT_NOTES
import { ascClient, env } from "./asc_api.mjs";

const call = ascClient();
const bundleId = env("BUNDLE_ID");
const buildNumber = env("BUILD_NUMBER");
const notes = env("TESTFLIGHT_NOTES");

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

const apps = await call("GET", `/v1/apps?filter[bundleId]=${encodeURIComponent(bundleId)}`);
const app = apps.data[0];
if (!app) {
  throw new Error(`App Store Connect 找不到 bundle id ${bundleId} 的 app；先照 README 第六段建 app 記錄`);
}

// Apple 處理一個建置通常 5 到 15 分鐘；最多等 30 分鐘
const pollEveryMs = 60 * 1000;
const maxPolls = 30;
let build = null;
for (let attempt = 1; attempt <= maxPolls; attempt += 1) {
  const result = await call(
    "GET",
    `/v1/builds?filter[app]=${app.id}&filter[version]=${encodeURIComponent(buildNumber)}` +
      "&sort=-uploadedDate&limit=1",
  );
  build = result.data[0] ?? null;
  const state = build?.attributes?.processingState;
  console.log(`第 ${attempt} 次查：build ${buildNumber} 狀態 ${state ?? "還沒出現"}`);
  if (state === "VALID") break;
  if (state === "FAILED" || state === "INVALID") {
    throw new Error(`Apple 把 build ${buildNumber} 標成 ${state}，到 App Store Connect 看原因`);
  }
  if (attempt === maxPolls) {
    throw new Error(`等了 ${maxPolls} 分鐘 build ${buildNumber} 還沒處理完，下次再跑一次這個 job`);
  }
  await sleep(pollEveryMs);
}

const existing = await call("GET", `/v1/builds/${build.id}/betaBuildLocalizations`);
const current = existing.data[0];
if (current) {
  await call("PATCH", `/v1/betaBuildLocalizations/${current.id}`, {
    data: { type: "betaBuildLocalizations", id: current.id, attributes: { whatsNew: notes } },
  });
  console.log(`已更新 build ${buildNumber} 的測試說明（${current.attributes.locale}）`);
} else {
  await call("POST", "/v1/betaBuildLocalizations", {
    data: {
      type: "betaBuildLocalizations",
      attributes: { locale: "zh-Hant", whatsNew: notes },
      relationships: { build: { data: { type: "builds", id: build.id } } },
    },
  });
  console.log(`已寫入 build ${buildNumber} 的測試說明（zh-Hant）`);
}
