# 重新產生三張畫板：14 張待機動作、七境深色卡、三境底色候選。
# 用法：python boards.py <畫布的 artifact-files/<id> 資料夾>   （在放樣板 idle_*.html、cand_*.html 的資料夾裡跑）
# 動畫是 12x8 的格子圖（96 格、一格 0.1 秒）。播法：固定大小的格子當視窗，一格一個關鍵影格換背景位置，不平移大圖。
# 眨眼已經畫進動畫，不另外疊。
import io, json, re, sys
root = sys.argv[1]
N, COLS, ROWS_ = 96, 12, 8
FT = 0.15            # 一格播幾秒。多米嫌 0.1 太快，2026-11-16 在比較畫板上選了 0.15（「中」）
LOOP = N * FT        # 一輪幾秒
# 煉氣男拆成零件的試做版，和它的八個圖層（由下往上）
PARTS_SHEET = '227b5df70b01a8e90c29e56d98817212'
LAYERS = [('背景', '03dd923e1a3cedee6d08895e34870dc2', '角色那一塊補起來了，完全不動。'),
          ('腿', 'e778ec9e693eef4328d24f2118d3a1b8', '衣襬底下那一段往上補了幾格，身體升高時不會露出空隙。'),
          ('手臂', '41adc93fa4cb16375183836381047365', '繞肩膀轉。上緣藏在袖口底下。'),
          ('頭', 'b38ea98e612d5b84e43673f90cfc7193', '臉、根鬚、紅果。下巴底下補了幾格脖子。'),
          ('身體', '7b1d4f6d3282be52efd2ee5173c5de27', '衣服和插腰的那隻手。只做整格平移。'),
          ('水桶', 'f87b91124e0698e8ad262ae6acb76ba4', '掛在手上，手臂怎麼轉它都垂著，會餘盪。'),
          ('左葉', 'bd633c3a71f48eb1d60f530f4997292c', '掛在頭上，繞葉柄轉。'),
          ('右葉', '1f2d67760884682596306b220e4b5d17', '掛在頭上，繞葉柄轉。')]
# 比較用：同一張角色的另外兩種待機方式（still 身體不動、sway 慢慢左右晃）。14 張定案用的是「慢慢呼吸」
ALT = {'r0-still': 'b02288e14fdc0ea78a0cc880fbb6ff04', 'r0-sway': '75cf568ed6232acbd335beb8a075e0ce',
       'r3-still': '25caa1fb8162c5eecad74f1fd5d5ed62', 'r3-sway': 'e7a27fa849988261d91cb9e371dbc557'}
IDS = {'r0': 'e4703d812e234d404e869bab553955a9', 'r1': '6a96021c99d8f0be5f70f00cf9848e6a', 'r2': 'fa91201bf33fade95020d0c0d7f57072',
       'r3': 'c0cee077335372c80f6b5d4032923949', 'r4': '697071a7b3e60225106d25df98c4929d', 'r5': 'c932013799b3e815144e08be853b27ec',
       'r6': '7908ed1813267dc3557af98d86c0c135', 'gr0': '244f8de3877d178fd85437d44ccb9fc6', 'gr1': '4a239ece7cf3c6466f57ff3538f052af',
       'gr2': 'b5c5b9b2c1f2834984c89130e04d0133', 'gr3': '3457872ddea055c26ce635dc36ae134f', 'gr4': 'e0a26552466fc45a2e34c1c00144e3a9',
       'gr5': '75a5a2d5290a9bafbee7233b302890eb', 'gr6': 'a79d5b806f526c3339ee371b9f9f8890'}
json.dump({k: {'sheet': '/_blob/' + v, 'frames': N, 'cols': COLS, 'rows': ROWS_, 'seconds_per_frame': FT} for k, v in IDS.items()},
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
       'animation:lp-play %.1fs step-end infinite}\n' % (COLS * 100, ROWS_ * 100, LOOP)
       + keyframes() + '\n'
       '@media (prefers-reduced-motion:reduce){.lp-strip{animation:none !important}}\n'
       + '.sp10{animation-duration:%.1fs}.sp20{animation-duration:%.1fs}\n' % (N * 0.1, N * 0.2)
       + '\n'.join('.st-%s{background-image:url(/_blob/%s)}' % kv for kv in list(IDS.items()) + list(ALT.items()) + [('r0-parts', PARTS_SHEET)]) + '\n')
CSS_RE = r'\.lp\{.*?(?=</style>)'
STRIP_DIV = '<div class="lp-strip {{%s.cls}}" style="animation-delay: {{%s.delay}}"></div>'
# 七個境界定案的底色（2026-11-16 多米選定：元嬰候選三、化神候選一、大乘候選一）
REALM = [('煉氣', '壹', '#734D29', '#EFE2D3', '一般未訓練'), ('築基', '貳', '#5C6234', '#E9E8D0', '有基礎'), ('金丹', '參', '#4D5525', '#E8E6CF', '看得出有在練'),
         ('元嬰', '肆', '#7A4424', '#F1E1D5', '資深健身者'), ('化神', '伍', '#2E3966', '#D9DDF0', '菁英'), ('大乘', '陸', '#7A5E0C', '#F3EBC8', '天賦上限附近'),
         ('渡劫', '柒', '#4A4249', '#E3DCDA', '自然人極限')]
ACT = {
 'r0': ('掂水桶', '平常桶輕輕晃。慢慢蹲、手往下沉，把桶提起來，放下時桶盪幾下、水濺出來。'),
 'gr0': ('提桶輕搖', '提著桶慢慢左右搖，一次移一格、停一下，桶慢半拍往反方向盪。搖一陣子停下來歇一下。'),
 'r1': ('舉劍下劈', '平常劍上偶爾滑過一點光。把劍慢慢舉過頭、人跟著站高，劈下來、人往下一沉，再慢慢站好。'),
 'gr1': ('連點兩劍', '平常劍上偶爾滑過一點光。第一下短，第二下蓄久一點、整個人往前送，再收回來。'),
 'r2': ('拋接金丹', '平常金丹在掌心上方輕輕浮。人慢慢蹲一下、往上一送把金丹拋高，落回掌心時迸出一圈火花。'),
 'gr2': ('金丹繞圈', '金丹在掌心上方繞圈、拖著一串光點，身體跟著它左右移一格。繞到第二圈，金丹盪出一圈光環。'),
 'r3': ('拄杖點地', '平常腳邊有光點往上飄。把手杖慢慢提起來，往下一頓，腳邊盪開兩圈光紋。'),
 'gr3': ('養元嬰', '兩手各升起一顆光點，繞個彎匯進頭頂的元嬰，元嬰亮起來、盪出一圈光。'),
 'r4': ('吐納', '平常只有星星在閃。深吸一口氣、人慢慢升高，吐出來時慢慢落回去，星光從身邊散開。'),
 'gr4': ('聚星', '星光一顆顆被吸過來、繞個彎落進掌心，吸夠了，兩掌的光一起炸開。'),
 'r5': ('佛光', '背後的佛光一直慢慢轉，隔一陣子光輪盪出一圈金環，皇冠上的寶石閃一下。'),
 'gr5': ('落花', '慢慢左右移一格。金色花瓣一片片飄下來、邊落邊翻面，背後的光一明一暗。'),
 'r6': ('扛天雷', '平常腳邊有火星往上飄。天暗下來、人慢慢蹲低，大雷劈下來整張閃白；頂住之後慢慢挺回來。'),
 'gr6': ('電弧纏身', '細電弧在身上亂竄。左邊先落一道小雷，人往下一沉再慢慢站回來；隔一陣子右邊那道大的再劈一次。'),
}


def delay(i, girl):
    return '-%.1fs' % ((i * 2.9 + (6.1 if girl else 0)) % LOOP)


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
page = page.replace(old, '定版。待機是「慢慢呼吸」（整個人升一格、停兩秒多、再回來），播放是一格 0.15 秒，一輪 14.4 秒做一次招牌動作。'
                         '平常另外有眨眼、葉子被風帶一下、道具自己的小動作和特效。背景、角色、特效分三層，背景不動。')
idle_tpl = page
page = page.replace('G 款第二版', 'G 款第六版')
W, H = 2790, 1560
page = (page.replace('__W__', str(W)).replace('__H__', str(H))
        .replace('__MEN__', row.replace('__SEX__', '男').replace('__LIST__', 'men'))
        .replace('__WOMEN__', row.replace('__SEX__', '女').replace('__LIST__', 'women'))
        .replace('__MJ__', json.dumps(cards('r', '男'), ensure_ascii=False))
        .replace('__WJ__', json.dumps(cards('gr', '女'), ensure_ascii=False)))
assert '<img' not in page and '__' not in page and 'G 款第六版' in page
write('IdleCards.dc.html', page)

# ---- 待機方式與速度的比較 ----
def pick(code, cls, title, sub, act, how, extra=''):
    realm, seal, bg, subc, who = REALM[int(code[-1])]
    return {'bg': bg, 'sub': subc, 'realm': title, 'seal': seal, 'who': sub, 'cls': ('st-' + cls + ' ' + extra).strip(), 'delay': '0s',
            'act': act, 'how': how, 'alt': '%s，%s' % (realm, title)}


STYLES = [('-still', '甲 身體不動', '沒選', '只有眨眼、葉子、道具和特效在動。做招牌動作時身體才會慢慢動一下。'),
          ('', '乙 慢慢呼吸', '選定，14 張都用這個', '除了甲的那些，身體每隔兩秒多往上升一格、停一下、再回來。像素圖沒辦法只動胸口，所以是整個人升一格。'),
          ('-sway', '丙 慢慢左右晃', '沒選', '除了甲的那些，身體慢慢往右移一格、回中間、往左移一格。看起來像在換腳站。')]
SPEEDS = [('sp10', '快：一格 0.1 秒', '沒選・一輪 9.6 秒', '前幾版的速度。'),
          ('', '中：一格 0.15 秒', '選定・一輪 14.4 秒', '14 張用的速度。'),
          ('sp20', '慢：一格 0.2 秒', '沒選・一輪 19.2 秒', '再慢一點。動作會比較一格一格的。')]
srow = row
spage = (idle_tpl.replace('G 款第二版：14 張各自的待機動作', '待機時身體要不要動、播多快')
         .replace(old, '你選了「乙 慢慢呼吸」和「中」速，14 張已經照這個做。這張留著當紀錄：上面兩列是同一個角色的三種待機方式，最下面一列是同一條動畫用三種速度播。'))
SW_, SH_ = 56 * 2 + 56 + 24 + 3 * 350 + 3 * 24, 56 * 2 + 150 + 3 * (516 + 150 + 28)
spage = (spage.replace('__W__', str(SW_)).replace('__H__', str(SH_))
         .replace('__MEN__', srow.replace('__SEX__', '煉氣').replace('__LIST__', 'a'))
         .replace('__WOMEN__', srow.replace('__SEX__', '元嬰').replace('__LIST__', 'b') + '\n' + srow.replace('__SEX__', '速度').replace('__LIST__', 'c'))
         .replace('men: __MJ__,\nwomen: __WJ__',
                  'a: %s,\nb: %s,\nc: %s' % tuple(json.dumps(x, ensure_ascii=False) for x in (
                      [pick('r0', 'r0' + t, title, sub, '掂水桶', how) for t, title, sub, how in STYLES],
                      [pick('r3', 'r3' + t, title, sub, '拄杖點地', how) for t, title, sub, how in STYLES],
                      [pick('r1', 'r1', title, sub, '舉劍下劈（乙）', how, sp) for sp, title, sub, how in SPEEDS]))))
assert '<img' not in spage and '__' not in spage and '第二版' not in spage
write('IdleStyles.dc.html', spage)

# ---- 煉氣男拆成零件（試做）----
TILE = ('<sc-for list="{{layers}}" as="t" hint-placeholder-count="8">\n'
        '<div style="width: 252px; display: flex; flex-direction: column; gap: 8px">\n'
        '<div style="width: 252px; height: 315px; border-radius: 12px; overflow: hidden; background: #3A3A44">'
        '<img src="{{t.src}}" alt="{{t.name}}" style="display: block; width: 252px; height: 315px; image-rendering: pixelated"></div>\n'
        '<div style="font-family: \'LXGW WenKai TC\', \'Kaiti TC\', serif; font-weight: 700; font-size: 20px; line-height: 1.3; color: #5E4410">{{t.name}}</div>\n'
        '<div style="font-size: 14px; line-height: 1.5; color: #5F5F66">{{t.note}}</div>\n'
        '</div>\n</sc-for>')
PW, PH = 56 * 2 + 8 * 252 + 7 * 16, 1250
prow = row.replace('__SEX__', '比較').replace('__LIST__', 'cards')
ppage = (idle_tpl.replace('G 款第二版：14 張各自的待機動作', '煉氣男拆成零件（試做）')
         .replace(old, '照著同一張像素圖，把煉氣男拆成八層：背景、腿、手臂、頭、身體、水桶、兩片葉子。被擋住的地方（脖子、衣襬底下的腿、袖口裡的手臂）是從旁邊的格子接著補的。'
                       '左邊是現在整塊移動的版本，右邊是零件版，多了三個動作：頭會歪一下、頭比身體晚一點跟上、手臂繞肩膀擺。2026-11-16 決定先不採用，14 張定版用整塊移動的第六版；這張留著當紀錄。')
         .replace('__W__', str(PW)).replace('__H__', str(PH))
         .replace('__MEN__', prow)
         .replace('__WOMEN__', '<div style="font-family: \'LXGW WenKai TC\', \'Kaiti TC\', serif; font-size: 28px; line-height: 1.3; color: #7A5916">拆出來的八層（由下往上疊）</div>\n'
                               '<div style="display: flex; gap: 16px; align-items: flex-start">\n' + TILE + '\n</div>')
         .replace('men: __MJ__,\nwomen: __WJ__', 'cards: %s,\nlayers: %s' % (
             json.dumps([pick('r0', 'r0', '整塊移動', '現在 14 張的做法', '掂水桶', '頭、手、衣服是同一塊，只能一起平移。提桶時是整隻手臂往上平移。'),
                         pick('r0', 'r0-parts', '拆成零件', '試做', '掂水桶', '頭會歪向桶那邊看，呼吸時頭晚一點才跟上。提桶時手臂繞肩膀往外擺，桶垂在手上晃。')], ensure_ascii=False),
             json.dumps([{'name': n, 'src': '/_blob/' + i, 'note': t} for n, i, t in LAYERS], ensure_ascii=False))))
assert '__' not in ppage and '第二版' not in ppage
write('PartsDemo.dc.html', ppage)

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
c['boards']['IdleCards.dc.html'].update({'w': W, 'h': H, 'title': 'G 款第六版：14 張各自的待機動作（定版）'})
c['boards']['RealmDark.dc.html']['title'] = '七個境界的深色卡（底色定案）'
c['boards']['IdleStyles.dc.html'] = {'x': 5670, 'y': 5460, 'w': SW_, 'h': SH_, 'title': '待機時身體要不要動、播多快（已選：乙、中速）'}
c['boards']['IdleStyles.dc.html']['title'] = '待機時身體要不要動、播多快（已選：乙、中速）'
c['boards']['PartsDemo.dc.html'] = {'x': 2800, 'y': 7140, 'w': PW, 'h': PH, 'title': '煉氣男拆成零件（試做，先不採用）'}
if 'PartsDemo.dc.html' not in c['order']:
    c['order'].insert(c['order'].index('IdleCards.dc.html') + 1, 'PartsDemo.dc.html')
if 'IdleStyles.dc.html' not in c['order']:
    c['order'].insert(c['order'].index('IdleCards.dc.html') + 1, 'IdleStyles.dc.html')
c['boards']['ColorCands.dc.html'].update({'w': CW, 'h': CH, 'title': '化神、元嬰、大乘的底色候選（已選定）'})
io.open(cj, 'w', encoding='utf-8', newline='\n').write(json.dumps(c, ensure_ascii=False, separators=(',', ':')))
print('ok', W, H, CW, CH, len(CSS))
