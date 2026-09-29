#!/usr/bin/env python3
"""모아타운 «주민공람 공고» 감시.

공람이 뜨면 «통합심의가 임박»했다는 신호다 — 그 뒤에 관리계획 고시가 나고
값이 뛴다. 즉 «공람 = 마지막 매수 기회»다.
(자료실 「서울투자반 교안」 — 후계공통승의 «공(공람)» 단계)

공람은 14일짜리라 매일 열려 있지 않다. 놓치면 다음 계단으로 넘어간다.
그래서 배치가 매일 훑는다.

출처: 서울도시공간포털 > 도시관리계획 > 열람공고(주민의견제출)
      POST /wrtanc/getWrtancList.json

    python3 scripts/moa_notice.py          # 화면에 출력
    python3 scripts/moa_notice.py --all    # 지난 것까지 전부
"""
import datetime
import json
import re
import sys
import urllib.request

API = "https://urban.seoul.go.kr/wrtanc/getWrtancList.json"

# 제목에 이게 들어가면 모아타운 관련으로 본다.
PAT = re.compile(r'모아|소규모주택정비')

# 새로 떴다고 볼 기간 · 마감 임박으로 볼 기간 (일)
NEW_DAYS = 3
SOON_DAYS = 3


def fetch():
    req = urllib.request.Request(
        API, method="POST",
        data=json.dumps({"pageSize": 5000}).encode(),
        headers={"Content-Type": "application/json",
                 "User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read()).get("content") or []


def _d(v):
    return (v or "")[:10]


def notices(today):
    """모아 관련 공람 공고를 (구분, 자치구, 제목, 시작, 마감, 남은일) 로."""
    d0 = datetime.date.fromisoformat(today)
    out = []
    for x in fetch():
        title = (x.get("title") or "").strip()
        if not PAT.search(title):
            continue
        bgn, end = _d(x.get("readingDateBgn")), _d(x.get("readingDateEnd"))
        if not end:
            continue
        gu = ((x.get("dept") or {}).get("insttName") or "").strip()
        left = (datetime.date.fromisoformat(end) - d0).days
        started = (d0 - datetime.date.fromisoformat(bgn)).days if bgn else 99

        if 0 <= started <= NEW_DAYS and left >= 0:
            kind = 'new'      # 막 떴다 — 지금이 마지막 매수 기회
        elif 0 <= left <= SOON_DAYS:
            kind = 'soon'     # 곧 닫힌다
        elif left >= 0:
            kind = 'open'     # 공람 중
        else:
            continue
        out.append((kind, gu, title, bgn, end, left))
    out.sort(key=lambda t: t[5])
    return out


# 공고 제목에서 «어디»를 뗀다 — 「사당동 202-29번지 일대」
_WHERE = re.compile(r'[가-힣]+\d*동\s*[0-9]+(?:-[0-9]+)?(?:번지)?(?:\s*(?:일대|일원))?')

# 내 구역 단계(모아 축) → 한 마디. lib/features/auction/buy_band.dart 의
# bandOfStage 와 같은 구간이다.
def _band(stage):
    s = stage or 0
    if s in (3, 4, 5):
        return '🟢 매수적기'
    if s in (7, 8):
        return '🟡 막차(조합설립 전)'
    if s >= 9:
        return '🚫 승계불가'
    return ''


def _md(d):
    """2026-09-17 → 9/17"""
    return f'{int(d[5:7])}/{int(d[8:10])}' if d else '?'


def _what(title):
    """공고가 «무엇»인지 짧게. 제목을 44자에서 자르면 「변경(안」처럼
    괄호 한가운데서 끊겨 깨진 것처럼 보였다 — 잘라 쓰지 않고 뜻만 뽑는다."""
    if '관리계획' in title:
        return '관리계획 변경' if '변경' in title else '관리계획 수립'
    t = re.sub(r'\([^)]*\)?', '', _WHERE.sub('', title))
    t = re.sub(r'\s+', ' ', t).strip(' ·-')
    return t if len(t) <= 30 else t[:30].rsplit(' ', 1)[0] + '…'


def slack_lines(today, zones_by_key=None):
    """daily_slack 이 쓰는 줄 목록. 없으면 빈 목록.

    한 공고 = 두 줄.
        ⏰ *공람 마감 D-1* · 동작구 사당동 202-29번지 일대
            관리계획 변경 · 9/17 → 10/1 · 🟢 매수적기

    날짜 사이에 「~」를 쓰지 않는다. 슬랙은 ~…~ 를 «취소선»으로 읽어서
    「2026-09-17~2026-10-01 … ~」 가 줄을 넘어 그어지며 깨져 보였다.
    """
    rows = notices(today)
    if not rows:
        return []
    lines = []
    for kind, gu, title, bgn, end, left in rows:
        when = '오늘 마감' if left == 0 else f'D-{left}'
        tag = {'new': f'🆕 *공람 시작* ({when})',
               'soon': f'⏰ *공람 마감 {when}*',
               'open': f'📄 공람 중 ({when})'}[kind]
        w = _WHERE.search(title)
        where = w.group(0) if w else _what(title)
        band = ''
        if zones_by_key:
            # 제목의 «동 + 번지» 로 내 구역과 맞춰본다
            m = re.search(r'([가-힣]+)\d*동\s*([0-9]+(?:-[0-9]+)?)', title)
            if m:
                z = zones_by_key.get(f'{m.group(1)}동 {m.group(2)}')
                if z and _band(z.get('stage')):
                    band = ' · ' + _band(z.get('stage'))
        lines.append(f'{tag} · {gu} {where}'.replace('  ', ' '))
        detail = _what(title) if w else ''
        lines.append('    ' + ' · '.join(
            x for x in [detail, f'{_md(bgn)} → {_md(end)}'] if x) + band)
    return lines


def main():
    today = datetime.datetime.now(datetime.timezone(
        datetime.timedelta(hours=9))).date().isoformat()  # 러너는 UTC
    rows = notices(today)
    if '--all' in sys.argv:
        d0 = datetime.date.fromisoformat(today)
        rows = []
        for x in fetch():
            t = (x.get("title") or "").strip()
            if not PAT.search(t):
                continue
            bgn, end = _d(x.get("readingDateBgn")), _d(x.get("readingDateEnd"))
            gu = ((x.get("dept") or {}).get("insttName") or "").strip()
            left = ((datetime.date.fromisoformat(end) - d0).days
                    if end else -999)
            rows.append(('past' if left < 0 else 'open', gu, t, bgn, end, left))
        rows.sort(key=lambda r: r[4], reverse=True)
        rows = rows[:30]

    if not rows:
        print(f'{today} — 공람 중인 모아타운 공고 없음')
        print('  (공람은 14일짜리라 늘 열려 있지는 않다. 뜨면 배치가 알린다.)')
        return
    print(f'{today} — 모아타운 공람 {len(rows)}건')
    for kind, gu, title, bgn, end, left in rows:
        mark = {'new': '🆕', 'soon': '⏰', 'open': '📄', 'past': '  '}[kind]
        print(f'  {mark} {bgn}~{end} ({left:+3}d) {gu:8} {title[:56]}')


if __name__ == "__main__":
    main()
