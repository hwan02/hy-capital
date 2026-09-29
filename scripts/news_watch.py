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
    ('한국주택경제신문', 'https://cdn.arunews.com/rss/gn_rss_allArticle.xml'),
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
    """슬랙에 넣을 줄 — «제목 + 한 줄 요약»만. 링크는 없다.

    【링크를 뺐다】 (2026-09-30)
    링크가 있어도 결국 눌러 들어가서 읽지 않았다. 아침에 슬랙만 보고
    «무슨 일이 있었나»를 알면 된다. 그래서 기사 첫 문장(리드)을 붙인다.
    더 보고 싶은 건 제목으로 검색하면 된다.

    요약은 기사 원문의 og:description(리드 문단)에서 첫 문장을 딴다.
    못 가져오면 제목만 보낸다 — 요약이 없다고 기사를 버리지 않는다.
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
        # 「(+7곳)」은 붙이지 않는다 — 몇 곳이 받아썼는지는 읽는 사람에게
        # 쓸모가 없었다. 순서(많이 받아쓴 것이 위)로만 쓴다.
        head = f"*{i['title'][:70]}*"
        gist = summary(i)
        lines.append(f"{head}\n{gist}" if gist else head)
    # 잘린 건수는 말하지 않는다. 하루치만 보므로 잘린 건 다시 안 온다 —
    # 「그 밖에 24건은 생략」은 할 수 있는 게 없는 정보라 소음이었다.
    return lines


UA = {'User-Agent': 'Mozilla/5.0'}


def original(url):
    """구글 뉴스 주소 → 기사 원문 주소. 못 풀면 None.

    구글 뉴스 RSS 주소(…/rss/articles/CBMi…)는 원문을 JS 로만 넘긴다.
    그 페이지가 싣고 있는 서명(data-n-a-sg · ts)을 구글 뉴스 자체의
    변환 요청(batchexecute)에 그대로 넘기면 원문 주소가 온다. 비공식
    경로라 언제든 깨질 수 있다 — 그러면 요약 없이 제목만 나간다.
    """
    if 'news.google.com' not in url:
        return url
    try:
        gid = url.split('/articles/')[1].split('?')[0]
        with u.urlopen(u.Request(url, headers=UA), timeout=8) as r:
            page = r.read().decode('utf-8', 'ignore')
        sg = re.search(r'data-n-a-sg="([^"]+)"', page).group(1)
        ts = re.search(r'data-n-a-ts="([^"]+)"', page).group(1)
        inner = ['garturlreq',
                 [['X', 'X', ['X', 'X'], None, None, 1, 1, 'US:en', None, 1,
                   None, None, None, None, None, 0, 1],
                  'X', 'X', 1, [1, 1, 1], 1, 1, None, 0, 0, None, 0],
                 gid, int(ts), sg]
        body = 'f.req=' + urllib.parse.quote(json.dumps(
            [[['Fbv4je', json.dumps(inner), None, 'generic']]]))
        req = u.Request(
            'https://news.google.com/_/DotsSplashUi/data/batchexecute',
            data=body.encode(),
            headers={**UA, 'Content-Type':
                     'application/x-www-form-urlencoded;charset=UTF-8'})
        with u.urlopen(req, timeout=8) as r:
            raw = r.read().decode('utf-8', 'ignore')
        arr = json.loads(raw.split('\n\n', 1)[1])
        return json.loads(arr[0][2])[1]
    except Exception:  # noqa: BLE001
        return None


# 리드 문단 앞머리의 바이라인 — 「[헤럴드경제=박종일 선임기자]」
# 「(서울=뉴스1) 홍길동 기자 =」 「홍길동 기자 =」
_BYLINE = re.compile(
    r'^\s*(?:[\[(【][^\])】]{0,40}[\])】]\s*)?'
    r'(?:[가-힣]{2,4}\s*(?:선임|수석|전문)?기자\s*=?\s*)?')


def summary(item, width=110):
    """기사 리드의 첫 문장. 못 가져오거나 제목과 상관없는 글이면 ''.

    og:description 은 대부분 기사 첫 문단이다. 다만 매체에 따라 사이트
    소개문(「매일 아침 배달되는 서울시 온라인뉴스…」)이 들어 있어서,
    제목과 겹치는 조각이 거의 없으면 요약이 아니라고 보고 버린다.
    """
    url = original(item['url'])
    if not url:
        return ''
    try:
        with u.urlopen(u.Request(url, headers=UA), timeout=8) as r:
            raw = r.read(400_000)
        cs = re.search(rb'charset=["\']?([\w-]+)', raw[:5000])
        page = raw.decode(cs.group(1).decode() if cs else 'utf-8', 'ignore')
    except Exception:  # noqa: BLE001
        return ''
    m = (re.search(r'<meta[^>]+(?:property|name)=["\'](?:og:)?description["\']'
                   r'[^>]*content=["\']([^"\']+)', page)
         or re.search(r'<meta[^>]+content=["\']([^"\']+)["\'][^>]*'
                      r'(?:property|name)=["\'](?:og:)?description', page))
    if not m:
        return ''
    text = re.sub(r'\s+', ' ', html.unescape(m.group(1))).strip()
    text = _BYLINE.sub('', text, count=1).strip()
    if _same(_shingles(text), _shingles(item['title'])) < 0.3:
        return ''
    # 첫 문장. 「…했다.」 로 끝나는 데서 자른다 — 리드 문단은 마침표 뒤에
    # 띄어쓰기 없이 다음 문장이 붙어 오기도 한다(「…올렸다.중랑구는」).
    cut = re.search(r'^(.+?다)[.。]', text)
    text = cut.group(1) + '.' if cut else text
    # 제목을 그대로 되풀이한 리드는 요약이 아니다.
    bare = lambda x: re.sub(r'[^가-힣0-9A-Za-z]', '', x)
    if bare(text).startswith(bare(item['title'])[:20]) \
            and len(text) < len(item['title']) + 15:
        return ''
    return text if len(text) <= width else text[:width].rstrip() + '…'


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
