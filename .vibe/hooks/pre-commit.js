#!/usr/bin/env node
// [pre-commit] VibeRails 口吻鎖定：本機文字層檢查（Windows 沒有 Swift 工具鏈，所以這層只用 node）。
// 不管 AI 記不記得規矩，commit 前都跑；不合規就打回。swift-format 與 SwiftLint 在 GitHub Actions 跑。
// 安裝：git config core.hooksPath .vibe/githooks（新 clone 要再跑一次）。
'use strict';
const { execFileSync } = require('child_process');

// 一律用參數陣列呼叫 git，檔名不進 shell（安全標準 CWE-78）
function staged() {
  const out = execFileSync('git', ['diff', '--cached', '--name-only', '--diff-filter=ACM', '-z'], { encoding: 'utf8' });
  return out.split('\0').filter(Boolean);
}
function stagedContent(path) {
  return execFileSync('git', ['show', ':' + path], { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
}

const problems = [];
const report = (file, line, rule, why) => problems.push({ file, line, rule, why });

// 規則一：憑證與金鑰永遠不進 repo（安全標準 CWE-798）
const SECRET_EXT = /\.(p12|p8|cer|mobileprovision|pem|key|keychain)$/i;

// 規則二：Swift 文字層禁令（規矩檔第 4 節），測試檔豁免 print
const SWIFT_RULES = [
  { re: /\btry\?/, rule: 'try?', why: '吞掉錯誤。錯誤要往上丟到畫面（規矩檔 4）' },
  { re: /\bcatch\s*(\w+\s*)?\{\s*\}/, rule: 'empty-catch', why: '空的 catch 把錯誤吃掉' },
  { re: /\b(print|debugPrint|NSLog)\s*\(/, rule: 'print', why: '不准 log；健康數值不進 log（安全標準）', skipTests: true },
  { re: /\bos_log\b|\bLogger\s*\(/, rule: 'os_log', why: '不准 log（安全標準）', skipTests: true },
  { re: /NSAllowsArbitraryLoads/, rule: 'ats', why: '不准關 ATS（安全標準）' },
  { re: /\bCloudKit\b|cloudKitDatabase|iCloud/, rule: 'icloud', why: '不做 iCloud（審核規範 5.1.3）', skipTests: true },
  { re: /\bURLSession\b|\bURLRequest\b/, rule: 'http', why: 'app 不發 HTTP 請求（安全標準）' },
  { re: /\bColor\s*\(\s*(red|hex|\.sRGB|white)\b|\bUIColor\s*\(\s*(red|white|hex)\b|#[0-9A-Fa-f]{6}\b/, rule: 'hardcoded-color', why: '顏色只從設計代號取（藍圖第六節）', viewsOnly: true },
  { re: /\bimport\s+(SwiftUI|SwiftData|HealthKit|WidgetKit|UIKit|AppIntents)\b/, rule: 'core-imports', why: 'RencanCore 只准 import Foundation（規矩檔 1）', coreOnly: true },
];

// 規則三：工作流不准 echo secrets、不准把外部字串拼進 shell（安全標準 CWE-78）
const YAML_RULES = [
  { re: /echo[^\n]*secrets\./i, rule: 'echo-secret', why: 'secrets 不准 echo' },
  { re: /\$\{\{\s*github\.event\.(pull_request\.title|head_commit\.message|comment\.body)/, rule: 'shell-injection', why: 'PR 標題、commit 訊息不准進 shell' },
];

for (const file of staged()) {
  if (SECRET_EXT.test(file)) { report(file, 0, 'secret-file', '憑證或金鑰檔不准進 repo'); continue; }
  const isSwift = /\.swift$/.test(file);
  const isYaml = /^\.github\/workflows\/.*\.ya?ml$/.test(file);
  if (!isSwift && !isYaml) continue;
  let text;
  try { text = stagedContent(file); } catch (e) { report(file, 0, 'read', '讀不到暫存內容：' + e.message); continue; }
  const lines = text.split('\n');
  const isTest = /\/Tests\//.test(file) || /Tests\.swift$/.test(file);
  const isView = /\/Views\//.test(file) || /View\.swift$/.test(file) || /\/RencanWidget\//.test(file);
  const isCore = /\/RencanCore\/Sources\//.test(file);
  const rules = isSwift ? SWIFT_RULES : YAML_RULES;
  lines.forEach((line, i) => {
    const trimmed = line.trim();
    if (isSwift && trimmed.startsWith('//')) return; // 註解不算
    for (const r of rules) {
      if (r.skipTests && isTest) continue;
      if (r.viewsOnly && !isView) continue;
      if (r.coreOnly && !isCore) continue;
      if (r.re.test(line)) report(file, i + 1, r.rule, r.why);
    }
  });
}

if (problems.length) {
  console.error('[pre-commit] reason: 口吻鎖定攔下 ' + problems.length + ' 個問題，commit 被打回');
  for (const p of problems) console.error('  ' + p.file + ':' + p.line + '  [' + p.rule + '] ' + p.why);
  console.error('修好再 commit。這是機器檢查，不是 AI 自律；規則在 .vibe/規矩檔.md 第 4 節與 .vibe/安全標準.md。');
  process.exit(1);
}
console.error('[pre-commit] reason: 口吻鎖定通過');
