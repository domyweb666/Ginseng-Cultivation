// raw RGBA 圖層 → 分層 PSD（給 rigby import-psd）
import fs from 'node:fs';
import { createRequire } from 'node:module';
const [src, rawDir, out] = process.argv.slice(2);
const require = createRequire(src + '/package.json');
const { writePsdBuffer } = require('ag-psd');
const m = JSON.parse(fs.readFileSync(rawDir + '/manifest.json', 'utf8'));
const W = m.width, H = m.height;
const comp = new Uint8ClampedArray(W * H * 4);
const children = m.layers.map((l) => {
  const w = l.right - l.left, h = l.bottom - l.top;
  const data = new Uint8ClampedArray(fs.readFileSync(`${rawDir}/${l.name}.bin`));
  if (data.length !== w * h * 4) throw new Error('size mismatch ' + l.name);
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const i = (y * w + x) * 4; if (data[i + 3] < 128) continue;
    comp.set(data.subarray(i, i + 4), ((l.top + y) * W + l.left + x) * 4);
  }
  return { name: l.name, top: l.top, left: l.left, bottom: l.bottom, right: l.right, imageData: { width: w, height: h, data } };
});
fs.writeFileSync(out, Buffer.from(writePsdBuffer({ width: W, height: H, imageData: { width: W, height: H, data: comp }, children }, { noBackground: true })));
console.log('wrote', out);
