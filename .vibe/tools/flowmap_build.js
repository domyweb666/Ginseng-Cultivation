// flowmap_build.js：把 .vibe/flowmap/*.json 規格產成 vibe-flowmap 格式的雙受眾 HTML。
// 用法：node .vibe/tools/flowmap_build.js <spec.json> <out.html>
// 規格：{ title, project, generated_at, mode, nodes[], edges[], file_index{}, layout{id:[x,y,w?,h?]}, notes? }
// 節點欄位：id,label,type(start|process|decision|end|error),description,trigger_condition,files[],file_responsibilities{},
//          planned_files[]（待掛點）,badge,inferred,subprocess
// 邊欄位：from,to,label,type(success|failure|retry|conditional),call,back,minor,inferred,show_label
'use strict';
const fs = require('fs');
const [specPath, outPath] = process.argv.slice(2);
if (!specPath || !outPath) { console.error('用法：node flowmap_build.js <spec.json> <out.html>'); process.exit(2); }
const spec = JSON.parse(fs.readFileSync(specPath, 'utf8'));

// ---- 驗證：邊引用、file_index 一致、版面齊全 ----
const ids = new Set(spec.nodes.map(n => n.id));
const bad = [];
spec.edges.forEach(e => { if (!ids.has(e.from) || !ids.has(e.to)) bad.push('edge ref ' + JSON.stringify(e)); });
const fi = {};
spec.nodes.forEach(n => (n.files || []).forEach(f => {
  (fi[f] = fi[f] || []).push(n.id);
  if (!((n.file_responsibilities || {})[f])) bad.push('no-resp ' + n.id + ' ' + f);
}));
for (const f in fi) { const a = JSON.stringify(fi[f]), b = JSON.stringify((spec.file_index || {})[f] || null); if (a !== b) bad.push('file_index mismatch ' + f + ' nodes=' + a + ' index=' + b); }
for (const f in (spec.file_index || {})) { if (!fi[f]) bad.push('index-only ' + f); }
spec.nodes.forEach(n => { if (!spec.layout[n.id]) bad.push('no layout ' + n.id); });
Object.keys(spec.layout).forEach(id => { if (!ids.has(id)) bad.push('layout-only ' + id); });
if (bad.length) { console.error('規格有問題：'); bad.forEach(x => console.error(' -', x)); process.exit(1); }

const data = { project: spec.project, generated_at: spec.generated_at, mode: spec.mode, nodes: spec.nodes, edges: spec.edges, file_index: spec.file_index || {}, planned_index: {}, notes: spec.notes || [] };
spec.nodes.forEach(n => (n.planned_files || []).forEach(f => { (data.planned_index[f] = data.planned_index[f] || []).push(n.id); }));
const esc = s => String(s).replace(/[&<>]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;' }[c]));
const jsonText = JSON.stringify(data, null, 1).replace(/<\/script/g, '<\\/script');

const html = `<!doctype html>
<html lang="zh-Hant-TW">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>${esc(spec.title)}</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=JetBrains+Mono:wght@400;700&display=swap" rel="stylesheet">
<style>
:root{--bg:#0d1117;--node:#161b22;--line:#30363d;--fg:#c9d1d9;--mut:#8b949e;--ok:#3fb950;--bad:#f85149;--retry:#d29922;--cond:#58a6ff}
html,body{margin:0;background:var(--bg);color:var(--fg);font-family:'JetBrains Mono','Fira Code',Consolas,monospace;font-size:13px}
header{position:sticky;top:0;z-index:5;display:flex;align-items:center;gap:16px;padding:10px 16px;background:rgba(13,17,23,.94);border-bottom:1px solid var(--line);backdrop-filter:blur(6px)}
header h1{font-size:15px;margin:0;font-weight:700}
header .meta{color:var(--mut);font-size:11px}
header button{margin-left:auto;background:#21262d;color:var(--fg);border:1px solid var(--line);border-radius:6px;padding:6px 12px;font:inherit;cursor:pointer}
header button:hover{border-color:var(--cond)}
.legend{display:flex;flex-wrap:wrap;gap:6px 16px;padding:8px 16px;color:var(--mut);font-size:11px;border-bottom:1px solid var(--line)}
.legend i{display:inline-block;width:22px;height:0;border-top:2px solid;vertical-align:middle;margin-right:4px}
.legend b{display:inline-block;width:14px;height:10px;border:1.5px solid;border-radius:3px;vertical-align:middle;margin-right:4px;font-weight:400}
.notes{padding:8px 16px;color:var(--mut);font-size:11px;border-bottom:1px solid var(--line)}
.canvas{overflow:auto;padding:16px}
svg{display:block}
.node{cursor:pointer}
.node rect{fill:var(--node);stroke:var(--line);stroke-width:1.5;transition:stroke .15s}
.node.decision rect{stroke:var(--cond)}
.node.start rect,.node.end rect{stroke:var(--ok)}
.node.error rect{stroke:var(--bad)}
.node.inferred rect,.node.planned rect{stroke-dasharray:6 4}
.node.sub rect.outer{fill:none;stroke:var(--mut)}
.node:hover rect{stroke:#fff}
.node.active rect{stroke:#fff;stroke-width:2.5}
.node.hl rect{fill:#172217;stroke:var(--ok);stroke-width:2.5}
.node.dim{opacity:.3}
.nbox{padding:7px 10px;height:100%;box-sizing:border-box;display:flex;flex-direction:column;justify-content:center;color:var(--fg);font-family:'JetBrains Mono','Fira Code',Consolas,monospace;overflow:hidden}
.nlabel{font-weight:700;font-size:12px;line-height:1.3}
.nsub{color:var(--mut);font-size:10px;margin-top:3px;line-height:1.3;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
.edge{fill:none;stroke-width:1.6}
.edge.success{stroke:var(--ok)}.edge.failure{stroke:var(--bad)}.edge.retry{stroke:var(--retry);stroke-dasharray:6 4}.edge.conditional{stroke:var(--cond)}
.edge.faint{stroke:var(--mut);stroke-dasharray:2 4;opacity:.55}
.edge.inferred{stroke-dasharray:6 4;opacity:.7}
.elabel{font-size:10px;fill:var(--fg)}
.elabelbg{fill:#0d1117;stroke:var(--line);stroke-width:.8}
#panel{position:fixed;top:0;right:0;width:420px;max-width:94vw;height:100vh;background:#161b22;border-left:1px solid var(--line);transform:translateX(100%);transition:transform .25s ease;z-index:10;overflow:auto;padding:18px 20px 40px;box-sizing:border-box}
#panel.open{transform:none}
#panel h2{font-size:15px;margin:0 36px 6px 0;line-height:1.4}
#panel .tag{display:inline-block;font-size:10px;padding:2px 7px;border:1px solid var(--line);border-radius:999px;color:var(--mut);margin-bottom:12px}
#panel h3{font-size:11px;letter-spacing:.1em;color:var(--mut);margin:16px 0 6px}
#panel p{margin:0;line-height:1.65;white-space:pre-wrap;font-size:12px}
#panel .file{display:block;width:100%;text-align:left;background:#0d1117;border:1px solid var(--line);color:var(--cond);border-radius:6px;padding:7px 9px;margin:6px 0 2px;font:inherit;font-size:11.5px;cursor:pointer}
#panel .file.planned{border-style:dashed;color:var(--mut)}
#panel .file:hover,#panel .file.on{border-color:var(--ok);color:var(--ok)}
#panel .resp{color:var(--mut);font-size:11px;margin:0 0 6px 4px;line-height:1.5}
#panel .close{position:absolute;top:10px;right:14px;background:none;border:0;color:var(--mut);font-size:20px;cursor:pointer}
details{margin:24px 16px;color:var(--mut);font-size:12px}
details pre{white-space:pre-wrap;background:#161b22;border:1px solid var(--line);border-radius:8px;padding:12px;color:var(--fg)}
</style>
</head>
<body>
<header><h1>${esc(spec.title)}</h1><span class="meta" id="meta"></span><button id="copy">複製 JSON</button></header>
<div class="legend">
  <span><i style="border-color:#3fb950"></i>成功路徑</span>
  <span><i style="border-color:#f85149"></i>失敗路徑</span>
  <span><i style="border-color:#d29922;border-style:dashed"></i>重試</span>
  <span><i style="border-color:#58a6ff"></i>條件分支</span>
  <span><i style="border-color:#8b949e;border-style:dotted"></i>呼叫規則引擎／回頭／次要（JSON 有完整標籤）</span>
  <span><b style="border-color:#58a6ff"></b>判斷</span>
  <span><b style="border-color:#f85149"></b>錯誤</span>
  <span><b style="border-color:#8b949e;border-style:double"></b>子流程</span>
  <span><b style="border-color:#8b949e;border-style:dashed"></b>虛線框＝待掛點（計畫中的檔案）或 ⚠ 推斷</span>
  <span>點節點看掛點；點檔案會亮出所有用到它的節點</span>
</div>
${data.notes.length ? '<div class="notes">' + data.notes.map(n => esc(n)).join('<br>') + '</div>' : ''}
<div class="canvas"><svg id="svg" xmlns="http://www.w3.org/2000/svg"></svg></div>
<aside id="panel"><button class="close" id="close" title="關閉">×</button><div id="pbody"></div></aside>
<details><summary>🤖 給 Claude Code 的讀圖說明</summary><pre>這份 HTML 包含一個 &lt;script id="flowmap-data" type="application/json"&gt; 區塊。
讀取方式：document.getElementById('flowmap-data').textContent，然後 JSON.parse()。

重要欄位：
- nodes[].trigger_condition：這個狀態的觸發條件
- nodes[].file_responsibilities：每個檔案在此節點的具體職責
- nodes[].planned_files：待掛點版才有，計畫中要建的檔案（實作後重跑掛點模式會變成 files）
- file_index：反查表（真實檔案）；planned_index：反查表（計畫中的檔案）
- edges[].type：success / failure / retry / conditional
- edges[].call：呼叫規則引擎；edges[].back：回頭；edges[].minor：次要
- nodes[].inferred：⚠ 推斷；nodes[].subprocess：子流程

當你修改一個檔案時，先查 file_index（或 planned_index）找到它涉及的所有節點，
再看每個節點的 edges 確認你的修改是否影響到下游分支。
規格來源：${esc(specPath.replace(/\\\\/g, '/'))}；改規格後重跑 node .vibe/tools/flowmap_build.js 重新產生。</pre></details>
<script id="flowmap-data" type="application/json">
${jsonText}
</script>
<script>
const data=JSON.parse(document.getElementById('flowmap-data').textContent);
const NW=190,NH=64;
const LAYOUT=${JSON.stringify(spec.layout)};
const NS='http://www.w3.org/2000/svg';
const esc=s=>String(s??'').replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
const el=(t,a={},p)=>{const e=document.createElementNS(NS,t);for(const k in a)e.setAttribute(k,a[k]);if(p)p.appendChild(e);return e};
const box=id=>{const [x,y,w,h]=LAYOUT[id];return {x,y,w:w||NW,h:h||NH,cx:x+(w||NW)/2,cy:y+(h||NH)/2}};
const svg=document.getElementById('svg');
let W=0,H=0;for(const id in LAYOUT){const b=box(id);W=Math.max(W,b.x+b.w);H=Math.max(H,b.y+b.h)}
W+=40;H+=40;svg.setAttribute('width',W);svg.setAttribute('height',H);svg.setAttribute('viewBox',\`0 0 \${W} \${H}\`);
const defs=el('defs',{},svg);
for(const [k,c] of Object.entries({success:'#3fb950',failure:'#f85149',retry:'#d29922',conditional:'#58a6ff',faint:'#8b949e'})){
  const m=el('marker',{id:'arr-'+k,viewBox:'0 0 10 10',refX:9,refY:5,markerWidth:7,markerHeight:7,orient:'auto-start-reverse'},defs);
  el('path',{d:'M0,0 L10,5 L0,10 z',fill:c},m);
}
const gE=el('g',{},svg);
data.edges.forEach(e=>{
  const a=box(e.from),b=box(e.to);const faint=e.call||e.back||e.minor;let d,mx,my;
  if(b.y>=a.y+a.h){ const x1=a.cx,y1=a.y+a.h,x2=b.cx,y2=b.y,dy=(y2-y1)/2;
    d=\`M\${x1},\${y1} C\${x1},\${y1+dy} \${x2},\${y2-dy} \${x2},\${y2}\`;mx=(x1+x2)/2;my=(y1+y2)/2;
  } else if(Math.abs(b.cy-a.cy)<a.h){ const left=b.cx<a.cx;const x1=left?a.x:a.x+a.w,x2=left?b.x+b.w:b.x,y=a.cy,k=left?-40:40;
    d=\`M\${x1},\${y} C\${x1+k},\${y+26} \${x2-k},\${y+26} \${x2},\${y}\`;mx=(x1+x2)/2;my=y+20;
  } else { const x1=a.x,y1=a.cy,x2=b.x,y2=b.cy,k1=x1-50,k2=x2-50;
    d=\`M\${x1},\${y1} C\${k1},\${y1} \${k2},\${y2} \${x2},\${y2}\`;mx=Math.min(k1,k2)+10;my=(y1+y2)/2;
  }
  const cls='edge '+(faint?'faint':e.type)+(e.inferred?' inferred':'');
  const p=el('path',{d,class:cls,'marker-end':\`url(#arr-\${faint?'faint':e.type})\`,'data-from':e.from,'data-to':e.to},gE);
  const t=el('title',{},p);t.textContent=\`\${e.from} → \${e.to}：\${e.label}\`;
  if(e.label&&(!faint||e.show_label)){
    const w=[...e.label].reduce((s,c)=>s+(c.charCodeAt(0)>255?10:6.2),0)+10;
    const g=el('g',{},gE);el('rect',{x:mx-w/2,y:my-8,width:w,height:16,rx:3,class:'elabelbg'},g);
    const tx=el('text',{x:mx,y:my+3.5,'text-anchor':'middle',class:'elabel'},g);tx.textContent=e.label;
  }
});
const gN=el('g',{},svg);
data.nodes.forEach(n=>{
  const b=box(n.id);const planned=!(n.files&&n.files.length)&&(n.planned_files&&n.planned_files.length);
  const g=el('g',{class:'node '+n.type+(n.inferred?' inferred':'')+(planned?' planned':'')+(n.subprocess?' sub':''),'data-id':n.id,transform:\`translate(\${b.x},\${b.y})\`},gN);
  if(n.subprocess)el('rect',{x:-4,y:-4,width:b.w+8,height:b.h+8,rx:10,class:'outer'},g);
  el('rect',{x:0,y:0,width:b.w,height:b.h,rx:8},g);
  const fo=el('foreignObject',{x:0,y:0,width:b.w,height:b.h},g);
  const div=document.createElementNS('http://www.w3.org/1999/xhtml','div');div.className='nbox';
  const first=(n.files&&n.files[0])||(n.planned_files&&('計畫：'+n.planned_files[0]))||'[尚未對應]';
  const sub=(n.badge?n.badge+' · ':'')+first;
  div.innerHTML=\`<div class="nlabel">\${esc(n.label)}</div><div class="nsub" title="\${esc(sub)}">\${esc(sub)}</div>\`;
  fo.appendChild(div);
  g.addEventListener('click',()=>openNode(n.id));
});
const panel=document.getElementById('panel'),pbody=document.getElementById('pbody');
const labelOf=id=>(data.nodes.find(x=>x.id===id)||{}).label||id;
function openNode(id){
  const n=data.nodes.find(x=>x.id===id);if(!n)return;
  document.querySelectorAll('.node').forEach(g=>g.classList.toggle('active',g.dataset.id===id));
  const files=(n.files||[]).map(f=>\`<button class="file" data-f="\${esc(f)}" data-kind="file">\${esc(f)}</button><p class="resp">\${esc((n.file_responsibilities||{})[f]||'')}</p>\`).join('');
  const planned=(n.planned_files||[]).map(f=>\`<button class="file planned" data-f="\${esc(f)}" data-kind="planned">\${esc(f)}</button><p class="resp">\${esc((n.file_responsibilities||{})[f]||'')}</p>\`).join('');
  const outs=data.edges.filter(e=>e.from===id).map(e=>\`→ \${labelOf(e.to)}（\${e.label}）\${e.call?' ⚙':''}\${e.back?' ↺':''}\`).join('\\n')||'（終點）';
  const ins=data.edges.filter(e=>e.to===id).map(e=>\`← \${labelOf(e.from)}（\${e.label}）\`).join('\\n')||'（起點）';
  pbody.innerHTML=\`<h2>\${esc(n.label)}</h2><span class="tag">\${n.id} · \${n.type}\${n.subprocess?' · 子流程':''}\${n.inferred?' · ⚠ 推斷':''}\${(!n.files||!n.files.length)&&n.planned_files?' · 待掛點':''}</span>
    <h3>觸發條件</h3><p>\${esc(n.trigger_condition)}</p>
    <h3>這個節點做什麼</h3><p>\${esc(n.description)}</p>
    \${files?'<h3>掛點（真實檔案，點一下亮出用到它的節點）</h3>'+files:''}
    \${planned?'<h3>計畫中的檔案（實作後會變成掛點）</h3>'+planned:''}
    <h3>從哪來</h3><p>\${esc(ins)}</p>
    <h3>往下接</h3><p>\${esc(outs)}</p>\`;
  panel.classList.add('open');
}
let hlFile=null;
pbody.addEventListener('click',ev=>{
  const b=ev.target.closest('.file');if(!b)return;const f=b.dataset.f;const idx=b.dataset.kind==='planned'?data.planned_index:data.file_index;hlFile=hlFile===f?null:f;
  document.querySelectorAll('#panel .file').forEach(x=>x.classList.toggle('on',x.dataset.f===hlFile));
  const ids=hlFile?(idx[hlFile]||[]):null;
  document.querySelectorAll('.node').forEach(g=>{const on=!!ids&&ids.includes(g.dataset.id);g.classList.toggle('hl',on);g.classList.toggle('dim',!!ids&&!on)});
});
document.getElementById('close').addEventListener('click',()=>{panel.classList.remove('open');document.querySelectorAll('.node').forEach(g=>g.classList.remove('active','hl','dim'));hlFile=null});
const copyBtn=document.getElementById('copy');
copyBtn.addEventListener('click',async()=>{const txt=document.getElementById('flowmap-data').textContent.trim();
  try{await navigator.clipboard.writeText(txt);copyBtn.textContent='已複製';setTimeout(()=>copyBtn.textContent='複製 JSON',1500)}
  catch(err){const ta=document.createElement('textarea');ta.value=txt;document.body.appendChild(ta);ta.select();document.execCommand('copy');ta.remove();copyBtn.textContent='已複製';setTimeout(()=>copyBtn.textContent='複製 JSON',1500)}});
document.getElementById('meta').textContent=\`\${data.nodes.length} 節點 · \${data.edges.length} 邊 · \${data.mode||''} · \${data.generated_at}\`;
</script>
</body>
</html>
`;
fs.writeFileSync(outPath, html);
const heavy = Object.entries(data.planned_index).filter(([, v]) => v.length >= 3).map(([k, v]) => k + '(' + v.length + ')');
console.log('OK', outPath, 'nodes', data.nodes.length, 'edges', data.edges.length, 'planned files', Object.keys(data.planned_index).length, 'heavy:', heavy.join(' | ') || '-');
