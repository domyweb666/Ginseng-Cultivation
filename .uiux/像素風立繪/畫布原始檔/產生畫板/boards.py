# 重新產生三張畫板：14 張待機動作、七境深色卡、三境底色候選。
# 用法：python boards.py <畫布的 artifact-files/<id> 資料夾>   （在放樣板 idle_*.html、cand_*.html 的資料夾裡跑）
# 動畫是 12x8 的格子圖（96 格、一格 0.1 秒）。播法：固定大小的格子當視窗，一格一個關鍵影格換背景位置，不平移大圖。
# 眨眼已經畫進動畫，不另外疊。
import io, json, re, sys
root = sys.argv[1]
N, COLS, ROWS_ = 96, 12, 8
IDS = {'r0': '26a86ed223dcf5b8d21e1ece60089fa5', 'r1': '11fb9db98a227efab3719215c1299de6', 'r2': '17661a67205ade7253e338118db6da41',
       'r3': 'aba79ec4cd217ad022f3f99e653b0cdc', 'r4': '8c2be04be0868a5ae39b7c344233ad5d', 'r5': 'd5a34911878466c3c6a8490df7bfed89',
       'r6': 'cfdf5afb179db0e0c6a456c773bb77fe', 'gr0': '3a559489212d2317eb4a8db376028f0f', 'gr1': '2c19e0ddd222ca6b112d4d10f380fadd',
       'gr2': '9e5349c1edecb0e6577743f6fb9e1405', 'gr3': 'd5a7dde67d8d703b9d934fb12b2e59af', 'gr4': '26966b76880c31cc56a37b43c506f742',
       'gr5': '9d863946a2b31258fb6b18ab0f785b49', 'gr6': 'c817b48d1d97446e77d3a995984864fc'}
json.dump({k: {'sheet': '/_blob/' + v, 'frames': N, 'cols': COLS, 'rows': ROWS_} for k, v in IDS.items()},
          io.open('urls.json', 'w', encoding='utf-8'), ensure_ascii=False, indent=1)


def keyframes():
    out = []
    for i in range(N):
        r, c = divmod(i, COLS)
        out.append('%.4f%%{background-position:%.4f%% %.4f%%}' % (100.0 * i / N, 100.0 * c / (COLS - 1), 100.0 * r / (ROWS_ - 1)))
    out.append('100%%{background-position:100%% 100%%}' % ())
    return '@keyframes lp-play{' + ''.join(out) + '}'


CSS = ('.lp{position:relative;overflow:hidden;background:#FFFFFF}\n'
       '.lp-strip{width:100%%;height:100%%;background-repeat:no-repeat;background-size:%d%% %d%%;image-rendering:pixelated;'
       'animation:lp-play %.1fs step-end infinite}\n' % (COLS * 100, ROWS_ * 100, N / 10.0)
       + keyframes() + '\n'
       '@media (prefers-reduced-motion:reduce){.lp-strip{animation:none !important}}\n'
       + '\n'.join('.st-%s{background-image:url(/_blob/%s)}' % kv for kv in IDS.items()) + '\n')
CSS_RE = r'\.lp\{.*?(?=</style>)'
STRIP_DIV = '<div class="lp-strip {{%s.cls}}" style="animation-delay: {{%s.delay}}"></div>'
# 七個境界定案的底色（2026-11-16 多米選定：元嬰候選三、化神候選一、大乘候選一）
REALM = [('煉氣', '壹', '#734D29', '#EFE2D3', '一般未訓練'), ('築基', '貳', '#5C6234', '#E9E8D0', '有基礎'), ('金丹', '參', '#4D5525', '#E8E6CF', '看得出有在練'),
         ('元嬰', '肆', '#7A4424', '#F1E1D5', '資深健身者'), ('化神', '伍', '#2E3966', '#D9DDF0', '菁英'), ('大乘', '陸', '#7A5E0C', '#F3EBC8', '天賦上限附近'),
         ('渡劫', '柒', '#4A4249', '#E3DCDA', '自然人極限')]
ACT = {
 'r0': ('掂水桶', '平常一拍彈一下。中間先蹲、手往下沉，一口氣把桶提起來，放下時桶盪幾下、水濺出來。'),
 'gr0': ('邊搖邊踮', '提著桶一拍一拍左右搖，髮帶和長髮跟著甩，桶慢半拍往反方向盪。搖一陣子，原地踮兩下。'),
 'r1': ('舉劍下劈', '先蹲一下，把劍慢慢舉過頭、人跟著站高，一格劈下來、人往下一沉往前帶，再彈回站好。'),
 'gr1': ('連點兩劍', '第一下短，縮一下就刺。第二下蓄久一點、整個人往前送，髮帶甩開再收回來。'),
 'r2': ('拋接金丹', '人蹲一下、往上一送把金丹拋高。落回掌心時整個人一頓，迸出一圈火花。'),
 'gr2': ('金丹繞圈', '金丹在掌心上方繞圈，身體跟著它左右移。繞到第二圈，縮一下、往上一挺，盪出一圈光環。'),
 'r3': ('拄杖點地', '把手杖提起來、人跟著升高，往下一頓，人一沉、畫面震一下，腳邊盪開兩圈光紋。'),
 'gr3': ('養元嬰', '兩手各升起一顆光點，繞個彎匯進頭頂的元嬰。匯進去那一格人往上一挺，元嬰亮起來。'),
 'r4': ('吐納', '浮在夜空裡慢慢起伏。深吸一口氣、人慢慢升高，一口吐出來、人一沉，星光從身邊散開。'),
 'gr4': ('聚星', '星光一顆顆被吸過來、繞個彎落進掌心。吸夠了，縮一下、往上一挺，兩掌的光一起炸開。'),
 'r5': ('佛光', '浮在雲上起伏。縮一下、往上一挺，背後的光輪盪出一圈金環，皇冠上的寶石閃一下。'),
 'gr5': ('落花', '浮在雲上，一拍一拍輕輕左右移。金色花瓣一片片飄下來、邊落邊翻面，中間開心地往上一挺。'),
 'r6': ('扛天雷', '喘著氣撐著。天暗下來、人越蹲越低，大雷劈下來，整張閃白震一下；頂住之後一口氣挺回來。'),
 'gr6': ('電弧纏身', '細電弧在身上亂竄。左邊先落一道小雷，人一沉又彈回來；隔一陣子右邊那道大的再劈一次。'),
}


def delay(i, girl):
    return '-%.1fs' % ((i * 1.7 + (4.3 if girl else 0)) % (N / 10.0))


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
page = re.sub(CSS_RE, lambda m: CSS, page, flags=re.S)
old = '每條 48 格、一格 0.1 秒，4.8 秒一輪。平常只有呼吸、葉子、鬚和衣角在動，隔一陣子做一次招牌動作。卡片套上這次挑的七個底色。'
assert old in page
page = page.replace(old, '衣服不再變形：頭、手、衣服整塊照姿勢移動，蹲下和站高只動腿。袖子、衣襬、飄帶不再起伏，只有頭髮、葉子和道具會被帶著盪。'
                         '一輪 96 格、9.6 秒，招牌動作 9.6 秒做一次，其餘時間只有呼吸和眨眼。卡片是定案的七個底色。')
page = page.replace('G 款第二版', 'G 款第三版')
W, H = 2790, 1560
page = (page.replace('__W__', str(W)).replace('__H__', str(H))
        .replace('__MEN__', row.replace('__SEX__', '男').replace('__LIST__', 'men'))
        .replace('__WOMEN__', row.replace('__SEX__', '女').replace('__LIST__', 'women'))
        .replace('__MJ__', json.dumps(cards('r', '男'), ensure_ascii=False))
        .replace('__WJ__', json.dumps(cards('gr', '女'), ensure_ascii=False)))
assert '<img' not in page and '__' not in page and 'G 款第三版' in page
write('IdleCards.dc.html', page)

# ---- 三境底色候選（已選定）----
SEVEN = [r[2] for r in REALM]
ROWS = [
 ('元嬰', 'ying', 3, 'r3', '肆', 'FFMI 21.8・根基穩固', [
   ('#6F5E38', '#EEE7D2', '原本的：古銅', '白金袍的金壓暗。'),
   ('#6B5D50', '#EDE6DF', '候選一：灰褐', '取雲和袍子陰影的暖灰。最不搶眼，跟煉氣、大乘的褐金拉得最開。'),
   ('#6E5F22', '#EEE9CC', '候選二：橄欖金', '比原本的更黃、更飽和一點，金的感覺比較明顯。會往築基、金丹的綠靠一點。'),
   ('#7A4424', '#F1E1D5', '選定｜候選三：檀木紅褐', '取手杖的木頭色。最暖、最深。缺點是跟煉氣的褐很像，紅印章在上面比較不跳。')]),
 ('化神', 'hua', 4, 'r4', '伍', 'FFMI 22.8・根基穩固', [
   ('#43528F', '#DFE2F3', '原本的：靛藍', '夜空的藍壓暗一階。'),
   ('#2E3966', '#D9DDF0', '選定｜候選一：深夜藍', '同一個藍再壓深，比較沉、比較不亮眼。米白字最清楚。'),
   ('#57507A', '#E6E1F0', '候選二：暮紫', '取雲和飄帶的灰紫。比較柔，跟袍子的顏色比較合。'),
   ('#4C5A7A', '#DFE4EE', '候選三：灰藍', '把藍的飽和度拿掉一半。比較不鮮豔，跟其他幾境的濁色比較搭。')]),
 ('大乘', 'cheng', 5, 'r5', '陸', 'FFMI 24.3・根基穩固', [
   ('#8B540B', '#F6E7CB', '原本的：琥珀', '金袍的金壓暗，偏橘。'),
   ('#7A5E0C', '#F3EBC8', '選定｜候選一：正金', '往黃的方向拉，不那麼橘，比較像金子。'),
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
cpage = re.sub(CSS_RE, lambda m: CSS, cpage, flags=re.S)
old = '每一列最左邊是現在的，右邊三個是候選。'
assert old in cpage
cpage = cpage.replace(old, '已定案：元嬰用候選三、化神用候選一、大乘用候選一，標「選定」的那三張。每一列最左邊是原本的，右邊三個是候選。')
cpage = cpage.replace('其他四境照上次那組沒動。', '色塊裡另外兩境已經換成選定的顏色。')
cpage = (cpage.replace('__W__', str(CW)).replace('__H__', str(CH)).replace('__ROWS__', '\n'.join(rows_html))
         .replace('__DATA__', json.dumps(data, ensure_ascii=False)))
assert '<img' not in cpage and '__' not in cpage and '已定案' in cpage and '兩境已經換成' in cpage
write('ColorCands.dc.html', cpage)

# ---- 七境深色卡（九支手機）----
p = root + '/project/RealmDark.dc.html'
t = io.open(p, encoding='utf-8').read()
t = re.sub(CSS_RE, lambda m: CSS, t, flags=re.S)
order = ['r0', 'gr0', 'r1', 'r2', 'r3', 'r4', 'r5', 'r6', 'gr6']
t, n = re.subn(r"cls: 'st-(\w+)', delay: '[^']*',", lambda m: "cls: 'st-%s', delay: '%s'," % (m.group(1), delay(order.index(m.group(1)), False)), t)
assert n == 9, n
SWAP = [
 ("{ label: '元嬰', note: '白金袍沒有夠深的顏色。取袍子的金，壓暗成古銅色。',\n  cardBg: '#6F5E38', nameColor: '#FFF4D2', subColor: '#EEE7D2',",
  "{ label: '元嬰', note: '你選的檀木紅褐，取手杖的木頭色。',\n  cardBg: '#7A4424', nameColor: '#FFF4D2', subColor: '#F1E1D5',"),
 ("{ label: '化神', note: '取夜空的靛藍，壓暗一階讓米白字夠清楚。',\n  cardBg: '#43528F', nameColor: '#FFF4D2', subColor: '#DFE2F3',",
  "{ label: '化神', note: '你選的深夜藍，夜空的藍再壓深。',\n  cardBg: '#2E3966', nameColor: '#FFF4D2', subColor: '#D9DDF0',"),
 ("{ label: '大乘', note: '金袍的金壓暗成琥珀色。跟元嬰的古銅比，這個比較橘、比較飽和。',\n  cardBg: '#8B540B', nameColor: '#FFF4D2', subColor: '#F6E7CB',",
  "{ label: '大乘', note: '你選的正金，比原本的琥珀黃一點、不那麼橘。',\n  cardBg: '#7A5E0C', nameColor: '#FFF4D2', subColor: '#F3EBC8',"),
]
for a, b in SWAP:
    assert t.count(a) == 1 or t.count(b) == 1, a
    t = t.replace(a, b)
assert '<img' not in t and t.count('.st-r0{') == 1
io.open(p, 'w', encoding='utf-8', newline='\n').write(t)

# ---- 畫板索引 ----
cj = root + '/project/canvas.json'
c = json.load(io.open(cj, encoding='utf-8'))
c['boards']['IdleCards.dc.html'].update({'w': W, 'h': H, 'title': 'G 款第三版：14 張各自的待機動作（衣服不變形、9.6 秒一輪）'})
c['boards']['RealmDark.dc.html']['title'] = '七個境界的深色卡（底色定案）'
c['boards']['ColorCands.dc.html'].update({'w': CW, 'h': CH, 'title': '化神、元嬰、大乘的底色候選（已選定）'})
io.open(cj, 'w', encoding='utf-8', newline='\n').write(json.dumps(c, ensure_ascii=False, separators=(',', ':')))
print('ok', W, H, CW, CH, len(CSS))
