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

    python3 scripts/geocode_zones.py          # 좌표 없는 구역만
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
LOT = re.compile(r'([가-힣]+?)[0-9·？]*동(\d+가)?\s*(\d+(?:-\d+)?)')


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


def lot_query(z):
    """«서울 강서구 화곡동 957-1» — 법정동 + 지번. 못 찾으면 None."""
    for src in [z.get('name') or '', z.get('stage_source') or '',
                *(z.get('aliases') or [])]:
        m = LOT.search(src.replace('？', '·'))
        if not m:
            continue
        stem = m.group(1)
        if len(stem) > 2 and stem.endswith('본'):   # 망우본동 → 망우동
            stem = stem[:-1]
        dong = f"{stem}동{m.group(2) or ''}"
        return f"서울 {z.get('district') or ''} {dong} {m.group(3)}".replace('  ', ' ')
    return None


def find(z, key):
    """(lat, lng, 쓴 검색어) 또는 None."""
    gu = z.get('district') or ''
    tries = []
    q = lot_query(z)
    if q:
        tries.append((ADDR, q))
    tries.append((KEYWORD, f"서울 {gu} {re.sub(r'[(（].*?[)）]', '', z['name'])}".strip()))
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
    try:
        zones = sb(path + ('' if redo else '&lat=is.null'), token=tok)
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
