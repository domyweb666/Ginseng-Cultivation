// [domy_colors] 把 domy-design 的 tokens.json（金棕主題＋中性色）寫成 Assets 的顏色集。
// 用法：node .vibe/tools/domy_colors.mjs [tokens.json 路徑]
// 預設讀 E:/domy-design/tokens/tokens.json。CI 拿不到那個私人 repo，所以產物（顏色集）直接 commit。
// 改了 domy-design 的色碼，重跑這支、看 git diff、commit。
import { readFileSync, writeFileSync, mkdirSync, rmSync, existsSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

// 這台 Windows 的 node 24 碰到中文路徑（載入 .mjs、寫檔）會直接崩潰（0xC0000409）。
// 那時把這支複製到英文路徑，RENCAN_ROOT 指向一個英文路徑的輸出資料夾
//（裡面先建好 ios/Rencan/Resources/Assets.xcassets/AccentColor.colorset），產完再整批複製回專案。
const root = process.env.RENCAN_ROOT || join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const tokensPath = process.argv[2] || 'E:/domy-design/tokens/tokens.json';
const tokens = JSON.parse(readFileSync(tokensPath, 'utf8'));
const theme = tokens.themes.gold;
const canvas = tokens.canvas[theme.canvas];
const neutral = tokens.neutral;

// 顏色集名稱 → [淺色, 深色]。名稱就是 Theme.swift 裡 Color("…") 的字串。
const sets = {
  Canvas: [canvas.light, canvas.dark],
  Surface: [neutral.light.surface, neutral.dark.surface],
  SurfaceMuted: [neutral.light.surfaceMuted, neutral.dark.surfaceMuted],
  Separator: [neutral.light.separator, neutral.dark.separator],
  FieldBorder: [neutral.light.fieldBorder, neutral.dark.fieldBorder],
  TextPrimary: [neutral.light.textPrimary, neutral.dark.textPrimary],
  TextSecondary: [neutral.light.textSecondary, neutral.dark.textSecondary],
  TextTertiary: [neutral.light.textTertiary, neutral.dark.textTertiary],
  Destructive: [neutral.light.destructive, neutral.dark.destructive],
  DestructiveSoft: [neutral.light.destructiveSoft, neutral.dark.destructiveSoft],
  Shadow: [neutral.light.shadow, neutral.dark.shadow],
  Accent: [theme.light.accent, theme.dark.accent],
  OnAccent: [theme.light.onAccent, theme.dark.onAccent],
  Strong: [theme.light.strong, theme.dark.strong],
  Soft: [theme.light.soft, theme.dark.soft],
  Tint: [theme.light.tint, theme.dark.tint],
  Bright: [theme.light.bright, theme.dark.bright],
  OnBright: [theme.light.onBright, theme.dark.onBright],
};

// 粒子自己的顏色：深淺色同一個值，不來自 domy-design（2026-11-16 加）。
// SparkJade 是慶祝粒子的翠綠。小人蔘的七個色 2026-11-16 跟著小人蔘一起拿掉了。
const fixed = {
  SparkJade: '#4CAF8D',
};
for (const [name, hex] of Object.entries(fixed)) sets[name] = [hex, hex];

// 舊的網頁版色票（藍圖第六節舊表），換成 domy 後刪掉
const retired = ['Background', 'Paper', 'Ink', 'InkSecondary', 'Line', 'Jade', 'JadeSoft', 'Gold', 'GoldSoft', 'Warn', 'Scroll'];

const comp = (hex) => {
  const h = hex.replace('#', '');
  return {
    alpha: '1.000',
    blue: '0x' + h.slice(4, 6).toUpperCase(),
    green: '0x' + h.slice(2, 4).toUpperCase(),
    red: '0x' + h.slice(0, 2).toUpperCase(),
  };
};
const contents = ([light, dark]) => JSON.stringify({
  colors: [
    { color: { 'color-space': 'srgb', components: comp(light) }, idiom: 'universal' },
    {
      appearances: [{ appearance: 'luminosity', value: 'dark' }],
      color: { 'color-space': 'srgb', components: comp(dark) },
      idiom: 'universal',
    },
  ],
  info: { author: 'xcode', version: 1 },
}, null, 2) + '\n';

const assets = join(root, 'ios', 'Rencan', 'Resources', 'Assets.xcassets');
const colorsDir = join(assets, 'Colors');

for (const name of retired) {
  const dir = join(colorsDir, name + '.colorset');
  if (existsSync(dir)) rmSync(dir, { recursive: true });
}
for (const [name, pair] of Object.entries(sets)) {
  const dir = join(colorsDir, name + '.colorset');
  mkdirSync(dir, { recursive: true });
  writeFileSync(join(dir, 'Contents.json'), contents(pair));
}
// 系統元件（開關、選取）的強調色跟著產品色
writeFileSync(join(assets, 'AccentColor.colorset', 'Contents.json'), contents(sets.Accent));

console.error('[domy_colors] reason: 從 domy-design ' + tokens.version + ' 寫了 ' + Object.keys(sets).length + ' 個顏色集');
