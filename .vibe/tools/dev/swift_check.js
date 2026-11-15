// 本機（Windows）沒有 swift-format／SwiftLint，推上去之前先用文字層檢查抓最常見的紅燈原因。
// 用法：node .vibe/tools/dev/swift_check.js ios/RencanCore   或   ios/Rencan
// 它只是粗篩（行長、禁用寫法、變數名長度、函式與型別長度、括號平衡），真正的檢查在 GitHub Actions。
const fs = require('fs'), path = require('path');
const root = process.argv[2] || 'ios/RencanCore';
const files = [];
(function walk(d) {
  for (const f of fs.readdirSync(d, { withFileTypes: true })) {
    if (f.name === '.build') continue;
    const p = path.join(d, f.name);
    if (f.isDirectory()) walk(p); else if (p.endsWith('.swift')) files.push(p);
  }
})(root);
const width = l => [...l].reduce((n, c) => n + (c.codePointAt(0) > 0x2E7F ? 2 : 1), 0);
const stripStrings = l => l.replace(/"(\\.|[^"\\])*"/g, '""');
let bad = 0;
const say = (f, i, m) => { bad++; console.log(f + ':' + (i + 1) + '  ' + m); };
const bodyLines = (lines, from) => {
  let j = from; while (j < lines.length && !lines[j].includes('{')) j++;
  if (j >= lines.length) return 0;
  let d = 0, k = j;
  do { const s = stripStrings(lines[k]); d += (s.match(/\{/g) || []).length - (s.match(/\}/g) || []).length; k++; } while (d > 0 && k < lines.length);
  return lines.slice(j + 1, k - 1).filter(x => x.trim() !== '' && !x.trim().startsWith('//')).length;
};
let totalTests = 0;
for (const f of files) {
  const src = fs.readFileSync(f, 'utf8'); const lines = src.split('\n');
  if (!src.endsWith('\n')) say(f, lines.length - 1, '檔尾沒有換行');
  if (src.endsWith('\n\n')) say(f, lines.length - 1, '檔尾多一個空行');
  if (src.includes('\r')) say(f, 0, '有 CR');
  if (lines.length - 1 > 400) say(f, 0, '檔案超過 400 行：' + (lines.length - 1));
  let blank = 0;
  lines.forEach((l, i) => {
    const t = l.trim(); const isComment = t.startsWith('//');
    if (/\s+$/.test(l)) say(f, i, '行尾空白');
    if (l.includes('\t')) say(f, i, 'tab');
    if (t === '') { blank++; if (blank > 1) say(f, i, '連續空行'); } else blank = 0;
    const chars = [...l].length;
    if (chars > 100) say(f, i, '超過 100 字元：' + chars);
    else if (!isComment && width(l) > 100) say(f, i, '全形當 2 欄會超過 100：' + width(l));
    if (isComment) return;
    const code = stripStrings(l);
    if (/\btry[?!]/.test(code)) say(f, i, 'try? 或 try!');
    if (/[A-Za-z0-9_\)\]]!(?!=)/.test(code)) say(f, i, '疑似強制解包 !');
    if (/\bas!/.test(code)) say(f, i, 'as!');
    if (/\bprint\s*\(/.test(code) && !f.includes('Tests')) say(f, i, 'print');
    if (/\.forEach\b/.test(code)) say(f, i, 'forEach');
    if (/;\s*$/.test(t)) say(f, i, '分號');
    const v = code.match(/\b(?:let|var)\s+([A-Za-z][A-Za-z0-9]*)\b/);
    if (v && v[1].length < 3 && !['id', 'kg', 'x', 'y', 'i'].includes(v[1])) say(f, i, '變數名太短：' + v[1]);
    if (/[=(,:]\s*\[\s*$/.test(code) || /^\s*\[\s*$/.test(code)) say(f, i, '多行陣列（swift-format 要尾逗號、SwiftLint 不准尾逗號）');
    const m = t.match(/func\s+(test[^\s(]+)/);
    if (m) { totalTests++; if ([...m[1]].length > 40) say(f, i, '測試名超過 40 字：' + [...m[1]].length); }
    if (/\S\s+\/\/ /.test(code)) say(f, i, '行尾註解');
    if (/\bfunc\b|\binit\(/.test(code)) { const n = bodyLines(lines, i); if (n > 40) say(f, i, '函式本體 ' + n + ' 行（上限 40）'); }
    if (/^(public |final |private )*(class|struct|enum|extension) /.test(l)) { const n = bodyLines(lines, i); if (n > 250) say(f, i, '型別本體 ' + n + ' 行（上限 250）'); }
  });
  const flat = src.split('\n').filter(x => !x.trim().startsWith('//')).map(stripStrings).join('\n');
  for (const [o, c] of [['(', ')'], ['{', '}'], ['[', ']']]) {
    const a = flat.split(o).length - 1, b = flat.split(c).length - 1;
    if (a !== b) say(f, 0, '括號不平衡 ' + o + c + ' ' + a + '/' + b);
  }
  console.log(path.basename(f) + ': ' + (lines.length - 1) + ' 行');
}
console.log('測試共 ' + totalTests + ' 條');
console.log(bad ? ('共 ' + bad + ' 個問題') : '文字層檢查通過');
process.exit(bad ? 1 : 0);
