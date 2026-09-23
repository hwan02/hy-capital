#!/usr/bin/env python3
"""서울시 «신속통합기획 온라인 아카이브»에서 신통 구역의 기획 단계를 가져온다.

【왜 필요했나】
신통 매수적기는 «선정 ~ 확정 전», 곧 아카이브에 「기획중」으로 떠 있는
구역이다. 기획이 확정되면 표에 «기획완료 날짜 + 링크»가 붙고, 그때부터는
매수적기가 아니다.

그런데 앱의 신통 단계는 서울도시공간포털(sync_moa_zones.py)에서만 왔고,
포털에는 「기획중」이라는 상태가 «없다». 선정된 구역은 기획이 끝날 때까지
전부 「대상지선정(3)」이고, 기획이 끝나도 한참 늦게 바뀐다. 그래서
  · 아카이브엔 기획중인데 앱엔 1·3 (독산동 1022·979, 구로동 739-7 …)
  · 아카이브엔 '25.8.27 기획완료인데 앱엔 4 (사당동 305-35)
처럼 양쪽으로 어긋나 있었다.

    https://news.seoul.go.kr/citybuild/plan-{downtown,northeast,northwest,southeast,southwest}

권역 페이지마다 「<강서구>」 같은 제목 아래 표가 있고, 한 행은
    ■ 구역명 | 위치(일대) | 기획완료('23.1.31.) 또는 「기획중」 | 링크 또는 -

【반영 규칙】
· 기획중 → 4(기획 중), 기획완료 → 5(기획 완료).
· 단계는 «올리기만» 한다. 6(정비구역 지정고시) 이상은 건드리지 않는다 —
  아카이브는 기획까지만 안다.
· 앱에 없는 «기획중» 구역은 추가한다 — 매수적기 후보를 놓치면 안 된다.
  «기획완료»는 추가하지 않는다. 못 붙은 건 대개 이름 표기만 다른 기존
  구역이라 만들면 중복이 된다(2026-09-23 중복 19건을 정리했다).

    python3 scripts/sync_sin_archive.py --dry     # 아카이브 표만 화면에
    python3 scripts/sync_sin_archive.py           # 반영 (매일 배치)
"""
import datetime
import html
import os
import re
import sys
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from import_moa_pdf import (_parts, app_password, login,  # noqa: E402
                            open_retry, report, sb)

BASE = "https://news.seoul.go.kr/citybuild/"
PAGES = ["plan-downtown", "plan-northeast", "plan-northwest",
         "plan-southeast", "plan-southwest"]
SRC = "서울시 신통 아카이브"

_HEAD = re.compile(r'&lt;\s*([가-힣]+구)\s*&gt;')
_ROW = re.compile(r'<tr>(.*?)</tr>', re.S)
_TD = re.compile(r'<td[^>]*>(.*?)</td>', re.S)


def _text(s):
    return re.sub(r'\s+', ' ', html.unescape(re.sub(r'<[^>]+>', ' ', s))).strip()


def parse(page_html):
    """권역 페이지 → [{gu, name, loc, state('기획중'|'기획완료'), done, link}]."""
    out = []
    heads = [(m.start(), m.group(1)) for m in _HEAD.finditer(page_html)]
    for i, (pos, gu) in enumerate(heads):
        end = heads[i + 1][0] if i + 1 < len(heads) else len(page_html)
        chunk = page_html[pos:end]
        for tr in _ROW.findall(chunk):
            tds = _TD.findall(tr)
            if len(tds) < 3:
                continue                      # 머리행(th)
            name = _text(tds[0]).lstrip('■').strip()
            loc = _text(tds[1])
            done = _text(tds[2])
            link = re.search(r'href="([^"]+)"', tds[3]) if len(tds) > 3 else None
            if re.match(r"'\d", done):
                state = '기획완료'
            elif '기획' in done and '중' in done:
                state = '기획중'
            else:
                continue
            out.append({'gu': gu, 'name': name, 'loc': loc, 'state': state,
                        'done': done if state == '기획완료' else '',
                        'link': link.group(1) if link else ''})
    return out


def fetch_all():
    rows = []
    for p in PAGES:
        req = urllib.request.Request(BASE + p, headers={'User-Agent': 'Mozilla/5.0'})
        try:
            rows += parse(open_retry(req).decode('utf-8', 'ignore'))
        except Exception as ex:  # noqa: BLE001  한 권역이 죽어도 나머지는 본다
            print(f"  «{p}» 조회 실패: {ex}", file=sys.stderr)
    return rows


CLEANUP_SEL = "https://cleanup.seoul.go.kr/cleanup/view/publicIntgrPlanArea.do"
CLEANUP_PRG = "https://cleanup.seoul.go.kr/cleanup/view/publicIntgrPlanSttn.do"


def _get(url):
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    return open_retry(req).decode('utf-8', 'ignore')


def _lines(page):
    t = re.sub(r'<script.*?</script>|<style.*?</style>|<!--.*?-->', '', page, flags=re.S)
    return [x.strip() for x in html.unescape(re.sub(r'<[^>]+>', '\n', t)).split('\n')
            if x.strip()]


def cleanup_selected(page):
    """정비몽땅 「재개발 공모 선정구역」 → [{when, gu, loc}]. 취소현황은 뺀다.

    회차 제목(1차 공모 · ’25년 수시선정구역(’25. 12월) …) 아래에
    「구역 표기 / 위치도 / 현황 / 구역면적 …」이 반복된다. 「위치도」 바로 앞
    줄이 구역이다. 제목에 월이 없는 회차(’26년)는 연도만 적는다.
    """
    L = _lines(page)
    cur, out = None, []
    for i, x in enumerate(L):
        if x.startswith('취소현황'):
            break
        if x.startswith('1차 공모 선정구역'):
            cur = '2021-12'
        elif x.startswith('2차 공모 선정구역'):
            cur = '2022-12'
        elif '수시선정구역' in x:
            y = re.search(r'’(\d\d)년', x)
            m = re.search(r'(\d{1,2})\s*월', x) or re.search(r'’\d\d\.\s*(\d{1,2})\.', x)
            if y:
                cur = f"20{y.group(1)}" + (f"-{int(m.group(1)):02d}" if m else '')
        if x == '위치도' and cur and i:
            raw = L[i - 1]
            m = (re.match(r'^\(?\s*([가-힣]{1,4}구)\s*\)?\s*(.+)$', raw)
                 or re.search(r'\(([가-힣]{1,4}구)\s+(.+?)\)', raw))
            gu, loc = (m.group(1), m.group(2)) if m else ('', raw)
            inner = re.search(r'\(([^)]*\d[^)]*)\)', loc)      # 「면목7구역(면목동 69-14일대)」
            out.append({'when': cur, 'gu': gu, 'name': raw,
                        'loc': inner.group(1) if inner and not m else loc})
    return out


# 「확정 이상」으로 볼 정비몽땅 추진현황 표현. 가이드라인 수립 = 기획 확정.
_PRG_DONE = re.compile(r'가이드라인|구역\s*지정|통심\s*완료|시행자\s*지정|조합설립')


def cleanup_done(page):
    """정비몽땅 「추진현황」 → 확정 이상인 구역 [{gu, name, why}].

    표가 두 개다(구역지정 이후 / 기획 단계). 둘 다 주석(<!-- -->) 안에도
    행이 있어 주석을 벗기고 읽는다. 이 표도 늦게 바뀐다 — 확정 «신호»로만 쓴다.
    """
    page = page.replace('<!--', '').replace('-->', '')
    out = []
    for tr in re.findall(r'<tr[^>]*>(.*?)</tr>', page, re.S):
        tds = [_text(x) for x in re.findall(r'<td[^>]*>(.*?)</td>', tr, re.S)]
        if len(tds) < 6 or not tds[1].endswith('구'):
            continue
        rest = ' '.join(tds[5:])
        if _PRG_DONE.search(rest):
            out.append({'gu': tds[1], 'name': tds[2], 'loc': tds[2],
                        'why': re.sub(r'\s+', ' ', rest)[:40]})
    return out


def dong_to_gu(zones):
    """앱 구역들에서 «동 → 자치구»를 배운다. 정비몽땅 ’26년 목록은 구가 없다."""
    m = {}
    for z in zones:
        d = _parts(z['name'])[0]
        if d and z.get('district'):
            m.setdefault(d, z['district'])
    return m


def _norm(s):
    """이름 비교용 — 「흑석10구역」과 「흑석10」, 「舊 신당10」과 「신당10구역」."""
    return re.sub(r'[\s·,()舊]|구역|일대|일원|번지|아파트|주택재개발사업', '', s or '')


def match(row, zones):
    """아카이브 한 행 → 앱의 신통 구역(같은 자치구). 못 찾으면 None.

    ① 이름이 같다   ② 위치의 (동, 번지)가 구역명의 (동, 번지)와 같다
    ③ 위치 번지가 그 구역의 포함 번지(aliases)에 있다
    """
    mine = [z for z in zones if (z.get('district') or '') == row['gu']]
    n = _norm(row['name'])
    for z in mine:
        if n and _norm(z['name']) == n:
            return z
    d, l = _parts(row['loc'])
    if l:
        for z in mine:
            if _parts(z['name']) == (d, l):
                return z
        for z in mine:
            # 구역명에 번지가 없으면(「삼선3구역」) 동을 비교할 수 없다 —
            # 포함 번지만으로 붙인다. 번지가 있으면 동도 같아야 한다.
            zd, zl = _parts(z['name'])
            if l in (z.get('aliases') or []) and (not zl or zd == d):
                return z
    # 「정릉 898-16」 「신월 5-72」처럼 동 글자가 빠진 표기 — 같은 구에서
    # 그 번지를 가진 구역이 «하나뿐»일 때만 붙인다.
    lot = re.search(r'(\d+-\d+|\d{2,})', row['loc'] or '')
    if lot:
        lot = lot.group(1)
        c = [z for z in mine if lot == _parts(z['name'])[1] or lot in (z.get('aliases') or [])]
        if len(c) == 1:
            return c[0]
    return None


def match_all(row, zones):
    """한 행에 구역이 둘 이상 묶인 경우(「미아동 258, 번동 148 일대」)까지."""
    found = []
    z = match(row, zones)
    if z:
        found.append(z)
    parts = [p.strip() for p in re.split(r'[,·]', row['name']) if p.strip()]
    if len(parts) > 1:
        for p in parts:
            if not _parts(p)[1]:
                continue                      # 번지 없는 조각(「3」「4」)은 못 믿는다
            zz = match({**row, 'name': p, 'loc': p}, zones)
            if zz and zz not in found:
                found.append(zz)
    return found


# 「확정」 신호 단어. 아카이브는 확정 뒤 며칠~몇 주 늦게 바뀐다.
_DONE = re.compile(r'확정|가이드라인|기획\s*완료|기획안\s*(수립|마련)')


def done_signals(rows, zones, tok, days=21):
    """아카이브엔 «기획중»인데 기사에 «확정»이 뜬 구역.

    자동으로 바꾸지 않는다 — 기사 제목만으로 단계를 올리면 틀릴 수 있다.
    판단은 서울시보·정비몽땅으로 사람이 하고, 여기선 «확인 필요»만 알린다.
    기사는 news_digest(매일 슬랙으로 보낸 기사 기록)에서 찾는다 —
    전문지가 확정 당일 기사를 내므로 가장 빠르다.
    """
    since = (datetime.date.today() - datetime.timedelta(days=days)).isoformat()
    try:
        news = sb("/rest/v1/news_digest?select=title,url,published_on"
                  f"&published_on=gte.{since}", token=tok) or []
    except Exception as ex:  # noqa: BLE001
        print(f"  기사 조회 실패: {ex}", file=sys.stderr)
        return []
    out = []
    for r in rows:
        if r['state'] != '기획중':
            continue
        d, l = _parts(r['loc'])
        keys = {k for k in (_norm(r['name']), f"{d.replace('동', '')}{l}" if l else '') if k}
        for n in news:
            t = n.get('title') or ''
            tn = _norm(t).replace('동', '')
            if _DONE.search(t) and any(k.replace('동', '') in tn for k in keys):
                out.append((r, n))
                break
    return out


def main():
    dry = '--dry' in sys.argv
    rows = fetch_all()
    ing = [r for r in rows if r['state'] == '기획중']
    print(f"{SRC} — {len(rows)}곳 (기획중 {len(ing)} · 기획완료 {len(rows) - len(ing)})")

    if dry and not app_password():
        for r in ing:
            print(f"  기획중  {r['gu']:5} {r['name'][:24]:26} {r['loc']}")
        print("\n(구역 대조는 키체인이나 HY_PASSWORD 가 필요하다.)")
        return

    tok, _ = login()
    zones = sb("/rest/v1/zones?select=id,name,district,stage,aliases,stage_source"
               "&kind=eq.신통기획", token=tok)

    now = datetime.datetime.now(datetime.timezone.utc)
    kst_day = (now + datetime.timedelta(hours=9)).date().isoformat()
    raised = same = 0
    missing = []
    added = 0
    uid = None
    for r in rows:
        target = 5 if r['state'] == '기획완료' else 4
        tag = f"기획완료 {r['done']}" if target == 5 else "기획중"
        src = (f"{SRC} «{tag}» · {r['name']} · {r['loc']}"
               + (f" · {r['link']}" if r['link'] else '') + f" (동기화 {kst_day})")
        found = match_all(r, zones)
        if not found:
            # 기획중인데 앱에 없다 = «매수적기 후보를 놓치고 있다». 추가한다.
            # 기획완료는 추가하지 않는다 — 매수적기가 아니고, 못 붙은 건 대개
            # 이름 표기만 다른 기존 구역이라 추가하면 중복이 된다.
            if r['state'] == '기획중':
                lot = _parts(r['loc'])[1]
                print(f"  ＋ [4] {r['gu']:5} {r['name'][:28]:30} (기획중 — 앱에 없음)")
                if not dry:
                    if uid is None:
                        uid = sb("/auth/v1/user", token=tok)['id']
                    sb("/rest/v1/zones", "POST", [{
                        'user_id': uid, 'name': r['name'], 'kind': '신통기획',
                        'district': r['gu'], 'stage': 4, 'stage_source': src,
                        'stage_checked_at': now.isoformat(),
                        'aliases': [lot] if lot else [],
                        'memo': '지금 진행 중 — 기획 중(선정~확정 전) — 매수적기',
                    }], token=tok)
                    report('신통 아카이브', f"＋ 새 구역 {r['gu']} {r['name'][:30]} (기획중 — 매수적기)")
                added += 1
            else:
                missing.append(r)
            continue
        for z in found:
            cur = z['stage'] or 0
            if cur >= 6 or cur >= target:
                same += 1
                continue
            print(f"  ↑ [{cur}→{target}] {r['gu']:5} {z['name'][:28]:30} ({tag})")
            if not dry:
                sb(f"/rest/v1/zones?id=eq.{z['id']}", "PATCH",
                   {'stage': target, 'stage_source': src,
                    'stage_checked_at': now.isoformat()}, token=tok)
                report('신통 아카이브', f"↑ {z['name'][:30]} — 단계 {cur}→{target} ({tag})")
            z['stage'] = target
            raised += 1

    # ── 정비몽땅: «확정 이상» 가리기 ─────────────────────────
    # 매수적기 = 선정 ~ 확정 전. 확정됐는데 3·4 로 남아 있으면 매수적기에 섞인다.
    try:
        done = cleanup_done(_get(CLEANUP_PRG))
    except Exception as ex:  # noqa: BLE001
        print(f"  정비몽땅 추진현황 조회 실패: {ex}", file=sys.stderr)
        done = []
    for r in done:
        z = match(r, zones)
        if not z or (z['stage'] or 0) >= 5:
            continue
        print(f"  ↑ [{z['stage']}→5] {r['gu']:5} {z['name'][:28]:30} (정비몽땅 «{r['why']}»)")
        if not dry:
            sb(f"/rest/v1/zones?id=eq.{z['id']}", "PATCH",
               {'stage': 5, 'stage_checked_at': now.isoformat(),
                'stage_source': f"정비몽땅 추진현황 «{r['why']}» · {r['name']} "
                                f"— 확정 이상 (동기화 {kst_day})"}, token=tok)
            report('신통 아카이브', f"↑ {z['name'][:30]} — 단계 {z['stage']}→5 "
                                    f"(정비몽땅 {r['why'][:20]})")
        z['stage'] = 5
        raised += 1

    # ── 정비몽땅: 선정됐는데 앱에서 못 찾은 구역 — «출력만» ─────────
    # 자동으로 추가하지 않는다. 정비몽땅 표기(「신림동 610-200일대」)와 앱
    # 이름(「신림10구역」)이 달라 못 붙은 게 대부분이고, 이미 확정된 곳도
    # 섞여 있다(독산동 1036·1072 = 독산1·2구역). 2026-09-23 드라이런에서
    # 31곳 중 대부분이 그랬다 — 넣으면 중복 19건 정리한 게 도로 생긴다.
    try:
        sel = cleanup_selected(_get(CLEANUP_SEL))
    except Exception as ex:  # noqa: BLE001
        print(f"  정비몽땅 선정구역 조회 실패: {ex}", file=sys.stderr)
        sel = []
    d2g = dong_to_gu(zones)
    done_keys = {(r['gu'], _parts(r['loc'])) for r in done}
    arch_done = {(r['gu'], _parts(r['loc'])) for r in rows if r['state'] == '기획완료'}
    unseen = []
    for r in sel:
        gu = r['gu'] or d2g.get(_parts(r['loc'])[0], '')
        if match_all({**r, 'gu': gu}, zones):
            continue
        if (gu, _parts(r['loc'])) in done_keys | arch_done:
            continue
        unseen.append((r['when'], gu or '?', r['loc']))
    if unseen:
        print(f"\n  정비몽땅 선정 중 앱에서 못 찾은 {len(unseen)}곳 (이름 표기 차이 가능 — 추가 안 함)")
        for w, g, l in unseen:
            print(f"    {w:7} {g:5} {l[:30]}")

    # ── 중복 의심 — 지우지 않고 출력만 ─────────────────────────
    # 이름 표기만 다른 같은 구역(흑석10 ↔ 흑석10구역)은 매수적기에 두 번 뜬다.
    # 삭제는 되돌릴 수 없으니 사람이 확인한다.
    seen = {}
    for z in zones:
        if not z.get('id'):
            continue
        k = (z.get('district'), _norm(z['name']))
        if k[1] and k in seen:
            # 매일 같은 줄이 슬랙에 반복되면 소음이라 출력만 한다.
            print(f"  ⚠ 중복 의심 — {z['district']} «{seen[k]['name']}» ↔ «{z['name']}»")
        else:
            seen[k] = z

    # 아카이브가 늦는 경우 — 기사엔 확정이 떴는데 표는 아직 기획중.
    for r, n in done_signals(rows, zones, tok):
        msg = (f"⚠ 확인 필요 — {r['name'][:26]} : 아카이브는 «기획중»인데 "
               f"기사에 확정 신호 «{(n.get('title') or '')[:40]}» → 서울시보·정비몽땅 확인")
        print("  " + msg)
        if not dry:
            report('신통 아카이브', msg)

    print(f"\n{'[--dry] ' if dry else ''}단계 상향 {raised} · 새 구역 {added} · "
          f"그대로 {same} · 못 붙음(기획완료) {len(missing)}")
    for r in missing:
        print(f"  ? {r['state']:4} {r['gu']:5} {r['name'][:24]:26} {r['loc']}")


if __name__ == "__main__":
    main()
