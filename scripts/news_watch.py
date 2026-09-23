#!/usr/bin/env python3
"""모아타운·신속통합기획 기사를 모아 «새 것만» 골라낸다.

아침 슬랙에 뉴스가 한 줄도 안 나오던 이유는 단순하다 — 수집하는 코드가
아예 없었다. news_digest 표는 있었지만 앱에서 손으로 링크를 넣는 용도였다.

출처는 둘이다.
  ① 정비사업 «전문지» RSS (SITES) — 구글이 늦게 잡거나 아예 안 잡는
     구역 단위 소식(동의서 징구·조합장 선출)이 여기 먼저 뜬다. 주소도
     원문 그대로라 짧다.
  ② «구글 뉴스 RSS» — 키가 필요 없고, 매체를 가리지 않고 긁는다.
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

# 정비사업 전문지. 사이트 전체 기사 RSS 를 받아 모아·신통만 걸러낸다.
# 검색어를 사이트마다 돌리지 않는 이유 — 전문지는 하루 기사가 몇 개
# 안 돼서 «전체»를 받아 거르는 게 빠르고, 검색 API 가 없는 곳도 된다.
SITES = [
    ('디벨로퍼뉴스', 'https://cdn.dpnews.co.kr/rss/gn_rss_allArticle.xml'),
    ('하우징헤럴드', 'https://cdn.housingherald.co.kr/rss/gn_rss_allArticle.xml'),
]

# 전문지 기사를 어느 topic 으로 볼지. 「모아」만 걸면 「모아서」가 걸린다.
TOPIC_OF = [
    (re.compile(r'모아타운|모아주택'), '모아타운'),
    (re.compile(r'신속통합|신통기획|신통\s*재'), '신통기획'),
]

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

def today_kst():
    """한국 날짜. GitHub 러너는 UTC 라 아침 6~9시에 돌면 «어제»가 된다."""
    return datetime.datetime.now(
        datetime.timezone(datetime.timedelta(hours=9))).date()


# «하루치»만 본다.
#
# 전에는 14일이었다. 그랬더니 매일 70건씩 후보가 쌓이는데 슬랙엔 8건만
# 나가서 「그 밖에 62건은 내일 이어서」가 붙었다. 하루 8건으로는 영영
# 못 따라잡고, 14일이 지난 기사는 어차피 잘려 나간다 — 밀린 목록만
# 계속 들고 있었던 셈이다.
#
# 오늘 새로 난 것만 보내고 나머지는 버린다. 어제 못 본 기사를 오늘
# 뒤늦게 받는 것보다, 매일 그날 것만 깔끔히 받는 게 낫다.
# (cutoff = today - 1 이라 «어제~오늘» 발행분이 들어온다. 배치가
#  아침 6시에 도므로 1 로 잡아야 어제 저녁 기사를 놓치지 않는다.)
DAYS = 1

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


def _site_items(name, url):
    """전문지 전체 기사 RSS → 모아·신통 기사만. 제목·요약에서 topic 을 정한다."""
    req = u.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    with u.urlopen(req, timeout=12) as r:
        xml = r.read().decode('utf-8', 'ignore')
    out = []
    for it in re.findall(r'<item>(.*?)</item>', xml, re.S):
        def pick(tag):
            m = re.search(rf'<{tag}[^>]*>(.*?)</{tag}>', it, re.S)
            if not m:
                return ''
            v = re.sub(r'^\s*<!\[CDATA\[(.*)\]\]>\s*$', r'\1', m.group(1), flags=re.S)
            return html.unescape(v).strip()
        title, link = pick('title'), pick('link')
        if not title or not link:
            continue
        text = title + ' ' + re.sub(r'<[^>]+>', ' ', pick('description'))[:600]
        topic = next((t for rx, t in TOPIC_OF if rx.search(text)), None)
        if not topic:
            continue
        day = None
        pub = pick('pubDate')
        if pub:
            try:
                day = datetime.datetime.strptime(pub[:16], '%a, %d %b %Y').date()
            except ValueError:
                day = None
        out.append({'url': link, 'title': title, 'source': name,
                    'topic': topic, 'published_on': day})
    return out


def collect(today=None, days=DAYS):
    """새로 볼 만한 기사. 중복(url)과 오래된 것은 여기서 이미 걸러진다."""
    today = datetime.date.fromisoformat(today) if isinstance(today, str) \
        else (today or today_kst())
    cutoff = today - datetime.timedelta(days=days)
    seen, out = set(), []
    # 전문지를 «먼저» 넣는다. 중복 묶기는 먼저 들어온 것을 대표로 남기므로,
    # 같은 사건을 구글도 잡았으면 전문지 기사가 대표가 되고 구글 쪽은
    # 「(+N곳)」으로만 붙는다 — 주소가 짧고 원문이다.
    batches = []
    for name, url in SITES:
        try:
            batches.append(_site_items(name, url))
        except Exception as ex:  # noqa: BLE001  한 곳이 죽어도 나머지는 본다
            print(f'  «{name}» 조회 실패: {ex}', file=sys.stderr)
    for q, topic in QUERIES:
        try:
            batches.append(_parse(_fetch(q), topic))
        except Exception as ex:  # noqa: BLE001
            print(f'  «{q}» 조회 실패: {ex}', file=sys.stderr)
    for items in batches:
        for it in items:
            if it['url'] in seen:
                continue
            if it['published_on'] and it['published_on'] < cutoff:
                continue
            if NOISE.search(it['title']):
                continue
            seen.add(it['url'])
            out.append(it)
    # 최신순. 날짜를 못 읽은 것은 뒤로. 같은 날이면 전문지가 앞 —
    # sort 는 안정적이라 위에서 넣은 순서(전문지 → 구글)가 유지된다.
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


def _dedupe(items, thr=0.45):
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


def slack_lines(fresh, limit=10):
    """슬랙에 넣을 줄. 너무 많으면 자르고 «몇 건 더»를 남긴다 —
    말없이 버리면 다 본 줄 안다.

    【URL 을 «그대로» 쓴다】
    전에는 <url|제목> 슬랙 문법을 썼다. 슬랙 안에서는 예쁘지만, 그 줄을
    복사해서 다른 데 붙이면 «제목만 남고 링크가 사라진다». 기사를 옮겨
    적으려면 결국 슬랙으로 돌아가 하나씩 다시 눌러야 했다.
    맨 URL 은 슬랙이 알아서 링크로 만들어 주고, 복사하면 따라온다.
    대신 미리보기(unfurl)가 8개씩 붙으면 채널이 터지므로 발송 쪽에서 끈다.

    줄머리 📰 는 붙이지 않는다 — 섹션 제목이 이미 「📰 정비사업 뉴스」다.
    """
    # «여러 매체가 받아쓴 것»을 위로 올린다.
    # 큰 발표가 나면 그 하나를 20곳이 조금씩 다른 제목으로 쓴다. 제목이
    # 제각각이라 중복 묶기가 다 못 잡고, 날짜순으로 자르면 그 한 사건의
    # 아류 기사들이 열 자리를 전부 차지한다. also(받아쓴 곳 수)가 큰
    # 대표 기사를 먼저 보내면, 같은 열 줄로 «서로 다른 사건»을 더 많이 본다.
    fresh = sorted(fresh, key=lambda x: (-(x.get('also') or 0),
                                         x['published_on'] or datetime.date.min),
                   reverse=False)
    lines = []
    for i in fresh[:limit]:
        d = i['published_on']
        when = f"{d.month}/{d.day}" if d else '?'
        src = f" · {i['source']}" if i['source'] else ''
        # 여러 매체가 받아쓴 건 «크게 난 소식»이라는 뜻이라 표시해 준다.
        more = f" (+{i['also']}곳)" if i.get('also') else ''
        # 기록(news_digest)은 원래 주소로 한다 — 중복 판정 키라서.
        # 줄이는 건 «보여줄 때»만.
        lines.append(
            f"{when} [{i['topic']}] {i['title'][:60]}{src}{more}\n{short(i['url'])}")
    # 잘린 건수는 말하지 않는다. 하루치만 보므로 잘린 건 다시 안 온다 —
    # 「그 밖에 24건은 생략」은 할 수 있는 게 없는 정보라 소음이었다.
    return lines


def short(url):
    """긴 주소를 tinyurl 로 줄인다. 실패하면 원래 주소를 그대로 쓴다.

    구글 뉴스 주소는 원문을 통째로 인코딩해서 200자가 넘는다. 원문으로
    풀 수는 없어서(JS 로만 튕긴다) 대신 짧게 감싼다 — 누르면 똑같이 간다.
    단축이 안 된다고 뉴스를 못 보내면 안 되므로 어떤 실패든 원래 주소로.
    is.gd 는 2026-09-23 에 「database insert failed」를 뱉어 뺐다.
    """
    if 'news.google.com' not in url:
        return url                    # 전문지 원문 주소는 이미 짧다
    try:
        req = u.Request('https://tinyurl.com/api-create.php?url='

                        + urllib.parse.quote(url, safe=''),
                        headers={'User-Agent': 'Mozilla/5.0'})
        with u.urlopen(req, timeout=8) as r:
            s = r.read().decode().strip()
        return s if s.startswith('https://tinyurl.com/') else url
    except Exception:  # noqa: BLE001
        return url


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
