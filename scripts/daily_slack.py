#!/usr/bin/env python3
"""오늘 할 일을 슬랙으로 보낸다. 매일 아침 배치가 돌린다.

보낼 게 «있을 때만» 보낸다 — 빈 알림은 보내지 않는다.
  · Shorts  오늘 편성 + 밀린 것
  · 공모주   오늘 청약 마감/시작 · 상장 · 환불 (마감이 제일 급하다)
  · 부동산   입찰일 D-7 이내 · 잔금·명도 기한
  · 모아타운 주민공람 공고 — 공람이 뜨면 통합심의 임박 = «마지막 매수 기회»

webhook 은 env.local.json 의 SLACK_WEBHOOK 에서 읽는다.
저장소는 공개이므로 코드에 넣지 않는다.

    python3 scripts/daily_slack.py           # 있으면 보낸다
    python3 scripts/daily_slack.py --dry     # 보내지 않고 화면에만
    python3 scripts/daily_slack.py --force   # 할 일이 없어도 보낸다
"""
import datetime
import json
import os
import re
import sys
import urllib.request as u

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
URL = 'https://rbksmjnfaqglnzypgxqa.supabase.co'
ANON = ('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6'
        'InJia3Ntam5mYXFnbG56eXBneHFhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU3MzIzNTMs'
        'ImV4cCI6MjEwMTMwODM1M30.v7a-ZkdHr0neEwRuZBveCROrs6J80bVeBFd2jN4LGUI')

CATS = {'fire': '🔥', 'film': '🎬', 'mind': '🤯',
        'data': '📈', 'trophy': '🏆', 'swap': '🔄'}


def env():
    with open(os.path.join(HERE, 'env.local.json')) as f:
        return json.load(f)


def login(e):
    req = u.Request(URL + '/auth/v1/token?grant_type=password',
                    data=json.dumps({'email': e['AUTO_EMAIL'],
                                     'password': e['AUTO_PASSWORD']}).encode(),
                    headers={'apikey': ANON, 'Content-Type': 'application/json'})
    return json.loads(u.urlopen(req).read())['access_token']


def get(path, token):
    req = u.Request(URL + path,
                    headers={'apikey': ANON, 'Authorization': f'Bearer {token}'})
    try:
        return json.loads(u.urlopen(req).read())
    except Exception as ex:  # noqa: BLE001 — 한 섹션이 실패해도 나머지는 보낸다
        print(f'  조회 실패 {path}: {ex}', file=sys.stderr)
        return []


def won(n):
    """1억 2,300만 꼴로."""
    n = int(n or 0)
    if n <= 0:
        return ''
    eok, rest = divmod(n, 100_000_000)
    man = rest // 10_000
    if eok and man:
        return f'{eok}억 {man:,}만'
    if eok:
        return f'{eok}억'
    return f'{man:,}만'


def build(token, today):
    """섹션 목록을 만든다. 비어 있으면 보낼 게 없다는 뜻."""
    lines = []

    # ── 공모주: 마감이 제일 급하다 ──────────────────────────
    ipo = get('/rest/v1/ipo_subscriptions?select=name,broker,sub_start,sub_end,'
              'refund_date,listing_date,band_low,band_high,shares', token)
    tomorrow = (datetime.date.fromisoformat(today) +
                datetime.timedelta(days=1)).isoformat()
    ipo_lines = []
    for r in ipo:
        who = ' · '.join(x for x in [r['name'], r.get('broker')] if x)
        band = ''
        if r.get('band_low') or r.get('band_high'):
            band = f" · {int(r.get('band_low') or 0):,}~{int(r.get('band_high') or 0):,}원"
        if r.get('sub_end') == today:
            ipo_lines.append(f'🚨 *오늘 청약 마감* — {who}{band}')
        elif r.get('sub_start') == today:
            end = r.get('sub_end')
            ipo_lines.append(
                f'▶️ 오늘 청약 시작 — {who}{band}' + (f' (마감 {end})' if end else ''))
        elif r.get('sub_start') and r.get('sub_end') \
                and r['sub_start'] < today < r['sub_end']:
            ipo_lines.append(f'⏳ 청약중 (마감 {r["sub_end"]}) — {who}{band}')
        elif r.get('sub_start') == tomorrow:
            ipo_lines.append(f'📅 내일 청약 시작 — {who}{band}')
        if r.get('listing_date') == today:
            ipo_lines.append(f'📈 오늘 상장 · 매도 판단 — {who}')
        if r.get('refund_date') == today:
            ipo_lines.append(f'💸 오늘 환불 — {who}')
    if ipo_lines:
        lines.append(('💰 공모주', ipo_lines))

    # ── Shorts ─────────────────────────────────────────────
    slots = get(f'/rest/v1/shorts_slots?slot_date=eq.{today}&select=*', token)
    s_lines = []
    for r in slots:
        mark = '✅' if r['done'] else CATS.get(r['cat'], '•')
        top = ' *(우선)*' if str(r.get('prio')) == '5' else ''
        s_lines.append(f'{mark} {r["title"]}{top}')
        if r.get('hook'):
            s_lines.append(f'    _{r["hook"]}_')
        if r.get('url'):
            s_lines.append(f'    <{r["url"]}|출처 열기>')
    late = get(f'/rest/v1/shorts_slots?slot_date=lt.{today}&done=is.false'
               '&select=slot_date,title&order=slot_date', token)
    if late:
        s_lines.append(f'⚠️ 밀린 것 {len(late)}건 — ' +
                       ', '.join(f'{x["slot_date"][5:]} {x["title"][:18]}'
                                 for x in late[:3]))
    if s_lines:
        lines.append(('🎬 Shorts', s_lines))

    # ── 부동산: 지켜야 할 날짜 ──────────────────────────────
    # 입찰일뿐 아니라 «잔금»과 «명도»도 본다.
    # 잔금 기한을 넘기면 입찰보증금을 몰수당한다 — 제일 무서운 날짜라
    # 더 일찍(D-21)부터, 지난 것도 계속 알린다.
    props = get('/rest/v1/auction_properties?select=title,status,bid_date,'
                'balance_due,evict_due,min_price,deposit,acquisition,excluded'
                '&order=bid_date', token)
    d0 = datetime.date.fromisoformat(today)
    p_lines = []
    for r in props:
        if r.get('excluded') or r.get('status') in ('sold', 'pass'):
            continue

        # 입찰 — D-7 이내
        if r.get('bid_date'):
            d = (datetime.datetime.fromisoformat(
                r['bid_date'].replace('Z', '+00:00')).date() - d0).days
            if 0 <= d <= 7:
                dep = won(r.get('deposit') or (r.get('min_price') or 0) * 0.1)
                tag = '오늘 입찰' if d == 0 else f'D-{d}'
                p_lines.append(f'⚖️ *{tag}* — {r["title"][:40]}'
                               + (f' · 보증금 {dep}원' if dep else ''))

        # 잔금 — D-21 이내 + 기한 지난 것
        if r.get('balance_due'):
            d = (datetime.date.fromisoformat(r['balance_due']) - d0).days
            if d < 0:
                p_lines.append(
                    f'🚨 *잔금 기한 {-d}일 지남* — {r["title"][:40]} · 보증금 몰수 위험')
            elif d <= 21:
                tag = '오늘이 잔금 기한' if d == 0 else f'잔금 D-{d}'
                p_lines.append(f'💳 *{tag}* — {r["title"][:40]}')

        # 명도 — D-7 이내 + 지난 것
        if r.get('evict_due'):
            d = (datetime.date.fromisoformat(r['evict_due']) - d0).days
            if d < 0:
                p_lines.append(
                    f'🔑 명도 목표일 {-d}일 지남 — {r["title"][:40]}')
            elif d <= 7:
                tag = '오늘 명도' if d == 0 else f'명도 D-{d}'
                p_lines.append(f'🔑 {tag} — {r["title"][:40]}')

    if p_lines:
        lines.append(('🏠 부동산', p_lines))

    # ── 모아타운 공람 공고 ──────────────────────────────────
    # 공람이 뜨면 통합심의가 임박했다는 신호다 = 마지막 매수 기회.
    # 외부 포털을 보므로 실패해도 나머지는 보낸다.
    try:
        import moa_notice
        zones = get('/rest/v1/zones?select=name,stage', token)
        by = {}
        for z in zones:
            m = re.search(r'([가-힣]+)\d*동\s*([0-9]+(?:-[0-9]+)?)', z['name'])
            if m:
                by[f'{m.group(1)}동 {m.group(2)}'] = z
        m_lines = moa_notice.slack_lines(today, by)
        if m_lines:
            lines.append(('🏘️ 모아타운 공람', m_lines))
    except Exception as ex:  # noqa: BLE001
        print(f'  공람 조회 실패: {ex}', file=sys.stderr)

    return lines


def main():
    dry = '--dry' in sys.argv
    force = '--force' in sys.argv
    e = env()
    token = login(e)
    today = datetime.date.today().isoformat()
    sections = build(token, today)

    if not sections and not force:
        print(f'{today} — 보낼 것 없음 (슬랙 미발송)')
        return

    wd = ['월', '화', '수', '목', '금', '토', '일'][
        datetime.date.fromisoformat(today).weekday()]
    md = [f'*{today[5:].replace("-", "/")} ({wd}) 오늘 할 일*']
    for title, rows in sections:
        md.append('')
        md.append(f'*{title}*')
        md.extend(rows)
    if not sections:
        md.append('')
        md.append('_오늘은 예정된 것이 없습니다._')
    text = '\n'.join(md)

    if dry:
        print(text)
        return

    hook = e.get('SLACK_WEBHOOK') or os.environ.get('SLACK_WEBHOOK')
    if not hook:
        sys.exit('SLACK_WEBHOOK 이 env.local.json 에 없습니다')
    req = u.Request(hook, data=json.dumps({'text': text}).encode(),
                    headers={'Content-Type': 'application/json'})
    try:
        with u.urlopen(req) as r:
            print(f'슬랙 전송 {r.status} · 섹션 {len(sections)}개')
    except Exception as ex:  # noqa: BLE001
        body = ex.read().decode() if hasattr(ex, 'read') else str(ex)
        sys.exit(f'슬랙 전송 실패: {body[:200]}')


if __name__ == '__main__':
    main()
