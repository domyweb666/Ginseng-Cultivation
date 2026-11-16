# 重新產生三張畫板：14 張待機動作、七境深色卡、三境底色候選。
# 播法改成「固定大小的格子換背景位置」，不再平移一張兩萬像素寬的圖；眨眼已經畫進動畫，不另外疊。
import io, json, re, sys
root = sys.argv[1]
IDS = {'r0': '89ee52810dc7f86a6bcf59b5fa3d9f53', 'r1': '80110bf1a09ed7bd39e7f8454f7f984e', 'r2': '11de902cf23135a2e9c5e2f86ab4d0f2',
       'r3': '48468dff5b626db5f69bf917fb5fab95', 'r4': '3212ae82894a1109d366eb913ccfc682', 'r5': 'db5f7fa2af85ab22771b7604a1c1d036',
       'r6': '9112fda329491f4d0ca4aa210b000e3d', 'gr0': '4cb19be9c8cecea95b954b802bb52d15', 'gr1': '5583938114a9654cd15e10747a3ed14b',
       'gr2': '31a14383e1d61847d330950777dccae4', 'gr3': 'b0d2bcd7851d3ba01224371c933de8cb', 'gr4': 'a99b48e564d4884f6dc9eb5531bbc111',
       'gr5': '5ccad71b65b75cf959a922cd7027ef1c', 'gr6': '6a11414a23a73bb8fb1addbaf4be614b'}
json.dump({k: {'strip': '/_blob/' + v} for k, v in IDS.items()}, io.open('urls.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
CSS = ('.lp{position:relative;overflow:hidden;background:#FFFFFF}\n'
       '.lp-strip{width:100%;height:100%;background-repeat:no-repeat;background-size:4800% 100%;image-rendering:pixelated;'
       'animation:lp-play 4.8s steps(48,jump-none) infinite}\n'
       '@keyframes lp-play{from{background-position:0% 0}to{background-position:100% 0}}\n'
       '@media (prefers-reduced-motion:reduce){.lp-strip{animation:none !important}}\n'
       + '\n'.join('.st-%s{background-image:url(/_blob/%s)}' % kv for kv in IDS.items()))
STRIP_DIV = '<div class="lp-strip {{%s.cls}}" style="animation-delay: {{%s.delay}}"></div>'
REALM = [('煉氣', '壹', '#734D29', '#EFE2D3', '一般未訓練'), ('築基', '貳', '#5C6234', '#E9E8D0', '有基礎'), ('金丹', '參', '#4D5525', '#E8E6CF', '看得出有在練'),
         ('元嬰', '肆', '#6F5E38', '#EEE7D2', '資深健身者'), ('化神', '伍', '#43528F', '#DFE2F3', '菁英'), ('大乘', '陸', '#8B540B', '#F6E7CB', '天賦上限附近'),
         ('渡劫', '柒', '#4A4249', '#E3DCDA', '自然人極限')]
ACT = {
 'r0': ('掂水桶', '平常一拍彈一下。中間先蹲、手往下沉，一口氣把桶提起來，放下時桶盪幾下、水濺出來。'),
 'gr0': ('邊搖邊踮', '提著桶一拍一拍左右搖，髮帶和長髮跟著甩，桶慢半拍往反方向盪。搖一陣子，原地踮兩下。'),
 'r1': ('舉劍下劈', '先蹲一下，把劍慢慢舉過頭、人跟著拉長，一格劈下來、身體壓扁往前帶，再彈回站好。'),
 'gr1': ('連點兩劍', '第一下短，縮一下就刺。第二下蓄久一點、整個人往前送，裙襬和髮帶甩開再收回來。'),
 'r2': ('拋接金丹', '人蹲一下、往上一送把金丹拋高，頭抬起來看。落回掌心時整個人一頓，迸出一圈火花。'),
 'gr2': ('金丹繞圈', '金丹在掌心上方繞圈，身體跟著它左右傾。繞到第二圈，縮一下、往上一挺，盪出一圈光環。'),
 'r3': ('拄杖點地', '把手杖提起來、人跟著拉長，往地上一頓，人壓扁、畫面震一下，腳邊盪開兩圈光紋。'),
 'gr3': ('養元嬰', '兩手各升起一顆光點，繞個彎匯進頭頂的元嬰。匯進去那一格人往上一挺，元嬰亮起來。'),
 'r4': ('吐納', '浮在夜空裡慢慢起伏。深吸一口氣、身體慢慢拉長，一口吐出來、人一沉，星光從身邊散開。'),
 'gr4': ('聚星', '星光一顆顆被吸過來、繞個彎落進掌心。吸夠了，縮一下、往上一挺，兩掌的光一起炸開。'),
 'r5': ('佛光', '浮在雲上起伏。縮一下、兩手往上一托，背後的光輪盪出一圈金環，皇冠上的寶石閃一下。'),
 'gr5': ('落花', '浮在雲上，一拍一拍輕輕左右傾。金色花瓣一片片飄下來、邊落邊翻面，中間開心地往上一挺。'),
 'r6': ('扛天雷', '喘著氣撐著。天暗下來、人越蹲越低，大雷劈下來，整張閃白震一下；頂住之後一口氣挺回來。'),
 'gr6': ('電弧纏身', '細電弧在身上亂竄。左邊先落一道小雷，人一沉又彈回來；隔一陣子右邊那道大的再劈一次。'),
}


def delay(i, girl):
    return '-%.1fs' % ((i * 1.7 + (2.9 if girl else 0)) % 4.8)


def write(name, html):
    io.open(root + '/project/' + name, 'w', encoding='utf-8', newline='\n').write(html)


# ---- 14 張待機動作 ----
def cards(prefix, sex):
    out = []
    for i, (realm, seal, bg, sub, who) in enumerate(REALM):
        code = '%s%d' % (prefix, i)
        out.append({'bg': bg, 'sub': sub, 'realm': realm, 'seal': seal, 'who': '%s・%s' % (sex, who), 'cls': 'st-' + code,
                    'delay': delay(i, prefix == 'gr'), 'act': ACT[code][0], 'how': ACT[code][1], 'alt': '%s，%s，%s' % (realm, sex, ACT[code][0])})
    return out


row = io.open('idle_row.html', encoding='utf-8').read()
row = re.sub(r'<img class="lp-strip".*?</sc-if>\n', STRIP_DIV % ('c', 'c') + '\n', row, flags=re.S)
page = io.open('idle_page.html', encoding='utf-8').read()
page = re.sub(r'\.lp\{.*?\n@media[^\n]*\n', lambda m: CSS + '\n', page, flags=re.S)
page = page.replace('每條 48 格、一格 0.1 秒，4.8 秒一輪。平常只有呼吸、葉子、鬚和衣角在動，隔一陣子做一次招牌動作。卡片套上這次挑的七個底色。',
                    '照像素 B-roll 的做法重排：角色有清楚的姿勢，動作前先蹲、出手只用一兩格、落定時壓扁再回彈，葉子和頭髮晚一拍跟著甩。每條 48 格、一格 0.1 秒，眨眼畫在動畫裡。')
W, H = 2790, 1560
page = (page.replace('__W__', str(W)).replace('__H__', str(H))
        .replace('__MEN__', row.replace('__SEX__', '男').replace('__LIST__', 'men'))
        .replace('__WOMEN__', row.replace('__SEX__', '女').replace('__LIST__', 'women'))
        .replace('__MJ__', json.dumps(cards('r', '男'), ensure_ascii=False))
        .replace('__WJ__', json.dumps(cards('gr', '女'), ensure_ascii=False)))
assert '<img' not in page and '__' not in page
write('IdleCards.dc.html', page)

# ---- 三境底色候選 ----
SEVEN = [r[2] for r in REALM]
ROWS = [
 ('元嬰', 'ying', 3, 'r3', '肆', 'FFMI 21.8・根基穩固', [
   ('#6F5E38', '#EEE7D2', '現在的：古銅', '白金袍的金壓暗。'),
   ('#6B5D50', '#EDE6DF', '候選一：灰褐', '取雲和袍子陰影的暖灰。最不搶眼，跟煉氣、大乘的褐金拉得最開。'),
   ('#6E5F22', '#EEE9CC', '候選二：橄欖金', '比現在的更黃、更飽和一點，金的感覺比較明顯。會往築基、金丹的綠靠一點。'),
   ('#7A4424', '#F1E1D5', '候選三：檀木紅褐', '取手杖的木頭色。最暖、最深。缺點是跟煉氣的褐很像，紅印章在上面比較不跳。')]),
 ('化神', 'hua', 4, 'r4', '伍', 'FFMI 22.8・根基穩固', [
   ('#43528F', '#DFE2F3', '現在的：靛藍', '夜空的藍壓暗一階。'),
   ('#2E3966', '#D9DDF0', '候選一：深夜藍', '同一個藍再壓深，比較沉、比較不亮眼。米白字最清楚。'),
   ('#57507A', '#E6E1F0', '候選二：暮紫', '取雲和飄帶的灰紫。比較柔，跟袍子的顏色比較合。'),
   ('#4C5A7A', '#DFE4EE', '候選三：灰藍', '把藍的飽和度拿掉一半。比較不鮮豔，跟其他幾境的濁色比較搭。')]),
 ('大乘', 'cheng', 5, 'r5', '陸', 'FFMI 24.3・根基穩固', [
   ('#8B540B', '#F6E7CB', '現在的：琥珀', '金袍的金壓暗，偏橘。'),
   ('#7A5E0C', '#F3EBC8', '候選一：正金', '往黃的方向拉，不那麼橘，比較像金子。'),
   ('#6E4A12', '#F1E4CC', '候選二：深金褐', '同一個色相再壓深。比較穩，缺點是跟煉氣的褐更近。'),
   ('#6F6418', '#EFEBC8', '候選三：橄欖金', '再往黃綠靠。跟褐色那幾境分得最開，但會有點像築基。')]),
]
crow = io.open('cand_row.html', encoding='utf-8').read().replace('<img class="lp-strip" src="{{c.strip}}" alt="">', STRIP_DIV % ('c', 'c'))
data, rows_html = {}, []
for realm, key, idx, code, seal, ffmi, cands in ROWS:
    lst = []
    for j, (bg, sub, label, note) in enumerate(cands):
        c = {'bg': bg, 'sub': sub, 'label': label, 'note': note, 'realm': realm, 'seal': seal, 'ffmi': ffmi, 'cls': 'st-' + code,
             'delay': '0s', 'alt': '%s，%s' % (realm, label)}
        for i in range(7):
            c['s%d' % i] = bg if i == idx else SEVEN[i]
            c['h%d' % i] = '0 0 0 3px #EFEBE3, 0 0 0 5px #1D1D1F' if i == idx else 'none'
        lst.append(c)
    data[key] = lst
    rows_html.append(crow.replace('__TITLE__', realm).replace('__LIST__', key))
CW, CH = 56 * 2 + 96 + 4 * 350 + 4 * 28, 56 * 2 + 130 + 3 * 700 + 2 * 36
cpage = io.open('cand_page.html', encoding='utf-8').read()
cpage = re.sub(r'\.lp\{.*?\n@media[^\n]*\n', lambda m: CSS + '\n', cpage, flags=re.S)
cpage = (cpage.replace('__W__', str(CW)).replace('__H__', str(CH)).replace('__ROWS__', '\n'.join(rows_html))
         .replace('__DATA__', json.dumps(data, ensure_ascii=False)))
assert '<img' not in cpage and '__' not in cpage
write('ColorCands.dc.html', cpage)

# ---- 七境深色卡（九支手機）----
p = root + '/project/RealmDark.dc.html'
t = io.open(p, encoding='utf-8').read()
t = re.sub(r'\.lp\{.*?\n@media[^\n]*\n', lambda m: CSS + '\n', t, flags=re.S)
t = re.sub(r'<img class="lp-strip.*?</sc-if>\n', STRIP_DIV % ('ph', 'ph') + '\n', t, flags=re.S)
order = ['r0', 'gr0', 'r1', 'r2', 'r3', 'r4', 'r5', 'r6', 'gr6']
it = iter(order)


def fix(m):
    code = next(it)
    return "cls: 'st-%s', delay: '%s'," % (code, delay(order.index(code), False))


t, n = re.subn(r"strip: '[^']*', sc: '[^']*', hasEyes: (?:true|false), eyes: '[^']*',", fix, t)
assert n == 9 and '<img' not in t, n
io.open(p, 'w', encoding='utf-8', newline='\n').write(t)

# ---- 畫板索引 ----
cj = root + '/project/canvas.json'
c = json.load(io.open(cj, encoding='utf-8'))
c['boards']['IdleCards.dc.html'].update({'w': W, 'h': H})
c['boards']['ColorCands.dc.html'] = {'x': 4300, 'y': 10080, 'w': CW, 'h': CH, 'title': '化神、元嬰、大乘的底色候選（各三個）'}
if 'ColorCands.dc.html' not in c['order']:
    c['order'].insert(c['order'].index('RealmDark.dc.html') + 1, 'ColorCands.dc.html')
io.open(cj, 'w', encoding='utf-8', newline='\n').write(json.dumps(c, ensure_ascii=False, separators=(',', ':')))
print('ok', W, H, CW, CH)
