// AI 自驗用：把檢查線留下的模擬器版（artifact「rencan-sim-app」）丟上 Limrun 雲端 iPhone 模擬器，
// 親手走一遍主流程、每一步截圖，然後刪機器。Limrun 以分鐘計費，所以：
//   - 不管成敗，finally 一定刪這次開的機器；另設閒置 3 分鐘、最長 12 分鐘自動關。
//   - 結束前列出帳號下帶 project=rencan 標籤、還活著的機器，有就刪掉並印出來。
// 用法：node .vibe/tools/limrun_walk.mjs <rencan-sim.zip> <截圖輸出資料夾> [只走哪幾段]
//   第三個參數不給就走 demo,best,fresh,mascot 四段；給「widget」只走小工具那段（要用 work/widget 的模擬器版）。
// 金鑰：環境變數 LIM_API_KEY，沒有就讀 ~/.lim/config.yaml 的 api-key。模擬器裡只有合成資料。
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";
import Limrun, { Ios } from "@limrun/api";

const [zipPath, outDir, onlyArg] = process.argv.slice(2);
const parts = (onlyArg ?? "demo,best,fresh,mascot").split(",");
if (!zipPath || !outDir) {
  console.error("用法：node limrun_walk.mjs <rencan-sim.zip> <截圖輸出資料夾>");
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
const LABELS = { project: "rencan", by: "ai-walk" };
const lim = new Limrun({ apiKey: apiKey() });
const started = Date.now();
const clock = () => ((Date.now() - started) / 1000).toFixed(1).padStart(6) + "s";
const log = (...parts) => console.log(clock(), ...parts);
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));
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
  try {
    return (await labels()).some((label) => label.includes(text));
  } catch {
    return false;
  }
}
async function waitFor(text, ms = 8000) {
  const end = Date.now() + ms;
  while (Date.now() < end) {
    if (await has(text)) return true;
    await sleep(400);
  }
  return false;
}
async function dump(name) {
  try {
    const all = await labels();
    log(`labels@${name}（${all.length}）:`, JSON.stringify(all.slice(0, 70)));
  } catch (error) {
    log("dump 失敗", error?.message);
  }
}
let shotIndex = 0;
async function shot(name) {
  shotIndex += 1;
  const file = join(outDir, `${String(shotIndex).padStart(2, "0")}-${name}.jpg`);
  try {
    const image = await client.screenshot({ format: "jpeg", size: "scaled" });
    writeFileSync(file, Buffer.from(image.base64 ?? image.data ?? image, "base64"));
    log("截圖", file);
  } catch (error) {
    log("截圖失敗", name, error?.message);
  }
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
/// 找一個節點：任何字串欄位含這段字（identifier 在不同版本的樹裡欄位名不一樣，所以整個比）。
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
/// 手指拖一段：按下、分幾步移動、放開。座標是 points。
async function drag(fromX, fromY, toX, toY, steps = 8) {
  const actions = [{ type: "touchDown", x: fromX, y: fromY }];
  for (let step = 1; step <= steps; step += 1) {
    const ratio = step / steps;
    actions.push({ type: "wait", durationMs: 1 });
    actions.push({
      type: "touchMove",
      x: fromX + (toX - fromX) * ratio,
      y: fromY + (toY - fromY) * ratio,
    });
  }
  actions.push({ type: "wait", durationMs: 120 });
  actions.push({ type: "touchUp", x: toX, y: toY });
  try {
    await client.performActions(actions);
    await sleep(700);
    return true;
  } catch (error) {
    log("拖曳失敗", String(error?.message ?? error).slice(0, 140));
    return false;
  }
}
/// 按住不動一段時間再放開。
async function hold(x, y, ms) {
  try {
    await client.performActions([
      { type: "touchDown", x, y },
      { type: "wait", durationMs: ms },
      { type: "touchUp", x, y },
    ]);
    await sleep(700);
    return true;
  } catch (error) {
    log("按住失敗", String(error?.message ?? error).slice(0, 140));
    return false;
  }
}
const scrollDown = () => drag(screen.width / 2, screen.height * 0.72, screen.width / 2, screen.height * 0.3);
const scrollUp = () => drag(screen.width / 2, screen.height * 0.3, screen.width / 2, screen.height * 0.75);

async function launch(seed, extra = []) {
  try {
    await client.terminateApp(BUNDLE);
  } catch (error) {
    log("關 app 失敗", error?.message);
  }
  await sleep(600);
  const args = ["launch", "booted", BUNDLE, "-rencanUITest"];
  if (seed) args.push("-rencanSeed", seed);
  args.push(...extra);
  try {
    const execution = client.simctl(args);
    if (typeof execution?.wait === "function") await execution.wait();
  } catch (error) {
    log("啟動失敗", error?.message);
  }
  await sleep(3500);
  log("啟動", seed ?? "（全新）");
}

// MARK: 流程

async function walkDemo() {
  await launch("demo");
  check("示範資料：進到境界頁", await waitFor("境界"));
  await dump("境界頁");
  await shot("示範-境界頁");
  await scrollDown();
  await shot("示範-境界頁往下");

  // 按住一列跳出選單（左滑會被三頁左右滑攔掉，2026-11-16 在 Limrun 上實測，所以 app 改成按住）
  const row = (await nodes()).find((node) => /公斤 ×/.test(node.AXLabel ?? "") && node.frame);
  if (row) {
    const { x, y, width, height } = row.frame;
    await hold(x + width / 2, y + height / 2, 900);
    await shot("示範-按住一列之後");
    const sawDelete = await has("刪除");
    check("今天的修煉：按住跳出選單有刪除", sawDelete);
    if (sawDelete) {
      await tap("刪除");
      const sawUndo = await waitFor("復原", 3000);
      await shot("示範-刪除後");
      check("刪除後出現復原", sawUndo);
      if (sawUndo) await tap("復原");
      await shot("示範-復原後");
    } else {
      await dump("按住之後");
      await client.tap(screen.width / 2, screen.height * 0.12);
    }
  } else {
    check("今天的修煉：找到一列", false, "示範資料今天沒有修煉，或標籤不含「公斤 ×」");
  }
  await scrollUp();

  check("到分析頁", (await tap("分析")) && (await waitFor("宗門身分")));
  await shot("示範-分析境界段");
  for (const index of [1, 2, 3]) {
    await scrollDown();
    await shot(`示範-分析境界段往下${index}`);
  }
  await tap("境界怎麼算", { contains: true });
  await shot("示範-境界怎麼算展開");
  for (const index of [1, 2, 3, 4]) await scrollUp();
  // 分段控制的兩段在 Limrun 的元件樹裡沒有標籤，直接點它右半邊的位置（頁標題下面那一列）
  const title = (await nodes())
    .filter((node) => node.AXLabel === "分析" && node.frame)
    .sort((a, b) => a.frame.y - b.frame.y)[0]; // 最上面那個是頁標題，底部那個是分頁列
  const segmentY = title ? title.frame.y + title.frame.height + 34 : screen.height * 0.155;
  await client.tap(screen.width * 0.73, segmentY);
  await sleep(900);
  check("切到功法段", await has("累計修煉"));
  await shot("示範-功法段");
  // 功法卡也沒有標籤可找時，點第一張卡大概的位置
  const card = (await nodes()).find((node) => /坐馬樁/.test(node.AXLabel ?? "") && node.frame);
  if (card) {
    await tapNode(card);
  } else {
    await client.tap(screen.width * 0.27, screen.height * 0.5);
    await sleep(800);
  }
  const opened = await waitFor("關閉", 4000);
  check("點功法卡開單一功法頁", opened);
  if (opened) {
    await shot("示範-單一功法頁");
    await tap("關閉");
  } else {
    await dump("功法段");
  }
  for (const index of [1, 2]) {
    await scrollDown();
    await shot(`示範-功法段往下${index}`);
  }
  for (const index of [1, 2, 3]) await scrollUp();
  await tap("境界");
  check("到設定頁", (await tap("設定")) && (await waitFor("身體")));
  await shot("示範-設定頁");
  for (const index of [1, 2, 3]) {
    await scrollDown();
    await shot(`示範-設定頁往下${index}`);
  }
  for (const index of [1, 2, 3, 4]) await scrollUp();
  await tap("境界");

  try {
    const execution = client.simctl(["ui", "booted", "appearance", "dark"]);
    if (typeof execution?.wait === "function") await execution.wait();
    await sleep(1200);
    await shot("示範-深色境界頁");
    await tap("分析");
    await shot("示範-深色分析頁");
    await tap("境界");
    const back = client.simctl(["ui", "booted", "appearance", "light"]);
    if (typeof back?.wait === "function") await back.wait();
  } catch (error) {
    log("切深色失敗", error?.message);
  }
}

/// 示範資料記一筆破紀錄的坐馬樁（100 加到 102.5 公斤）：要跳「功法精進」的全螢幕慶祝。
/// 第三輪檢查線這一步紅過（按「記下」後 XCUITest 等 app 閒下來等了 17 秒，慶祝 4.5 秒就關了），
/// 所以這裡每隔一小段記一次「離按下多久、元件樹回得多快、慶祝在不在」，看 app 有沒有真的卡住。
async function walkLiftBest() {
  await launch("demo");
  check("破紀錄：進到境界頁", await waitFor("境界"));
  if (!(await tap("記一筆", { contains: true }))) {
    check("破紀錄：開記一筆表單", false, "找不到「記一筆」");
    return;
  }
  await sleep(700);
  const picked = await tap("坐馬樁", { contains: true });
  const added = await tap("重量加 2.5 公斤");
  await shot("破紀錄-表單102點5公斤");
  check("破紀錄：選坐馬樁並加到 102.5 公斤", picked && added, await has("預估 1RM 120") ? "預覽 1RM 120" : "");
  await tap("記下", { wait: 0 });
  const pressed = Date.now();
  let seenAt = null;
  let goneAt = null;
  let label = "";
  let shots = 0;
  while (Date.now() - pressed < 12000) {
    const asked = Date.now();
    const node = await findNode("celebration");
    const answered = Date.now();
    log(`破紀錄 +${asked - pressed}ms 元件樹花 ${answered - asked}ms 慶祝${node ? "在" : "不在"}`);
    if (node && seenAt === null) {
      seenAt = answered - pressed;
      label = node.AXLabel ?? "";
    }
    if (node && shots < 3) {
      shots += 1;
      await shot(`破紀錄-慶祝第${shots}張`);
    }
    if (!node && seenAt !== null && goneAt === null) {
      goneAt = answered - pressed;
      break;
    }
    await sleep(250);
  }
  check("破紀錄：出現慶祝畫面", seenAt !== null, `第一次看到 +${seenAt}ms｜${label}`);
  check("破紀錄：慶祝寫的是功法精進", label.includes("功法精進"), label);
  check("破紀錄：慶祝自己關掉", goneAt !== null, `+${goneAt}ms`);
  await shot("破紀錄-慶祝關掉之後");
  await scrollDown();
  check("破紀錄：今天的修煉有 102.5 公斤那一筆", await has("102.5 公斤"));
  await shot("破紀錄-今天的修煉");
}

async function walkFresh() {
  await launch(null);
  check("全新：看到問身高與性別", await waitFor("開始"));
  await dump("第一次打開");
  await shot("全新-第一次打開");
  await tap("男");
  await shot("全新-選了男");
  await tap("開始");
  check("全新：進到境界頁空狀態", await waitFor("還沒量過體組成"));
  await shot("全新-境界頁空狀態");

  await tap("手動輸入體組成");
  await sleep(800);
  await dump("體組成表單");
  await shot("全新-體組成表單");
  const fields = (await nodes()).filter((node) => /textfield/i.test(node.type ?? "") && node.frame);
  log("文字欄位數", fields.length);
  // typeText 在這台模擬器會被當成注音輸入（打出「ㄢ」），所以直接點畫面上數字鍵盤的鍵
  const values = ["70", "15", "60"];
  for (let index = 0; index < Math.min(fields.length, values.length); index += 1) {
    await tapNode(fields[index], 500);
    for (const digit of values[index]) await tap(digit, { wait: 150 });
    await sleep(300);
  }
  await shot("全新-體組成填好");
  // 鍵盤可能蓋住按鈕：先試直接點，不行就往下拖收鍵盤再點
  if (!(await tap("結算境界", { wait: 0 }))) {
    await drag(screen.width / 2, screen.height * 0.3, screen.width / 2, screen.height * 0.6);
    await tap("結算境界", { wait: 0 });
  }
  // 粒子只在剛出現的那一兩秒，連截三張
  await sleep(250);
  await shot("全新-結算後馬上");
  await shot("全新-結算後再一張");
  const celebration = await findNode("celebration");
  check("第一次量測：出現慶祝畫面", Boolean(celebration), celebration?.AXLabel ?? "");
  await sleep(800);
  await shot("全新-慶祝兩秒左右");
  await client.tap(screen.width / 2, screen.height / 2);
  await sleep(1000);
  await shot("全新-關掉慶祝後的境界碑");
  check("境界碑有 FFMI", await has("FFMI"));

  if (await tap("記一筆", { contains: true })) {
    await sleep(600);
    await dump("記一筆表單");
    await shot("全新-記一筆表單");
    await tap("記下");
    await sleep(1200);
    await shot("全新-記下之後");
    await scrollDown();
    await shot("全新-今天的修煉");
  } else {
    check("開記一筆表單", false, "找不到「記一筆」");
    await dump("境界頁找記一筆");
  }
}

/// 小人蔘：展示畫面（六個動作三種高度），以及沒資料時分析頁兩段的空狀態。
/// 舊版本沒有展示畫面時會照常進 app，截到的就是第一次打開那頁，不算壞。
async function walkMascot() {
  await launch(null, ["-rencanMascotGallery"]);
  await dump("小人蔘展示畫面");
  await shot("小人蔘-展示畫面");
  await scrollDown();
  await shot("小人蔘-展示畫面往下");

  await launch("profile");
  if (await tap("分析")) {
    await sleep(900);
    await shot("空狀態-分析境界段");
    const title = (await nodes())
      .filter((node) => node.AXLabel === "分析" && node.frame)
      .sort((a, b) => a.frame.y - b.frame.y)[0]; // 最上面那個是頁標題，底部那個是分頁列
    const segmentY = title ? title.frame.y + title.frame.height + 34 : screen.height * 0.155;
    await client.tap(screen.width * 0.73, segmentY);
    await sleep(900);
    await shot("空狀態-功法段");
    await scrollDown();
    await shot("空狀態-功法段往下");
  }
}

/// 小工具（組塊 G）：示範資料打開 app 寫好快照，回主畫面，按住空白處、編輯、加入小工具，
/// 看小工具清單裡的預覽與放到主畫面後的樣子。主畫面的按鈕字隨系統語言不同，中英文都試。
/// 每一步都把看到的標籤印出來：這段第一次跑，哪一步點不到看紀錄就知道。
async function pressHome() {
  await client.performActions([
    { type: "buttonDown", button: "home" },
    { type: "wait", durationMs: 80 },
    { type: "buttonUp", button: "home" },
  ]);
  await sleep(1500);
}
async function tapAny(texts) {
  for (const text of texts) {
    if (await tap(text, { contains: true, wait: 1200 })) return true;
  }
  return false;
}
async function walkWidget() {
  await launch("demo");
  check("小工具：示範資料進到境界頁", await waitFor("境界"));
  await sleep(1000);
  await pressHome();
  await shot("小工具-主畫面");
  await dump("主畫面");
  await hold(screen.width / 2, screen.height * 0.62, 1500);
  await shot("小工具-按住空白處之後");
  await dump("按住之後");
  check("小工具：主畫面進編輯模式有編輯鈕", await tapAny(["Edit", "編輯"]));
  await shot("小工具-點編輯之後");
  await dump("點編輯之後");
  check("小工具：點加入小工具", await tapAny(["Add Widget", "加入小工具"]));
  // 清單第一次打開要載入好幾秒（2026-11-16 第一趟 2 秒時還是空的），每 3 秒截一張等它出來
  for (const second of [3, 6, 9, 12]) {
    await sleep(3000);
    await shot(`小工具-小工具清單${second}秒`);
    if (await has("人蔘修煉")) break;
  }
  await dump("小工具清單");
  let found = await tapAny(["人蔘修煉", "Rencan"]);
  for (let index = 0; index < 4 && !found; index += 1) {
    await scrollDown();
    await shot(`小工具-小工具清單往下${index + 1}`);
    found = await tapAny(["人蔘修煉", "Rencan"]);
  }
  check("小工具：清單裡找得到人蔘修煉", found);
  if (!found) return;
  await sleep(1200);
  await shot("小工具-預覽第一種");
  await dump("預覽頁");
  for (const index of [2, 3]) {
    await drag(screen.width * 0.8, screen.height * 0.42, screen.width * 0.2, screen.height * 0.42);
    await shot(`小工具-預覽第${index}種`);
  }
  check("小工具：按加入", await tapAny(["Add Widget", "加入小工具"]));
  await sleep(1200);
  await shot("小工具-加到主畫面");
  await tapAny(["Done", "完成"]);
  await pressHome();
  await shot("小工具-主畫面上的樣子");
  await dump("加完之後的主畫面");
  check("小工具：主畫面上看得到境界", (await has("金丹")) || (await has("境界")));
}

/// 跑一個 simctl 指令，把它印的字收回來。
function simctlOutput(args, ms = 15000) {
  return new Promise((resolve) => {
    const lines = [];
    let done = false;
    const finish = (note) => {
      if (done) return;
      done = true;
      if (note) lines.push(note);
      resolve(lines.join("\n"));
    };
    try {
      const execution = client.simctl(args);
      execution.on("line-stdout", (line) => lines.push(line));
      execution.on("line-stderr", (line) => lines.push("[stderr] " + line));
      execution.on("exit", (code) => finish(`[exit ${code}]`));
      execution.on("error", (error) => finish(`[error ${error?.message}]`));
    } catch (error) {
      finish(`[throw ${error?.message}]`);
    }
    setTimeout(() => finish("[timeout]"), ms);
  });
}

/// 小工具的快照有沒有真的寫進 App Group（片 G1）。雲端模擬器的「加入小工具」清單是空的
/// （2026-11-16 兩趟都是，連系統內建的小工具都沒有），小工具的樣子在這裡看不到，
/// 所以改看資料：示範資料打開 app 之後，App Group 的偏好設定檔裡要有 widgetSnapshot.v1 那一格。
async function walkSnapshot() {
  await launch("demo");
  check("快照：示範資料進到境界頁", await waitFor("境界"));
  await sleep(1500);
  // Limrun 不准用 get_app_container，改用 appinfo：它的 GroupContainers 那段有 App Group 的路徑
  const info = await simctlOutput(["appinfo", "booted", BUNDLE]);
  log("appinfo：", info.slice(0, 2500));
  const match = info.match(/"?group\.org\.domyweb\.rencan"?\s*=\s*"?(?:file:\/\/)?(\/[^";\n]+)/);
  check("快照：主 app 有 App Group 容器", Boolean(match), match ? match[1] : "appinfo 裡沒有 group.org.domyweb.rencan");
  if (!match) return;
  const folder = decodeURIComponent(match[1]).replace(/\/$/, "");
  const plist = `${folder}/Library/Preferences/group.org.domyweb.rencan`;
  const listed = await simctlOutput(["spawn", "booted", "/bin/ls", "-la", `${folder}/Library/Preferences`]);
  log("偏好設定資料夾：", listed);
  const read = await simctlOutput(["spawn", "booted", "defaults", "read", plist]);
  log("defaults read：", read.slice(0, 1500));
  check("快照：App Group 裡有 widgetSnapshot.v1", read.includes("widgetSnapshot.v1") || listed.includes("group.org.domyweb.rencan.plist"));
  // 空狀態的快照是 62 個位元組（只有 weekDays、updatedAtMs、isUnstable）。示範資料有境界與本週天數，
  // 一定比它長。系統把偏好設定寫回磁碟有延遲，所以記一筆之後隔幾秒多讀幾次。
  const sizeOf = (text) => Number(text.match(/length = (\d+)/)?.[1] ?? 0);
  log("快照長度（剛打開）：", sizeOf(read));
  if (await tap("記一筆", { contains: true })) {
    await sleep(700);
    await tap("記下", { wait: 1500 });
  }
  let longest = sizeOf(read);
  for (const second of [2, 5, 9, 14]) {
    await sleep(second === 2 ? 2000 : 3500);
    const again = await simctlOutput(["spawn", "booted", "defaults", "read", plist]);
    log(`快照長度（記一筆後約 ${second} 秒）：`, sizeOf(again), again.slice(0, 220).replace(/\s+/g, " "));
    longest = Math.max(longest, sizeOf(again));
  }
  check("快照：示範資料的快照比空狀態長（有境界與本週天數）", longest > 62, `最長 ${longest} 位元組`);
}

// MARK: 主程式

async function aliveOfOurs() {
  const selector = Object.entries(LABELS)
    .map(([key, value]) => `${key}=${value}`)
    .join(",");
  const listed = await lim.iosInstances.list({ labelSelector: selector });
  const items = Array.isArray(listed) ? listed : (listed.items ?? listed.data ?? listed.body ?? []);
  return items.filter((item) => !item.metadata?.terminatedAt && item.status?.state !== "terminated");
}

try {
  const assetName = `rencan-walk-${Date.now()}.zip`;
  log("上傳", zipPath);
  const asset = await lim.assets.getOrUpload({
    path: zipPath,
    name: assetName,
    platform: "ios",
    kind: "App",
    ttl: "2h",
  });
  log("資產", asset.name);
  log("開機");
  instance = await lim.iosInstances.create({
    wait: true,
    metadata: { labels: LABELS },
    spec: {
      model: "iphone",
      inactivityTimeout: "3m",
      hardTimeout: "12m",
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
  await sleep(3000);
  const root = (await nodes()).find((node) => node.frame?.width > 300 && node.frame?.height > 600);
  if (root) screen = { width: root.frame.width, height: root.frame.height };
  log("螢幕", JSON.stringify(screen));

  if (parts.includes("demo")) await walkDemo();
  if (parts.includes("best")) await walkLiftBest();
  if (parts.includes("fresh")) await walkFresh();
  if (parts.includes("mascot")) await walkMascot();
  if (parts.includes("widget")) await walkWidget();
  if (parts.includes("snapshot")) await walkSnapshot();
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
  try {
    const left = await aliveOfOurs();
    for (const item of left) {
      await lim.iosInstances.delete(item.metadata.id);
      log("補刪殘留的模擬器", item.metadata.id);
    }
    log(`帶 project=rencan 標籤還活著的模擬器：${left.length} 台（已全數刪除）`);
  } catch (error) {
    log("列出殘留模擬器失敗", error?.message);
  }
  const minutes = ((Date.now() - started) / 60000).toFixed(1);
  log(`整趟 ${minutes} 分鐘`);
  console.log("\n結果：");
  for (const result of results) {
    console.log(`  ${result.ok ? "過  " : "沒過"} ${result.name}${result.note ? "｜" + result.note : ""}`);
  }
}
