#!/usr/bin/env node
// 小人蔘標準答案產生器（片 K2，跟 golden_build.mjs 同一招）。
// 把 .uiux/小人蔘/頭套預覽.html 的 <script id="core"> 原封不動載進沙盒執行，
// 對六個動作取幾個時間點、幾個補間進度，把算出來的數字寫成
// ios/RencanCore/Tests/RencanCoreTests/MascotFixture.swift。
// Swift 測試（MascotTests.swift）拿同樣的動作與時間算一次，逐項比對到小數第 6 位。
//
// 規矩：
//   - 答案只准由這支工具產生，不准手改 MascotFixture.swift。
//   - 重跑這支工具，git status 不該看到 MascotFixture.swift 有變動。
//   - 沙盒裡只改一件事：把 f（四捨五入到小數一位，只為了 SVG 字串短）換成原樣傳回，
//     這樣畫出來的座標才有完整精度可以比。姿勢與座標的算法一行都沒動。
// 用法：node .vibe/tools/mascot_golden.mjs
// 零套件，只用 node 內建模組。
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', '..');
const HTML = path.join(ROOT, '.uiux', '小人蔘', '頭套預覽.html');
const OUT = path.join(ROOT, 'ios', 'RencanCore', 'Tests', 'RencanCoreTests', 'MascotFixture.swift');
const fail = why => { console.error('[mascot_golden] reason: ' + why); process.exit(1); };

const html = fs.readFileSync(HTML, 'utf8');
const found = html.match(/<script id="core">([\s\S]*?)<\/script>/);
if (!found) fail('頭套預覽.html 裡找不到 <script id="core">，預覽頁可能改過結構');
// 補間秒數寫在預覽頁的畫面程式裡（不在 core），這裡只確認它還是 0.28。
const TRANSITION = 0.28;
if (!html.includes('(state.clock-state.switchAt)/' + TRANSITION + ';')) fail('預覽頁換動作的補間秒數不是 ' + TRANSITION + ' 了');

const EXPORTS = 'RIG,basePose,ss,ANIMS,poseAt,blend,renderChar';
const W = vm.runInNewContext(found[1] + '\n;f=function(n){return n;};({' + EXPORTS + '})', { Math });

// ---------- 取樣 ----------
const ACTIONS = ['wave', 'sleep', 'think', 'oops', 'shrug', 'please'];
// 每個動作：0、週期中段、跨過一個週期以後。聳肩多取幾個，舉起、停住、放下、休息、下一輪都要有。
const TIMES = {
  wave: [0, 0.2, 0.7, 3.3],
  sleep: [0, 1.1, 2.24, 9.5],
  think: [0, 1, 1.96, 8.4],
  oops: [0, 0.13, 0.26, 4.1],
  shrug: [0, 0.15, 0.9, 1.7, 2.2, 2.55, 5.7],
  please: [0, 0.22, 0.45, 6.3],
};
// 補間：從哪個動作的哪一刻，到哪個動作的哪一刻，進度多少（0.5 是嘴型換邊的那一點）。
const BLENDS = [
  ['wave', 0.7, 'sleep', 0.1, 0],
  ['wave', 0.7, 'sleep', 0.1, 0.25],
  ['sleep', 1.1, 'wave', 0.2, 0.49],
  ['think', 1, 'oops', 0.13, 0.5],
  ['shrug', 0.9, 'please', 0.22, 0.75],
  ['oops', 0.26, 'think', 1.96, 1],
];
// 換動作後過了幾秒（最後兩個超過 0.28 秒，進度要停在 1）。
const ELAPSED = [0, 0.07, 0.1, 0.14, 0.21, 0.27, 0.28, 0.5];
// 畫出來的座標：每個動作挑一刻，聳肩多一刻（肩膀抬到最高）。
const FIGURES = [['wave', 0.2], ['sleep', 1.1], ['think', 1], ['oops', 0.13], ['shrug', 0], ['shrug', 0.9], ['please', 0.22]];

// ---------- 姿勢 ----------
const JOINTS = ['lS', 'lE', 'rS', 'rE', 'lH', 'lK', 'rH', 'rK'];
const BODY = ['lean', 'head', 'hy', 'sh'];
const FACE = ['eyeH', 'lookX', 'lookY', 'brow', 'browY'];
const MARKS = ['bubble', 'zzz', 'sweat'];
const NUMERIC = [...JOINTS, ...BODY, ...FACE, ...MARKS];
// Swift 版沒搬的欄位：六個動作都沒動到，永遠是這些值。哪天網頁版動到了，這裡會擋下來。
const UNPORTED = { rx: 0, ry: 0, squash: 0, tl: 1, hs: 1, sx: 1, happy: 0 };
const MOUTHS = { smile: 'smile', o: 'o', flat: 'flat', wavy: 'wavy' };

function poseNumbers(pose, where) {
  const known = new Set([...NUMERIC, ...Object.keys(UNPORTED), 'mouth', 't']);
  for (const key of Object.keys(pose)) if (!known.has(key)) fail(where + '：姿勢多了 Swift 版不認得的欄位 ' + key);
  for (const [key, value] of Object.entries(UNPORTED)) {
    if (pose[key] !== value) fail(where + '：' + key + ' 不是 ' + value + ' 了，Swift 版沒搬這個欄位，要補');
  }
  if (!MOUTHS[pose.mouth]) fail(where + '：嘴型 ' + pose.mouth + ' Swift 版沒有');
  return NUMERIC.map(key => pose[key]);
}

// ---------- 從 renderChar 畫出來的 SVG 字串抽座標 ----------
const NUM = /[-+]?(?:\d+\.?\d*|\.\d+)(?:e[-+]?\d+)?/g;
const numbersIn = text => (text.match(NUM) || []).map(Number);
const all = (text, pattern) => [...text.matchAll(pattern)].map(m => m.slice(1));
const same = (a, b) => a[0] === b[0] && a[1] === b[1];

// 把只含 M、L、Q、C、Z 與相對 q、t 的路徑換成絕對座標的數字，另給一串指令字母。
function pathNumbers(d) {
  const out = [];
  let letters = '';
  let cur = [0, 0];
  let lastControl = null;
  for (const [, cmd, rest] of d.matchAll(/([MLQCZqt])([^MLQCZqt]*)/g)) {
    const n = numbersIn(rest);
    const size = { M: 2, L: 2, Q: 4, C: 6, Z: 0, q: 4, t: 2 }[cmd];
    if (cmd === 'Z') { letters += 'Z'; continue; }
    if (n.length === 0 || n.length % size !== 0) fail('看不懂的路徑：' + d);
    for (let i = 0; i < n.length; i += size) {
      let part = n.slice(i, i + size);
      if (cmd === 'q') part = part.map((v, j) => v + cur[j % 2]);
      if (cmd === 't') {
        if (!lastControl) fail('t 前面沒有二次曲線：' + d);
        part = [2 * cur[0] - lastControl[0], 2 * cur[1] - lastControl[1], part[0] + cur[0], part[1] + cur[1]];
      }
      const isQuad = cmd === 'Q' || cmd === 'q' || cmd === 't';
      lastControl = isQuad ? part.slice(0, 2) : null;
      cur = part.slice(-2);
      letters += isQuad ? 'Q' : cmd;
      out.push(...part);
    }
  }
  return { letters, numbers: out };
}

function figureOf(pose, where) {
  const svg = W.renderChar(pose, 'hood');
  const limbs = all(svg, /<line class="limb" x1="([^"]+)" y1="([^"]+)" x2="([^"]+)" y2="([^"]+)"/g).map(l => l.map(Number));
  if (limbs.length !== 11) fail(where + '：身體應該是 11 段線，畫出來 ' + limbs.length + ' 段');
  const chain = (from, count) => {
    const pts = [limbs[from].slice(0, 2)];
    for (let i = from; i < from + count; i++) {
      if (!same(limbs[i].slice(0, 2), pts[pts.length - 1])) fail(where + '：第 ' + i + ' 段線沒接在上一段後面');
      pts.push(limbs[i].slice(2));
    }
    return pts.flat();
  };
  const head = svg.match(/translate\(([^,]+),([^)]+)\) rotate\(([^)]+)\) scale\(1,1\)/);
  const shade = svg.match(/<ellipse class="shade" cx="([^"]+)" cy="([^"]+)"/);
  if (!head || !shade) fail(where + '：找不到頭的位置或影子');
  const body = [...chain(0, 3), ...chain(3, 3), ...chain(6, 1), ...chain(7, 2), ...chain(9, 2), ...head.slice(1).map(Number), ...shade.slice(1).map(Number)];
  const dots = all(svg, /<circle class="mark" cx="([^"]+)" cy="([^"]+)" r="([^"]+)" opacity="([^"]+)"/g).flat().map(Number);
  const letters = all(svg, /<text class="mark" x="([^"]+)" y="([^"]+)"[^>]*font-size="([^"]+)" opacity="([^"]+)"/g).flat().map(Number);
  const eyes = all(svg, /<rect x="([^"]+)" y="([^"]+)" width="([^"]+)" height="([^"]+)" rx="2.3"/g).flat().map(Number);
  const brows = all(svg, /<line x1="([^"]+)" y1="([^"]+)" x2="([^"]+)" y2="([^"]+)" stroke="[^"]+" stroke-width="3.4"/g).flat().map(Number);
  if (eyes.length !== 8 || brows.length !== 8) fail(where + '：眼睛或眉毛的數目不對');
  let mouth;
  if (pose.mouth === 'o') {
    const c = svg.match(/<circle cx="([^"]+)" cy="([^"]+)" r="2.6" fill="none"/);
    if (!c) fail(where + '：找不到圓嘴');
    mouth = { letters: '-', numbers: c.slice(1).map(Number) };
  } else if (pose.mouth === 'flat') {
    const l = svg.match(/<line x1="([^"]+)" y1="([^"]+)" x2="([^"]+)" y2="([^"]+)" stroke="[^"]+" stroke-width="3" /);
    if (!l) fail(where + '：找不到平嘴');
    mouth = { letters: 'ML', numbers: l.slice(1).map(Number) };
  } else {
    const p = svg.match(/<path d="([^"]+)" fill="none" stroke="#3A2A0C" stroke-width="3" stroke-linecap="round"\/>/);
    if (!p) fail(where + '：找不到嘴');
    mouth = pathNumbers(p[1]);
  }
  let sweat = [];
  const drop = svg.match(/<path d="([^"]+)" fill="#6FB7E0" opacity="([^"]+)"\/>/);
  if (drop) sweat = [...pathNumbers(drop[1]).numbers, Number(drop[2])];
  return { body, dots, letters, eyes, brows, mouth, sweat };
}

// ---------- 頭套不會動的部分 ----------
function hoodOf() {
  const svg = W.renderChar(W.basePose(), 'hood');
  const inner = svg.slice(svg.indexOf('scale(1,1)">'), svg.indexOf('</g>'));
  const names = ['whiskerLeft', 'whiskerRight', 'whiskerUpper', 'stem', 'leafLeft', 'leafRight', 'veinLeft', 'veinRight', 'body', 'bodyShine', 'ringTop', 'ringMiddle', 'ringLower'];
  const tags = [...inner.matchAll(/<path d="([^"]+)"([^>]*)\/>/g)].slice(0, names.length);
  if (tags.length !== names.length) fail('頭套的路徑數目不對');
  const attr = (text, name, fallback) => { const m = text.match(new RegExp(' ' + name + '="([^"]+)"')); return m ? Number(m[1]) : fallback; };
  const paths = tags.map((tag, i) => {
    const p = pathNumbers(tag[1]);
    return [names[i], p.letters, attr(tag[2], 'stroke-width', 0), attr(tag[2], 'stroke-opacity', 1), ...p.numbers];
  });
  const berries = all(inner, /<circle cx="([^"]+)" cy="([^"]+)" r="5.4"/g).flat().map(Number);
  const shines = all(inner, /<circle cx="([^"]+)" cy="([^"]+)" r="1.4" fill="#FFFFFF" fill-opacity="([^"]+)"/g).map(s => s.map(Number));
  const faces = all(inner, /<circle cx="0" cy="(-46)" r="(\d+)"/g).map(s => s.map(Number));
  if (berries.length !== 10 || shines.length !== 5 || faces.length !== 2) fail('紅果或白臉的數目不對');
  const outline = Number(inner.match(/r="30"[^>]*stroke-width="([^"]+)"/)[1]);
  // 紅果半徑、亮點相對紅果的位移、亮點半徑、亮點不透明度；白臉圓心 y、外圈半徑、白臉半徑、白臉外框線寬
  const sizes = [5.4, shines[0][0] - berries[0], 1.4, shines[0][2], faces[0][0], faces[0][1], faces[1][1], outline];
  return { paths, berries, sizes };
}

// ---------- 寫成 Swift ----------
const num = n => {
  if (typeof n !== 'number' || !Number.isFinite(n)) fail('答案裡有算不出來的數字');
  const s = n.toFixed(9).replace(/\.?0+$/, '');
  return s === '-0' ? '0' : s;
};
// 一筆紀錄：幾個字加一串數字，折成每行不超過 96 個字，最後用直線 | 收尾。
function record(words, numbers) {
  const tokens = [...words, ...numbers.map(num)];
  const lines = [];
  let cur = '';
  for (const token of tokens) {
    if (cur && (cur + ' ' + token).length > 88) { lines.push(cur); cur = token; } else cur = cur ? cur + ' ' + token : token;
  }
  lines.push(cur + ' |');
  return lines;
}
function block(name, doc, records) {
  const out = doc.map(line => '    /// ' + line);
  out.push('    static let ' + name + ' = """');
  for (const lines of records) for (const line of lines) out.push('        ' + line);
  out.push('        """');
  return out.join('\n');
}

const R = W.RIG;
const poseRecords = [];
for (const action of ACTIONS) {
  for (const t of TIMES[action]) {
    const pose = W.poseAt(action, t);
    if (pose.t !== t) fail(action + ' ' + t + '：姿勢的時間不對');
    poseRecords.push(record([action, MOUTHS[pose.mouth]], [t, ...poseNumbers(pose, action + ' ' + t)]));
  }
}
const base = W.basePose();
const blendRecords = BLENDS.map(([from, fromT, to, toT, k]) => {
  const pose = W.blend(W.poseAt(from, fromT), W.poseAt(to, toT), k);
  if (pose.t !== toT) fail('補間的時間不是目標動作的時間');
  return record([from, to, MOUTHS[pose.mouth]], [fromT, toT, k, ...poseNumbers(pose, '補間 ' + from + '→' + to)]);
});
const figures = FIGURES.map(([action, t]) => ({ action, t, pose: W.poseAt(action, t), ...figureOf(W.poseAt(action, t), action + ' ' + t) }));
const marked = (key, size, what) => {
  const rows = figures.filter(f => f[key].length);
  if (!rows.length || rows.some(f => f[key].length !== size)) fail(what + '的取樣不對');
  return rows.map(f => record([f.action], [f.t, ...f[key]]));
};
const hood = hoodOf();

const parts = [
  block('rig', ['骨架尺寸（網頁版 RIG）：hipX hipY ground thigh shin torso shoulderDrop shoulderHalf upper fore'],
    [record([], [R.hipX, R.hipY, R.ground, R.thigh, R.shin, R.torso, R.shoulderDrop, R.shoulderHalf, R.upper, R.fore])]),
  block('basePose', ['基準姿勢：嘴型，然後 20 個數字（順序同 poses，少了時間）。'], [record([MOUTHS[base.mouth]], poseNumbers(base, '基準姿勢'))]),
  block('poses', [
    '六個動作在各個時間點的姿勢。每筆：動作 嘴型 時間，然後 20 個數字，順序是',
    '左肩 左肘 右肩 右肘 左髖 左膝 右髖 右膝｜前傾 歪頭 頭上下 肩上下｜',
    '眼高 視線x 視線y 眉角度 眉上下｜思考泡泡 Z 汗。',
  ], poseRecords),
  block('blends', ['補間。每筆：起點動作 目標動作 嘴型 起點時間 目標時間 進度，然後 20 個數字（順序同 poses）。'], blendRecords),
  block('transitions', ['換動作後過了幾秒 → 補間進度（慢進慢出）。每筆：秒數 進度。'],
    ELAPSED.map(e => record([], [e, W.ss(0, TRANSITION, e)]))),
  block('figures', [
    '畫出來的身體座標。每筆：動作 時間，然後 37 個數字：左腿四點、右腿四點、身體兩點、',
    '左臂三點、右臂三點（每點 x y）、頭套原點 x y、頭套轉幾度、影子中心 x y。',
  ], figures.map(f => record([f.action], [f.t, ...f.body]))),
  block('faces', ['五官。每筆：動作 時間，然後左眼、右眼（各 x y 寬 高）、左眉、右眉（各兩點 x y）。'],
    figures.map(f => record([f.action], [f.t, ...f.eyes, ...f.brows]))),
  block('mouths', ['嘴。每筆：動作 嘴型 路徑指令（- 是圓嘴，數字是圓心）時間，然後路徑的數字。'],
    figures.map(f => record([f.action, MOUTHS[f.pose.mouth], f.mouth.letters], [f.t, ...f.mouth.numbers]))),
  block('thoughtDots', ['思考泡泡。每筆：動作 時間，然後三個圓點（各 x y 半徑 不透明度）。'], marked('dots', 12, '思考泡泡')),
  block('sleepLetters', ['打瞌睡的 Z。每筆：動作 時間，然後三個 Z（各 x y 字級 不透明度）。'], marked('letters', 12, 'Z')),
  block('sweats', ['汗滴。每筆：動作 時間，然後路徑的 10 個數字與不透明度。'], marked('sweat', 11, '汗滴')),
  block('hoodPaths', ['頭套不會動的路徑，照畫的順序。每筆：名字 路徑指令 線寬（0 是不描邊）不透明度，然後路徑的數字。'],
    hood.paths.map(p => record(p.slice(0, 2), p.slice(2)))),
  block('berries', ['五顆紅果的圓心（各 x y）。'], [record([], hood.berries)]),
  block('hoodSizes', ['紅果半徑、亮點位移、亮點半徑、亮點不透明度、白臉圓心 y、外圈半徑、白臉半徑、白臉外框線寬。'], [record([], hood.sizes)]),
];

const header = [
  '// 小人蔘的標準答案（片 K2）。由 .vibe/tools/mascot_golden.mjs 跑',
  '// .uiux/小人蔘/頭套預覽.html 的 <script id="core"> 產生，不要手改。',
  '// 每一塊是一段文字：一筆紀錄用直線 | 收尾，前面幾個字、後面一串數字，MascotTests 會拆開來比。',
  '',
  'enum MascotFixture {',
].join('\n');
const text = header + '\n' + parts.join('\n\n') + '\n}\n';
const tooLong = text.split('\n').filter(line => [...line].length > 100);
if (tooLong.length) fail('產生的檔有超過 100 字元的行：' + tooLong[0]);
fs.writeFileSync(OUT, text);
console.error('[mascot_golden] reason: 寫好 ' + path.relative(ROOT, OUT) + '，姿勢 ' + poseRecords.length + ' 筆、補間 ' + blendRecords.length + ' 筆、座標 ' + figures.length + ' 筆');
