#!/usr/bin/env python3
"""구역 «좌표» 채우기 — 카카오 주소검색으로 대표 지번 → 위도·경도.

행크옥션 부동산지도를 구역 위치로 바로 열려고 쓴다(앱 구역 카드의
「행크옥션 지도」 버튼). 좌표가 없는 구역만 찾는다 — 한 번 찾으면 끝이고,
새로 생긴 구역은 다음 날 아침 배치가 채운다.

【무엇으로 찾나】
  1) 이름·단계 출처·별칭에서 «동 + 지번»을 뽑는다 — 「신림동 610-220」.
     행정동 번호와 «본»은 뗀다(화곡1동→화곡동, 망우본동→망우동) —
     지번 주소는 법정동으로 붙는다. 「금호동1가」는 그대로.
  2) 지번이 없으면(「신림10구역」) 장소 키워드로 찾는다.
  3) 결과가 «서울 + 그 자치구» 주소가 아니면 버린다 — 엉뚱한 곳보다 비워 두는 게 낫다.

【키 — 저장소가 공개라 코드에 넣지 않는다】
  KAKAO_REST_KEY : GitHub Actions 시크릿 / env.local.json
  없으면 아무것도 안 하고 끝난다(배치를 빨갛게 만들지 않는다).

    python3 scripts/geocode_zones.py          # 좌표 없고 아직 안 찾아본 구역만
    python3 scripts/geocode_zones.py --dry    # 찾기만, 저장 안 함
    python3 scripts/geocode_zones.py --all    # 전부 다시
"""
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from import_moa_pdf import login, sb  # noqa: E402

ADDR = 'https://dapi.kakao.com/v2/local/search/address.json'
KEYWORD = 'https://dapi.kakao.com/v2/local/search/keyword.json'

# 「화곡1동 354」「면목3·8동 453-1」「금호동1가 129」「신림동 610-220」
# 「원효로4가 110-1」처럼 «동» 없이 «가»로 끝나는 법정동도 받는다.
# 「번동2지역」「상봉13구역」의 숫자는 번지가 아니다 — 뒤에 지역·구역 등이
# 붙으면 버린다(처음엔 「번동 2」로 찾아 엉뚱한 곳이 찍혔다).
LOT = re.compile(r'([가-힣]+?)(?:[0-9·？]*동(\d+가)?|(\d+가))\s*(\d+(?:-\d+)?)'
                 r'(?!\d|\s*(?:지역|구역|지구|단지|차|호))')


def kakao_key():
    k = os.environ.get('KAKAO_REST_KEY', '')
    path = os.path.join(os.path.dirname(HERE), 'env.local.json')
    if not k and os.path.exists(path):
        with open(path) as f:
            k = json.load(f).get('KAKAO_REST_KEY', '')
    return k.strip()


def kakao(url, query, key):
    req = urllib.request.Request(
        url + '?' + urllib.parse.urlencode({'query': query, 'size': 1}),
        headers={'Authorization': f'KakaoAK {key}'})
    with urllib.request.urlopen(req, timeout=15) as r:
        docs = json.loads(r.read()).get('documents') or []
    return docs[0] if docs else None


def lot_queries(z):
    """«서울 강서구 화곡동 957-1» 꼴 검색어들 — 법정동 + 지번. 출처마다 하나씩."""
    out = []
    for src in [z.get('name') or '', z.get('stage_source') or '',
                *(z.get('aliases') or [])]:
        for m in LOT.finditer(src.replace('？', '·')):
            stem = m.group(1)
            if m.group(3):                              # 원효로4가
                dong = f'{stem}{m.group(3)}'
            else:
                if len(stem) > 2 and stem.endswith('본'):   # 망우본동 → 망우동
                    stem = stem[:-1]
                dong = f"{stem}동{m.group(2) or ''}"
            q = f"서울 {z.get('district') or ''} {dong} {m.group(4)}".replace('  ', ' ')
            if q not in out:
                out.append(q)
    return out


def lot_query(z):
    qs = lot_queries(z)
    return qs[0] if qs else None


# 키워드 검색에 방해만 되는 말.
NOISE = re.compile(r'일대|일원|일재|번지|주택재개발사업|재개발사업|신속통합기획|후보지|'
                   r'모아타운|정비예정구역|[()（）]')


def find(z, key):
    """(lat, lng, 쓴 검색어) 또는 None.

    대표 번지(「봉천동 635 일대」)는 실제 필지가 635-1·635-2…로 쪼개져 있어
    그대로는 안 찾아지는 일이 많다. 정확한 번지 → -1 → -2 → -3 순으로 본다.
    """
    gu = z.get('district') or ''
    tries = []
    for q in lot_queries(z):
        tries.append((ADDR, q))
        head, lot = q.rsplit(' ', 1)
        base = lot.split('-')[0]
        # 본번만 남겨 -1·-2·-3 도 본다(「297-28」이 없으면 「297-1」).
        tries += [(ADDR, f'{head} {base}-{n}') for n in (1, 2, 3)
                  if f'{base}-{n}' != lot]
    name = NOISE.sub(' ', z['name']).replace(gu, ' ')
    name = re.sub(r'\s+', ' ', name).strip()
    tries.append((KEYWORD, f"서울 {gu} {name}".strip()))
    for url, query in tries:
        try:
            d = kakao(url, query, key)
        except urllib.error.HTTPError as e:
            # 401/403 = 키가 틀렸거나 «카카오맵» 사용 설정이 꺼져 있다.
            sys.exit(f'카카오 거절 [HTTP {e.code}] — 키·카카오맵 사용 설정을 확인한다: '
                     f'{e.read().decode()[:160]}')
        if not d:
            continue
        where = d.get('address_name') or ''
        if not where.startswith('서울') or (gu and gu not in where):
            continue  # 다른 동네 — 버린다
        return float(d['y']), float(d['x']), query
    return None


def main():
    dry, redo = '--dry' in sys.argv, '--all' in sys.argv
    key = kakao_key()
    if not key:
        print('KAKAO_REST_KEY 없음 — 구역 좌표를 건너뛴다')
        return
    tok, _ = login()
    path = '/rest/v1/zones?select=id,name,district,stage_source,aliases'
    redo = redo or os.environ.get('GEOCODE_ALL') == '1'
    try:
        # 좌표가 없고 «아직 시도 안 한» 구역만. 한 번 못 찾은 구역은 geo_query 에
        # «못 찾음»을 남겨 다음 날 다시 부르지 않는다 — 카카오 호출을 아낀다
        # (버튼은 저장된 좌표만 쓰므로 누를 때는 호출이 아예 없다).
        zones = sb(path + ('' if redo else '&lat=is.null&geo_query=is.null'),
                   token=tok)
    except urllib.error.HTTPError as e:
        print(f'좌표 칸 없음(0062 실행 전?) — 건너뜀 [HTTP {e.code}]')
        return
    ok = miss = 0
    for z in zones:
        hit = find(z, key)
        time.sleep(0.1)
        if not hit:
            miss += 1
            print(f"  ✖ {z.get('district')} {z['name']} — 못 찾음")
            if not dry:
                sb(f"/rest/v1/zones?id=eq.{z['id']}", 'PATCH',
                   {'geo_query': '못 찾음'}, token=tok)
            continue
        lat, lng, q = hit
        ok += 1
        print(f"  ✓ {z.get('district')} {z['name']} ← {q} ({lat:.5f}, {lng:.5f})")
        if not dry:
            sb(f"/rest/v1/zones?id=eq.{z['id']}", 'PATCH',
               {'lat': lat, 'lng': lng, 'geo_query': q}, token=tok)
    print(f'좌표 {ok}곳 채움 · 못 찾음 {miss}곳' + (' (dry)' if dry else ''))


if __name__ == '__main__':
    main()
