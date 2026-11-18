// 上架用：在 Limrun 雲端 iPhone 模擬器上拍商品頁截圖的原圖、錄送審影片（多米 2026-11-18：拍照和錄影都用 Limrun）。
// 截圖腳本照 docs/上架文稿.md 第五節；錄影照同一份文稿第四節送審備註的步驟走。
// 模擬器版是檢查線 artifact「rencan-sim-app」（Debug 版，認得 -rencanUITest 等啟動參數）。
// Limrun 以分鐘計費：finally 一定刪這次開的機器，閒置 3 分鐘、最長 20 分鐘自動關。
// 用法：node .vibe/tools/limrun_store.mjs <rencan-sim.zip> <輸出資料夾> [shots,video]
// 金鑰：環境變數 LIM_API_KEY，沒有就讀 ~/.lim/config.yaml 的 api-key。模擬器裡只有合成資料。
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join, resolve } from "node:path";
import Limrun, { Ios } from "@limrun/api";

const [zipPath, outDir, onlyArg] = process.argv.slice(2);
const parts = (onlyArg ?? "shots,video").split(",");
if (!zipPath || !outDir) {
  console.error("用法：node limrun_store.mjs <rencan-sim.zip> <輸出資料夾> [shots,video]");
  process.exit(2);
}
mkdirSync(outDir, { recursive: true });

function apiKey() {
  if (process.env.LIM_API_KEY) return process.env.LIM_API_KEY;
  const configPath = join(homedir(), ".lim", "config.yaml");
  if (!existsSync(configPath)) throw new Error("沒有 LIM_API_KEY，也沒有 ~/.lim/config.yaml");
  const match = readFileSync(configPath, "utf8").match(/api-key:\s*(\S+)/);
  if (!match) throw new Error("~/.lim/config.yaml 裡沒有 api-key");
  return match[1];
}

const BUNDLE = "org.domyweb.rencan";
const LABELS = { project: "rencan", by: "ai-store" };
const lim = new Limrun({ apiKey: apiKey() });
const started = Date.now();
const clock = () => ((Date.now() - started) / 1000).toFixed(1).padStart(6) + "s";
const log = (...items) => console.log(clock(), ...items);
const sleep = (ms) => new Promise((done) => setTimeout(done, ms));
const results = [];
function check(name, ok, note = "") {
  results.push({ name, ok, note });
  log(ok ? "PASS" : "FAIL", name, note);
}

let instance = null;
let client = null;
let screen = { width: 393, height: 852 };

function flatten(node, out = []) {
  if (Array.isArray(node)) {
    for (const item of node) flatten(item, out);
    return out;
  }
  if (!node || typeof node !== "object") return out;
  out.push(node);
  for (const child of node.children ?? []) flatten(child, out);
  return out;
}
const nodes = async () => flatten(await client.elementTree());
const labels = async () => (await nodes()).filter((node) => node.AXLabel).map((node) => node.AXLabel);
async function has(text) {
  return (await labels()).some((label) => label.includes(text));
}
async function waitFor(text, ms = 10000) {
  const end = Date.now() + ms;
  while (Date.now() < end) {
    if (await has(text)) return true;
    await sleep(400);
  }
  return false;
}
async function dump(name) {
  const all = await labels();
  log(`labels@${name}（${all.length}）:`, JSON.stringify(all.slice(0, 80)));
}
/// 原尺寸截圖（size full＝裝置像素），商品頁合成要用。
async function shot(name) {
  const file = join(outDir, `${name}.png`);
  const image = await client.screenshot({ format: "png", size: "full" });
  writeFileSync(file, Buffer.from(image.base64, "base64"));
  log("截圖", file, `${image.width}×${image.height}`);
}
async function tap(text, { contains = false, wait = 700 } = {}) {
  try {
    await client.tapElement(contains ? { AXLabelContains: text } : { AXLabel: text });
    log("點", JSON.stringify(text));
    await sleep(wait);
    return true;
  } catch (error) {
    log("點不到", JSON.stringify(text), String(error?.message ?? error).slice(0, 140));
    return false;
  }
}
async function findNode(text) {
  return (await nodes()).find((node) => {
    const { children, ...rest } = node;
    return JSON.stringify(rest).includes(text);
  });
}
async function tapNode(node, wait = 800) {
  const frame = node?.frame;
  if (!frame) return false;
  await client.tap(frame.x + frame.width / 2, frame.y + frame.height / 2);
  await sleep(wait);
  return true;
}
async function drag(fromX, fromY, toX, toY, steps = 10) {
  const actions = [{ type: "touchDown", x: fromX, y: fromY }];
  for (let step = 1; step <= steps; step += 1) {
    const ratio = step / steps;
    actions.push({ type: "wait", durationMs: 16 });
    actions.push({ type: "touchMove", x: fromX + (toX - fromX) * ratio, y: fromY + (toY - fromY) * ratio });
  }
  actions.push({ type: "wait", durationMs: 150 });
  actions.push({ type: "touchUp", x: toX, y: toY });
  await client.performActions(actions);
  await sleep(800);
}
/// 往下捲 fraction 個螢幕高（0.4 大約捲 40%）。
const scrollBy = (fraction) =>
  drag(screen.width / 2, screen.height * (0.5 + fraction / 2), screen.width / 2, screen.height * (0.5 - fraction / 2));

async function simctl(args) {
  const execution = client.simctl(args);
  if (typeof execution?.wait === "function") await execution.wait();
}

async function launch(seed, extra = []) {
  try {
    await client.terminateApp(BUNDLE);
  } catch (error) {
    log("關 app（可能本來就沒開）", String(error?.message ?? error).slice(0, 80));
  }
  await sleep(600);
  const args = ["launch", "booted", BUNDLE, "-rencanUITest"];
  if (seed) args.push("-rencanSeed", seed);
  args.push(...extra);
  await simctl(args);
  await sleep(3500);
  log("啟動", seed ?? "（全新）", extra.join(" "));
}

/// 數字欄：點欄位，再一顆一顆點畫面上的數字鍵（typeText 在這台模擬器會變注音）。
async function typeDigits(field, digits) {
  await tapNode(field, 500);
  for (const digit of digits) await tap(digit, { wait: 150 });
  await sleep(300);
}

/// 量體組成：手動輸入 → 三欄 → 結算境界。回傳有沒有出慶祝畫面。
async function measure(values) {
  if (!(await tap("手動輸入體組成", { contains: true }))) await tap("手動輸入", { contains: true });
  await sleep(900);
  const fields = (await nodes()).filter((node) => /textfield/i.test(node.type ?? "") && node.frame);
  log("文字欄位數", fields.length);
  for (let index = 0; index < Math.min(fields.length, values.length); index += 1) {
    await typeDigits(fields[index], values[index]);
  }
  if (!(await tap("結算境界", { wait: 0 }))) {
    await drag(screen.width / 2, screen.height * 0.3, screen.width / 2, screen.height * 0.6);
    await tap("結算境界", { wait: 0 });
  }
  const end = Date.now() + 6000;
  while (Date.now() < end) {
    if (await findNode("celebration")) return true;
    await sleep(250);
  }
  return false;
}

// MARK: 商品頁截圖（docs/上架文稿.md 第五節；第 4 張要另做 seed、第 9 張小工具要真機，這次不拍）

async function shots() {
  await simctl(["status_bar", "booted", "override", "--time", "9:41", "--batteryState", "charged",
    "--batteryLevel", "100", "--wifiBars", "3", "--cellularBars", "4"]);

  await launch("demo");
  check("1 境界頁", await waitFor("FFMI"));
  await shot("1-realm");
  await scrollBy(0.45);
  await shot("3-next-stage");

  await launch("profile", ["-rencanHoldCelebration"]);
  await waitFor("還沒量過", 10000);
  const celebrated = await measure(["70", "15", "60"]);
  check("2 第一次量測出慶祝", celebrated);
  await sleep(1100);
  await shot("2-celebration");

  await launch("unstable");
  await waitFor("FFMI");
  await scrollBy(0.3);
  check("5 根基不穩", await has("根基不穩"));
  await shot("5-unstable");

  await launch("demo");
  await waitFor("FFMI");
  if (await tap("記一筆", { contains: true })) {
    await sleep(800);
    await tap("坐馬樁", { contains: true });
    await sleep(600);
    await dump("記一筆表單");
    await shot("6-log-lift");
    await tap("取消");
  } else {
    check("6 開記一筆表單", false);
  }

  await launch("demo");
  await waitFor("FFMI");
  await tap("分析");
  await sleep(1000);
  const title = (await nodes())
    .filter((node) => node.AXLabel === "分析" && node.frame)
    .sort((a, b) => a.frame.y - b.frame.y)[0];
  const segmentY = title ? title.frame.y + title.frame.height + 34 : screen.height * 0.155;
  await client.tap(screen.width * 0.73, segmentY);
  await sleep(1000);
  check("7 功法段", await has("累計修煉"));
  await scrollBy(0.25);
  await shot("7-moves");

  await shotData();

  await launch("demo", ["-rencanOwn", "all", "-rencanStyle", "celadon"]);
  await waitFor("FFMI");
  await shot("10b-realm-celadon");
  await tap("設定");
  await sleep(1000);
  const row = await findNode("settings-portrait-style");
  if (row) await tapNode(row, 1200);
  else await tap("目前的造型", { contains: true, wait: 1200 });
  check("10 選造型頁", await has("青花瓷"));
  await shot("10-styles");
}

/// 第 8 張：設定頁的資料區。捲到「資料」標題貼近頂端，上面的健康 app 區（測試模式會寫「這台裝置沒有健康 app」）不入鏡。
async function shotData() {
  await launch("demo");
  await waitFor("FFMI");
  await tap("設定");
  await sleep(1000);
  for (let index = 0; index < 8; index += 1) {
    const header = (await nodes()).find((node) => node.AXLabel === "資料" && node.frame);
    if (header && header.frame.y < screen.height * 0.22) break;
    await scrollBy(0.15);
  }
  check("8 資料區", await has("匯出"));
  check("8 沒有健康 app 那句", !(await has("沒有健康 app")));
  await shot("8-data");
}

// MARK: 送審錄影（docs/上架文稿.md 第四節的步驟）

async function video() {
  await simctl(["status_bar", "booted", "override", "--time", "9:41", "--batteryState", "charged",
    "--batteryLevel", "100", "--wifiBars", "3", "--cellularBars", "4"]);
  await launch(null);
  await waitFor("開始", 10000);
  await client.startRecording({ quality: 7 });
  log("開始錄影");
  await sleep(1500);

  // 第一次打開：身高（預設值）、男、開始
  await dump("第一次打開");
  await tap("男");
  await sleep(800);
  await tap("開始");
  check("錄影：進到境界頁", await waitFor("還沒量過", 8000));
  await sleep(1500);

  // 手動輸入體組成 70／15／60 → 結算 → 慶祝
  const celebrated = await measure(["70", "15", "60"]);
  check("錄影：出慶祝", celebrated);
  await sleep(5500);
  if (await findNode("celebration")) await client.tap(screen.width / 2, screen.height / 2);
  await sleep(1500);
  await scrollBy(0.4);
  await sleep(1200);
  await scrollBy(-0.4);
  await sleep(800);

  // 記一筆修煉：坐馬樁 → 重量加兩次 → 記下
  if (await tap("記一筆", { contains: true })) {
    await sleep(1000);
    await tap("坐馬樁", { contains: true, wait: 900 });
    await tap("重量加 2.5 公斤", { wait: 500 });
    await tap("重量加 2.5 公斤", { wait: 900 });
    await tap("記下", { wait: 2500 });
    if (await findNode("celebration")) {
      await sleep(3000);
      await client.tap(screen.width / 2, screen.height / 2);
    }
    await sleep(1500);
  }

  // 分析頁兩段
  await tap("分析");
  await sleep(2000);
  await scrollBy(0.4);
  await sleep(1500);
  await scrollBy(-0.4);
  const title = (await nodes())
    .filter((node) => node.AXLabel === "分析" && node.frame)
    .sort((a, b) => a.frame.y - b.frame.y)[0];
  const segmentY = title ? title.frame.y + title.frame.height + 34 : screen.height * 0.155;
  await client.tap(screen.width * 0.73, segmentY);
  await sleep(2000);
  await scrollBy(0.4);
  await sleep(1500);

  // 設定 → 立繪造型 → 點有鎖的 → 購買 → 恢復購買
  await tap("設定");
  await sleep(1500);
  const row = await findNode("settings-portrait-style");
  if (row) await tapNode(row, 1800);
  else await tap("目前的造型", { contains: true, wait: 1800 });
  await tap("青花瓷", { contains: true, wait: 2000 });
  check("錄影：購買鍵出現", await has("購買"));
  await tap("購買「", { contains: true, wait: 2500 });
  await tap("恢復購買", { wait: 2500 });
  await tap("完成", { wait: 1500 });
  await tap("境界");
  await sleep(3000);

  const file = resolve(outDir, "review.mp4");
  const url = await client.stopRecording({ localPath: file });
  log("錄影存好", file, url ? "（也有下載網址）" : "");
  check("錄影檔存在", existsSync(file));
}

async function aliveOfOurs() {
  const selector = Object.entries(LABELS).map(([key, value]) => `${key}=${value}`).join(",");
  const listed = await lim.iosInstances.list({ labelSelector: selector });
  const items = Array.isArray(listed) ? listed : (listed.items ?? listed.data ?? listed.body ?? []);
  return items.filter((item) => !item.metadata?.terminatedAt && item.status?.state !== "terminated");
}

try {
  const asset = await lim.assets.getOrUpload({
    path: zipPath,
    name: `rencan-store-${Date.now()}.zip`,
    platform: "ios",
    kind: "App",
    ttl: "2h",
  });
  log("資產", asset.name);
  instance = await lim.iosInstances.create({
    wait: true,
    metadata: { labels: LABELS },
    spec: {
      model: "iphone",
      inactivityTimeout: "3m",
      hardTimeout: "20m",
      initialAssets: [
        { kind: "App", source: "AssetName", assetName: asset.name, launchMode: "RelaunchIfRunning" },
      ],
    },
  });
  log("模擬器", instance.metadata?.id, instance.status?.state);
  client = await Ios.createInstanceClient({
    apiUrl: instance.status.apiUrl,
    token: instance.status.token,
    logLevel: "none",
  });
  log("裝置", JSON.stringify(client.deviceInfo ?? {}));
  await sleep(3000);
  const root = (await nodes()).find((node) => node.frame?.width > 300 && node.frame?.height > 600);
  if (root) screen = { width: root.frame.width, height: root.frame.height };
  log("螢幕", JSON.stringify(screen));
  if (parts.includes("shots")) await shots();
  if (parts.includes("video")) await video();
  if (parts.includes("data")) {
    await simctl(["status_bar", "booted", "override", "--time", "9:41", "--batteryState", "charged",
      "--batteryLevel", "100", "--wifiBars", "3", "--cellularBars", "4"]);
    await shotData();
  }
} catch (error) {
  log("中斷：", error?.stack ?? String(error));
  check("整趟跑完", false, String(error?.message ?? error).slice(0, 200));
} finally {
  if (instance) {
    try {
      await lim.iosInstances.delete(instance.metadata.id);
      log("模擬器已刪", instance.metadata.id);
    } catch (error) {
      log("刪模擬器失敗，請到 console.limrun.com 手動刪：", instance.metadata?.id, error?.message);
    }
  }
  const left = await aliveOfOurs();
  for (const item of left) {
    await lim.iosInstances.delete(item.metadata.id);
    log("補刪殘留的模擬器", item.metadata.id);
  }
  log(`帶 by=ai-store 標籤還活著的模擬器：${left.length} 台（已全數刪除）`);
  log(`整趟 ${((Date.now() - started) / 60000).toFixed(1)} 分鐘`);
  console.log("\n結果：");
  for (const result of results) {
    console.log(`  ${result.ok ? "過  " : "沒過"} ${result.name}${result.note ? "｜" + result.note : ""}`);
  }
}
