#!/usr/bin/env python3
"""모아타운·신속통합기획 기사를 모아 «새 것만» 골라낸다.

아침 슬랙에 뉴스가 한 줄도 안 나오던 이유는 단순하다 — 수집하는 코드가
아예 없었다. news_digest 표는 있었지만 앱에서 손으로 링크를 넣는 용도였다.

출처는 «구글 뉴스 RSS». 키가 필요 없고, 매체를 가리지 않고 긁는다.
    https://news.google.com/rss/search?q=<검색어>&hl=ko&gl=KR&ceid=KR:ko

중복은 news_digest.url 로 막는다(unique). 한 번 보낸 기사는 다시 안 보낸다.

    python3 scripts/news_watch.py --dry    # 새 기사만 화면에
    python3 scripts/news_watch.py          # 저장까지 (daily_slack 이 부른다)
"""
import datetime
import html
import json
import re
import sys
import urllib.parse
import urllib.request as u

RSS = 'https://news.google.com/rss/search?q={q}&hl=ko&gl=KR&ceid=KR:ko'

# 무엇을 찾을 것인가. 값은 앱의 topic 으로 그대로 들어간다.
#
# 「모아타운」·「신속통합기획」만 걸면 서울시 전체 기사가 쏟아진다. 정작
# 필요한 건 «내 구역에 무슨 일이 생겼나»라서, 절차가 움직였다는 신호
# (공람·심의·고시·조합설립)를 붙인 검색어를 같이 돌린다.
# 「모아타운」·「신속통합기획」 두 개면 각각 100건씩 와서 사실상 다 덮는다.
# 검색어를 8개까지 늘렸더니 구글이 스로틀을 걸어 배치가 멈췄다 —
# 넓은 것 2개 + 놓치면 안 되는 신호 2개만 남긴다.
QUERIES = [
    ('모아타운', '모아타운'),
    ('모아타운 주민공람', '모아타운'),   # 공람 = 통합심의 임박 = 마지막 매수 기회
    ('신속통합기획', '신통기획'),
    ('신속통합기획 정비구역 지정', '신통기획'),
]

# 며칠 안쪽 기사만 본다. 오래된 게 섞이면 「새 소식」이 아니다.
DAYS = 14

# 재개발과 무관한 소음. 제목에 있으면 버린다.
NOISE = re.compile(r'(분양권|청약 경쟁률|오피스텔 분양|광고|부고|인사)')


def _fetch(q):
    url = RSS.format(q=urllib.parse.quote(q))
    req = u.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    # 짧게 끊는다. 하나가 물려도 아침 알림 전체가 늦으면 안 된다.
    with u.urlopen(req, timeout=12) as r:
        return r.read().decode('utf-8', 'ignore')


def _parse(xml, topic):
    out = []
    for it in re.findall(r'<item>(.*?)</item>', xml, re.S):
        def pick(tag):
            m = re.search(rf'<{tag}[^>]*>(.*?)</{tag}>', it, re.S)
            return html.unescape(m.group(1)).strip() if m else None

        title = pick('title')
        link = pick('link')
        if not title or not link:
            continue
        # 구글 제목은 「제목 - 매체」로 끝난다. 매체는 <source> 에 따로 있다.
        source = pick('source')
        if source and title.endswith(f' - {source}'):
            title = title[: -len(source) - 3]
        pub = pick('pubDate')
        day = None
        if pub:
            try:
                day = datetime.datetime.strptime(
                    pub[:16], '%a, %d %b %Y').date()
            except ValueError:
                day = None
        out.append({'url': link, 'title': title, 'source': source,
                    'topic': topic, 'published_on': day})
    return out


def collect(today=None, days=DAYS):
    """새로 볼 만한 기사. 중복(url)과 오래된 것은 여기서 이미 걸러진다."""
    today = datetime.date.fromisoformat(today) if isinstance(today, str) \
        else (today or datetime.date.today())
    cutoff = today - datetime.timedelta(days=days)
    seen, out = set(), []
    for q, topic in QUERIES:
        try:
            items = _parse(_fetch(q), topic)
        except Exception as ex:  # noqa: BLE001
            print(f'  «{q}» 조회 실패: {ex}', file=sys.stderr)
            continue
        for it in items:
            if it['url'] in seen:
                continue
            if it['published_on'] and it['published_on'] < cutoff:
                continue
            if NOISE.search(it['title']):
                continue
            seen.add(it['url'])
            out.append(it)
    # 최신순. 날짜를 못 읽은 것은 뒤로.
    out.sort(key=lambda x: x['published_on'] or datetime.date(1970, 1, 1),
             reverse=True)
    return _dedupe(out)


def _shingles(title):
    """제목을 «글자 2개짜리 조각»으로 쪼갠다. 매체마다 어순이 달라
    (「상계한신3차, 재건축 속도」 vs 「노원구 상계한신3차 재건축 …」)
    앞머리만 봐서는 같은 사건인 줄 모른다."""
    t = re.sub(r'[^가-힣0-9A-Za-z]', '', title)
    return {t[i:i + 2] for i in range(len(t) - 1)}


def _same(a, b):
    """겹치는 조각 비율. 짧은 쪽 기준으로 본다 — 한쪽이 길다고
    다른 사건이 되는 건 아니다."""
    if not a or not b:
        return 0.0
    return len(a & b) / min(len(a), len(b))


def _dedupe(items, thr=0.55):
    """한 사건을 매체 10곳이 받아쓴다 — 「상계한신3차 정비구역 지정 요청」이
    한 번에 7건 들어왔다. 그대로 보내면 슬랙이 같은 말로 도배된다.
    사건당 한 줄만 남기고 몇 곳이 더 썼는지만 붙인다."""
    kept = []
    for i in items:
        sh = _shingles(i['title'])
        hit = next((k for k in kept if _same(sh, k['_sh']) >= thr), None)
        if hit:
            hit['also'] += 1
            continue
        i['also'] = 0
        i['_sh'] = sh
        kept.append(i)
    for k in kept:
        k.pop('_sh', None)
    return kept


def new_items(get, post, today=None):
    """이미 보낸 것을 뺀 «진짜 새» 기사. get/post 는 daily_slack 이 준다."""
    items = collect(today)
    if not items:
        return []
    sent = {r['url'] for r in get('/rest/v1/news_digest?select=url')}
    fresh = [i for i in items if i['url'] not in sent]
    return fresh


def slack_lines(fresh, limit=8):
    """슬랙에 넣을 줄. 너무 많으면 자르고 «몇 건 더»를 남긴다 —
    말없이 버리면 다 본 줄 안다."""
    lines = []
    for i in fresh[:limit]:
        d = i['published_on']
        when = f"{d.month}/{d.day}" if d else '?'
        src = f" · {i['source']}" if i['source'] else ''
        # 여러 매체가 받아쓴 건 «크게 난 소식»이라는 뜻이라 표시해 준다.
        more = f" (+{i['also']}곳)" if i.get('also') else ''
        lines.append(
            f"📰 {when} [{i['topic']}] <{i['url']}|{i['title'][:60]}>{src}{more}")
    if len(fresh) > limit:
        # «내일 이어서»가 맞다. 보낸 것만 news_digest 에 남기므로 나머지는
        # 내일 다시 후보가 된다. 「앱에서 보라」고 하면 거기 없어서 헛걸음이다.
        lines.append(f'… 그 밖에 {len(fresh) - limit}건은 내일 이어서')
    return lines


def main():
    dry = '--dry' in sys.argv
    items = collect()
    print(f'{len(items)}건 수집 (최근 {DAYS}일)')
    for i in items[:20]:
        d = i['published_on']
        print(f"  {d or '?'} [{i['topic']:5}] {(i['source'] or '?'):10} "
              f"{i['title'][:60]}")
    if dry:
        return
    print(json.dumps(items[:3], ensure_ascii=False, default=str, indent=2))


if __name__ == '__main__':
    main()
