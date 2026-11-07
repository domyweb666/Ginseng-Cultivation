// AI 自驗用：開一台 Limrun 雲端 iPhone 模擬器、裝最新的模擬器版、截三個分頁的圖存進
// .vibe/evidence/、讀元件樹，然後刪機器（交付圖 d14；每分鐘 2 點，所以硬上限 12 分鐘）。
// 用法：node .vibe/tools/limrun_check.mjs --piece A2 [--asset rencan-sim-123]
// 金鑰：環境變數 LIM_API_KEY，沒有就讀 ~/.lim/config.yaml 的 api-key。
// 模擬器裡只放合成資料，不放真實體組成（安全標準類別 9）。
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import Limrun, { Ios } from "@limrun/api";

const here = dirname(fileURLToPath(import.meta.url));
const evidenceDir = resolve(here, "..", "evidence");

function arg(name, fallback) {
  const index = process.argv.indexOf(`--${name}`);
  return index >= 0 && process.argv[index + 1] ? process.argv[index + 1] : fallback;
}
const piece = arg("piece", "");
if (!piece) {
  console.error("用法：node limrun_check.mjs --piece A2 [--asset rencan-sim-123]");
  process.exit(2);
}

function apiKey() {
  if (process.env.LIM_API_KEY) return process.env.LIM_API_KEY;
  const configPath = join(homedir(), ".lim", "config.yaml");
  if (!existsSync(configPath)) {
    throw new Error("沒有 LIM_API_KEY，也沒有 ~/.lim/config.yaml；見 ios/ci/README.md 第九段");
  }
  const match = readFileSync(configPath, "utf8").match(/api-key:\s*(\S+)/);
  if (!match) throw new Error("~/.lim/config.yaml 裡沒有 api-key");
  return match[1];
}

const lim = new Limrun({ apiKey: apiKey() });
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
const today = new Date().toISOString().slice(0, 10);
mkdirSync(evidenceDir, { recursive: true });

// 挑資產：指定就用指定的，否則拿 rencan-sim- 開頭、建置號最大的那個
async function pickAsset() {
  const wanted = arg("asset", "");
  const result = await lim.assets.list({ platform: "ios" });
  const items = Array.isArray(result) ? result : (result.body ?? result.items ?? result.data ?? []);
  const ours = items.filter((asset) => /^rencan-sim-\d+$/.test(asset.name ?? ""));
  if (wanted) {
    const found = ours.find((asset) => asset.name === wanted);
    if (!found) throw new Error(`Limrun 上沒有資產 ${wanted}`);
    return found;
  }
  if (ours.length === 0) {
    throw new Error("Limrun 上沒有任何 rencan-sim-* 資產；先讓 GitHub Actions 綠一次");
  }
  ours.sort((a, b) => Number(b.name.split("-").pop()) - Number(a.name.split("-").pop()));
  return ours[0];
}

async function saveScreenshot(client, label) {
  const shot = await client.screenshot({ format: "jpeg", size: "scaled" });
  const data = shot.data ?? shot.base64 ?? shot;
  const file = join(evidenceDir, `${piece}-${today}-${label}.jpg`);
  writeFileSync(file, Buffer.from(data, "base64"));
  console.log("截圖：" + file);
}

const asset = await pickAsset();
console.log(`用資產 ${asset.name}`);

let instance = null;
try {
  instance = await lim.iosInstances.create({
    wait: true,
    spec: {
      model: "iphone",
      inactivityTimeout: "5m",
      hardTimeout: "12m",
      initialAssets: [
        { kind: "App", source: "AssetName", assetName: asset.name, launchMode: "RelaunchIfRunning" },
      ],
    },
  });
  console.log(`模擬器 ${instance.metadata.id} 開了（${instance.status?.state}）`);
  const client = await Ios.createInstanceClient({
    apiUrl: instance.status.apiUrl,
    token: instance.status.token,
  });

  // app 由 initialAssets 裝好並啟動；等畫面穩
  await sleep(6000);
  await saveScreenshot(client, "01-境界");

  for (const [index, tab] of [["02", "功法"], ["03", "錄入"]]) {
    await client.tapElement({ AXLabel: tab });
    await sleep(1500);
    await saveScreenshot(client, `${index}-${tab}`);
  }
  await client.tapElement({ AXLabel: "境界" });
  await sleep(1000);

  const tree = await client.elementTreeRaw();
  const treeFile = join(evidenceDir, `${piece}-${today}-element-tree.txt`);
  writeFileSync(treeFile, tree);
  console.log("元件樹：" + treeFile);
} finally {
  if (instance) {
    await lim.iosInstances.delete(instance.metadata.id);
    console.log(`模擬器 ${instance.metadata.id} 已刪`);
  }
}
