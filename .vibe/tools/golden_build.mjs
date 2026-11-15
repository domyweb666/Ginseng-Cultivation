#!/usr/bin/env node
// 黃金集產生器（片 B2）。
// 把 index.html 裡「規則」到「畫面」之間那段原版程式原封不動載進沙盒，
// 對幾組假資料算出標準答案，寫成 ios/RencanCore/Tests/RencanCoreTests/Fixtures/web-export.json。
// Swift 測試（GoldenTests.swift）拿同一份假資料算一次，逐項比對。
//
// 規矩（.vibe/標準清單.md 片 B2）：
//   - 答案只准由這支工具產生，不准手改那個 JSON。
//   - 假資料全部是編的，不准放真實紀錄（repo 公開）。
//   - 重跑這支工具，git status 不該看到 Fixtures 有任何變動。
// 用法：node .vibe/tools/golden_build.mjs
// 零套件，只用 node 內建模組。
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const INDEX = path.join(ROOT, 'index.html');
const OUT = path.join(ROOT, 'ios', 'RencanCore', 'Tests', 'RencanCoreTests', 'Fixtures', 'web-export.json');
const START = '/* ---------- 規則 ---------- */';
const END = '/* ---------- 畫面 ---------- */';
// 每組假資料的「今天」。固定下來，本週修煉天數才不會隔天就變。
const TODAY = '2026-03-11';

const html = fs.readFileSync(INDEX, 'utf8');
const from = html.indexOf(START);
const until = html.indexOf(END);
if (from < 0 || until < 0 || until < from) {
  console.error('[golden_build] reason: index.html 裡找不到「規則」到「畫面」那一段，網頁版可能改過結構');
  process.exit(1);
}
const RULES = html.slice(from, until);
const EXPORTS = 'REALMS,STAGES,MOVES,LV,RANKS,leanOf,daysBetween,durTxt,sectOf,realmMax,ffmi,leanFor,realmOf,moveLevel,state,byDate,liftCalc,bestByMove,trainDays,breakthroughs,weekCount,today';

// 每組開一個新的沙盒，state 互不干擾。Date 換成「現在永遠是 today 中午」的版本。
function loadWeb(today) {
  const [y, m, d] = today.split('-').map(Number);
  const noon = new Date(y, m - 1, d, 12, 0, 0).getTime();
  class FixedDate extends Date {
    constructor(...args) { if (args.length === 0) super(noon); else super(...args); }
  }
  return vm.runInNewContext(RULES + '\n;({' + EXPORTS + '})', { Date: FixedDate, Math, JSON, Set, String, Object, Number });
}

// ---------- 假資料 ----------
let clock = 1760000000000;
const tick = () => (clock += 60000);
const meas = (date, weight, bf, lean) => {
  const m = { id: date, date, weight, bf };
  if (lean != null) m.lean = lean;
  m.t = tick();
  return m;
};
const lift = (date, move, kg, reps, sets, bw = null) => {
  const t = tick();
  return { id: 'l' + t, date, move, kg, reps, sets, bw, t };
};
const addDays = (date, n) => new Date(Date.parse(date + 'T00:00:00Z') + n * 864e5).toISOString().slice(0, 10);
// 從某一天起每隔 step 天練一次，輪流練六門功法，重量慢慢加。
const routine = (start, count, step, bw = null) => {
  const moves = ['squat', 'bench', 'dead', 'ohp', 'row', 'pull'];
  const base = { squat: 60, bench: 40, dead: 80, ohp: 25, row: 40, pull: 0 };
  const out = [];
  for (let i = 0; i < count; i++) {
    const move = moves[i % moves.length];
    const kg = base[move] + Math.floor(i / moves.length) * (move === 'pull' ? 1 : 2.5);
    out.push(lift(addDays(start, i * step), move, kg, 3 + (i % 6), 3, bw));
  }
  return out;
};

const GROUPS = [
  { name: '空的：什麼都還沒記', height: 174, meas: [], lift: [] },
  {
    name: '新手：體脂 24% 根基不穩，練了三天',
    height: 174,
    meas: [meas('2026-03-01', 82, 24)],
    lift: [lift('2026-03-02', 'squat', 60, 5, 3), lift('2026-03-04', 'bench', 40, 8, 3), lift('2026-03-09', 'row', 45, 10, 3), lift('2026-03-09', 'squat', 62.5, 5, 3)],
  },
  {
    name: '穩定進步半年：金丹初期到中期，中間一次體脂超標',
    height: 174,
    meas: [
      meas('2025-09-06', 70, 16.5), meas('2025-10-04', 70.6, 16), meas('2025-11-01', 72.5, 21.4), meas('2025-12-06', 71.2, 15.1, 60.6),
      meas('2026-01-03', 71, 14.6), meas('2026-02-07', 70.8, 14.9), meas('2026-03-07', 70.4, 14.2),
    ],
    lift: [...routine('2025-09-08', 45, 4), lift('2026-03-09', 'squat', 110, 3, 3), lift('2026-03-09', 'pull', 5, 6, 3), lift('2026-03-10', 'dead', 140, 1, 1)],
  },
  {
    name: '補登：先記了三月，再回頭補一月更高的那筆；也有量測之前的修煉',
    height: 178,
    meas: [meas('2026-03-01', 74, 15), meas('2026-01-10', 76, 13, 66.4), meas('2026-02-01', 75, 19.9), meas('2025-12-01', 77, 20), meas('2025-11-01', 78, 20.1)],
    lift: [lift('2025-10-15', 'squat', 100, 5, 3), lift('2026-01-12', 'squat', 100, 5, 3), lift('2026-03-02', 'squat', 100, 5, 3), lift('2026-03-02', 'bench', 75, 5, 3, 73.2)],
  },
  {
    name: '客卿長老：元嬰以上的身體，只練了 10 天',
    height: 180,
    meas: [meas('2026-02-20', 88, 12, 76.5)],
    lift: routine('2026-02-21', 10, 1),
  },
  {
    name: '客卿：金丹的身體，只練了 12 天',
    height: 172,
    meas: [meas('2026-02-10', 68, 14)],
    lift: routine('2026-02-12', 12, 2, 68.3),
  },
  {
    name: '執事：練了 130 天，境界停在築基',
    height: 170,
    meas: [meas('2025-08-01', 60, 17), meas('2026-01-05', 61, 16.2)],
    lift: routine('2025-08-02', 130, 1),
  },
  {
    name: '太上長老：練了 320 天，渡劫後期（FFMI 超過 27）',
    height: 168,
    meas: [meas('2024-06-01', 78, 12), meas('2025-01-01', 82, 11, 73.4), meas('2026-03-01', 88, 10, 79.6)],
    lift: routine('2024-06-02', 320, 2),
  },
  {
    name: '低於煉氣：FFMI 不到 16.5，身高 190',
    height: 190,
    meas: [meas('2026-03-03', 62, 12)],
    lift: [lift('2026-03-08', 'pull', 0, 1, 1), lift('2026-03-11', 'ohp', 20, 12, 2)],
  },
  {
    name: '引體向上加重、體重快照跟量測不一樣、同一門功法比值一樣',
    height: 165.5,
    meas: [meas('2026-01-01', 66.6, 18), meas('2026-03-01', 64.2, 15.5)],
    lift: [
      lift('2026-02-01', 'pull', 0, 8, 3, 66), lift('2026-02-08', 'pull', 7.5, 5, 3, 65.5), lift('2026-03-05', 'pull', 10, 1, 1),
      lift('2026-03-05', 'bench', 64.2, 1, 1), lift('2026-03-06', 'bench', 64.2, 1, 2), lift('2026-03-07', 'squat', 0, 20, 1),
    ],
  },
];

// ---------- 用原版程式算答案 ----------
function answer(group) {
  const W = loadWeb(TODAY);
  W.state.meas = group.meas.map(m => ({ ...m }));
  W.state.lift = group.lift.map(l => ({ ...l }));
  W.state.cfg = { height: group.height };
  const H = group.height;
  const calc = l => {
    const c = W.liftCalc(l);
    return { id: l.id, e1rm: c.e, ratio: c.ratio, bodyweight: c.bw, level: W.moveLevel(c.m, c.ratio) };
  };
  const measurements = [...W.byDate(W.state.meas)].map(m => {
    const lean = W.leanOf(m);
    const f = W.ffmi(lean, H);
    const R = W.realmOf(f);
    const row = { date: m.date, lean, ffmi: f, realmIndex: R.i, stageIndex: R.s, label: R.r.n + W.STAGES[R.s], nextFFMI: R.nextF, fromFFMI: R.fromF, nextLabel: null, leanNeeded: null };
    // 網頁版境界碑「距下一期還差肌肉」那三行（renderRealm）
    if (R.nextF != null) {
      const nr = W.realmOf(R.nextF + 0.001);
      row.nextLabel = nr.r.n + W.STAGES[nr.s];
      row.leanNeeded = Math.max(0, W.leanFor(R.nextF, H) - lean);
    }
    return row;
  });
  const best = W.bestByMove();
  const days = W.trainDays();
  const realmMax = W.realmMax(H);
  const S = W.sectOf(days, realmMax);
  return {
    measurements,
    breakthroughs: [...W.breakthroughs(H)].map(b => ({ date: b.date, stageRank: b.idx, label: b.label, first: b.first, days: b.days })),
    realmMax,
    trainDays: days,
    weekCount: W.weekCount(),
    sect: { rankIndex: S.ri, title: S.title, note: S.note, next: S.next, percent: S.pct },
    lifts: W.state.lift.map(calc),
    best: W.MOVES.filter(m => best[m.k]).map(m => ({ move: m.k, ...calc(best[m.k].l) })),
  };
}

const W = loadWeb(TODAY);
// 沒量過體重的修煉，網頁版會用 65 公斤硬算，iOS 版刻意不算；這種情況不放進黃金集，另有專門的測試。
for (const g of GROUPS) {
  if (g.lift.length && !g.meas.length && g.lift.some(l => !l.bw)) {
    console.error('[golden_build] reason: 「' + g.name + '」有修煉卻沒有任何體重，這種情況兩邊本來就不一樣，不能放進黃金集');
    process.exit(1);
  }
}
const ladder = [];
for (let i = 150; i <= 280; i++) {
  const f = i / 10;
  const R = W.realmOf(f);
  ladder.push({ ffmi: f, label: R.r.n + W.STAGES[R.s], nextFFMI: R.nextF, fromFFMI: R.fromF });
}
const sectGrid = [];
for (const days of [0, 5, 7, 8, 23, 24, 49, 50, 99, 100, 149, 150, 299, 300, 400]) {
  for (let realm = -1; realm <= 6; realm++) {
    const S = W.sectOf(days, realm);
    sectGrid.push({ days, realmIndex: realm, rankIndex: S.ri, title: S.title, note: S.note, next: S.next, percent: S.pct });
  }
}
const durations = [0, 1, 30, 59, 60, 74, 75, 104, 105, 200, 364, 365, 379, 380, 400, 729, 730, 800, 1094, 1095, 2000].map(days => ({ days, text: W.durTxt(days) }));
const dayGaps = [['2024-02-28', '2024-03-01'], ['2025-02-28', '2025-03-01'], ['2025-12-31', '2026-01-01'], ['2026-03-01', '2026-01-01'], ['2000-01-01', '2026-03-11'], ['2026-03-11', '2026-03-11']]
  .map(([a, b]) => ({ from: a, until: b, days: W.daysBetween(a, b) }));

const fixture = {
  about: '黃金集：假資料加上網頁版 index.html 原版程式算出來的答案。由 .vibe/tools/golden_build.mjs 產生，不要手改。',
  today: TODAY,
  groups: GROUPS.map(g => ({ name: g.name, export: { meas: g.meas, lift: g.lift, cfg: { height: g.height } }, expected: answer(g) })),
  ladder,
  sectGrid,
  durations,
  dayGaps,
};

// 答案裡不准有 NaN、Infinity（JSON 會悄悄變成 null），有就是假資料或原版程式出了狀況。
const bad = [];
(function scan(v, where) {
  if (typeof v === 'number' && !Number.isFinite(v)) bad.push(where);
  else if (Array.isArray(v)) v.forEach((x, i) => scan(x, where + '[' + i + ']'));
  else if (v && typeof v === 'object') for (const k of Object.keys(v)) scan(v[k], where + '.' + k);
})(fixture, 'fixture');
if (bad.length) {
  console.error('[golden_build] reason: 答案裡有算不出來的數字：' + bad.slice(0, 5).join('、'));
  process.exit(1);
}

fs.mkdirSync(path.dirname(OUT), { recursive: true });
fs.writeFileSync(OUT, JSON.stringify(fixture, null, 2) + '\n');
console.error('[golden_build] reason: 寫好 ' + path.relative(ROOT, OUT) + '，' + fixture.groups.length + ' 組假資料');
