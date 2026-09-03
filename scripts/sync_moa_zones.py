#!/usr/bin/env python3
"""서울도시공간포털에서 «모아타운 + 신속통합기획» 구역 현황을 zones 에 동기화한다.

앱에 손으로 넣은 구역은 서울 전체의 «일부»뿐이었다. 공식 목록은 107곳이다.
매수 자리(관리계획 수립 중)를 찾으려면 목록이 통째로 있어야 한다.

출처: 서울도시공간포털 > 서울플랜+
      POST /bsns/getPageListbsnsIntegrated2.json
        모아타운  {"bsnsCdList":["BZ201"]}   107곳
        신통기획  {"bsnsCdList":["BZ101"]}   231곳

【추진단계 → 앱 stage 매핑】 「후계공통승」 순서 그대로.
  수립범위 자문 · 대상지선정 · 사전자문 · 위원회심의  → 1 (관리계획 «수립» 중 = 매수 A)
  관리지역고시                                      → 2 (동의서 «징구» 중 = 매수 B)
【신통은 축이 «다르다»】 교안 시세 그래프에서 골짜기 위치가 다르다.
  대상지선정 → 1 (오르는 중 — 토허가까지 더 오른다)
  기획완료   → 2 (매수 A ← «첫 골짜기»)
  열람공고   → 3 (지정 임박 — 곧 뛴다)
  구역지정   → 4 (봉우리)
모아의 1·2단계와 뜻이 다르므로 Zone.kind 로 갈라서 판정한다(buy_band.dart).

조합설립 이상은 이 API 에 «안 나온다». 그래서 이미 그 단계인 구역은
건드리지 않는다 — 안 그러면 조합설립인가 난 구역이 되돌아가 진입 불가
경고가 사라진다 (2026-09-02 실제로 한 번 겪었다).

    python3 scripts/sync_moa_zones.py --dry   # 화면에만
    HY_PASSWORD='...' python3 scripts/sync_moa_zones.py
"""
import json
import os
import sys
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SB = "https://rbksmjnfaqglnzypgxqa.supabase.co"
ANON = ("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6"
        "InJia3Ntam5mYXFnbG56eXBneHFhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU3MzIzNTMs"
        "ImV4cCI6MjEwMTMwODM1M30.v7a-ZkdHr0neEwRuZBveCROrs6J80bVeBFd2jN4LGUI")
API = "https://urban.seoul.go.kr/bsns/getPageListbsnsIntegrated2.json"

# 교안 「단계별 시세 그래프」 x축을 그대로 쓴다.
#   모아 1 동의서징구시작 2 동의서달성 3 신규선정 4 관리계획수립
#        5 통합심의 6 관리계획승인고시 7 조합동의서징구 8 조합설립인가 …
#   신통 1 동의서징구시작 2 동의서달성 3 신규선정 4 토허가발효 5 기획완료
#        6 정비구역지정고시 7 동의서징구 8 조합설립인가 9 사업시행인가 …
# 포털이 주는 추진단계를 이 축에 꽂는다. 포털에 없는 칸(동의서징구·토허가)은
# 구역이 머무는 상태가 아니거나 별도 정보라 비어 있다.
MOA_STAGE = {
    '대상지선정': (3, '선정 발표로 오른 구간'),
    '수립범위 자문': (4, '관리계획 수립 — 수립범위 자문'),
    '사전자문': (4, '관리계획 수립 — 전문가 사전자문'),
    '위원회심의': (5, '통합심의 중 — 고시 임박'),
    '관리지역고시': (6, '관리계획 승인고시 완료 — 조합 동의서 걷기 시작'),
}

SIN_STAGE = {
    '대상지선정': (3, '선정 발표로 오른 구간'),
    '기획완료': (5, '기획 완료 — 지정고시 대기 (첫 골짜기)'),
    '열람공고': (6, '열람공고 — 정비구역 지정 임박'),
    '구역지정': (7, '정비구역 지정고시 완료 — 조합 동의서 징구'),
}

KINDS = [
    ('모아타운', 'BZ201', MOA_STAGE),
    ('신통기획', 'BZ101', SIN_STAGE),
]


def fetch(code):
    req = urllib.request.Request(
        API, method="POST",
        data=json.dumps({"bsnsCdList": [code], "pageSize": 1000}).encode(),
        headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read())["content"]


def sb(path, method="GET", body=None, token=None):
    req = urllib.request.Request(
        SB + urllib.parse.quote(path, safe="/?&=.*,"), method=method)
    req.add_header("apikey", ANON)
    req.add_header("Content-Type", "application/json")
    req.add_header("Prefer", "return=representation")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    data = json.dumps(body).encode() if body is not None else None
    with urllib.request.urlopen(req, data) as r:
        raw = r.read()
        return json.loads(raw) if raw else None


def key(name):
    """구역 이름에서 «동 + 번지»만 남겨 비교 키로 쓴다.
    「화곡1동 354번지 일대」와 「화곡동 354」가 같은 구역이다."""
    import re
    m = re.search(r'([가-힣]+)\d*동\s*([0-9]+(?:-[0-9]+)?)', name)
    return f'{m.group(1)}동 {m.group(2)}' if m else name.strip()


def main():
    dry = '--dry' in sys.argv
    from collections import Counter

    want = []
    for kind, code, table in KINDS:
        rows = fetch(code)
        skipped = []
        mine = []
        for c in rows:
            st = table.get(c.get('propelCdNm'))
            if not st:
                skipped.append(c.get('propelCdNm'))
                continue
            stage, doing = st
            mine.append({
                'kind': kind,
                'name': c['bsnsName'].strip(),
                'district': c.get('siteName'),
                'stage': stage,
                'addr': (c.get('bsnsAddr') or '').strip(),
                'area': int(c.get('bsnsArea') or 0),
                'doing': doing,
                'raw': c.get('propelCdNm'),
                'dt': (c.get('propelDt') or '')[:10],
                'rfenc': (c.get('rfencDt') or '')[:10],
            })
        print(f'{kind} {len(rows)}곳 → 매핑 {len(mine)}곳')
        print('  단계별:', dict(Counter(f"{w['stage']} {w['raw']}" for w in mine)))
        if skipped:
            print('  건너뜀(모르는 단계):', dict(Counter(skipped)))
        want += mine

    if dry:
        # 매수 A — 모아는 stage 1, 신통은 stage 2(기획완료)
        print('\n★ 매수 A (저점) 후보')
        for w in want:
            a = (w['stage'] == 4) if w['kind'] == '모아타운' else (w['stage'] == 5)
            if a:
                print(f"  {w['kind']:6} {w['district'] or '?':6} "
                      f"{w['name'][:30]:32} {w['raw']}")
        return

    pw = os.environ.get("HY_PASSWORD", "")
    if not pw:
        sys.exit("HY_PASSWORD 를 설정해주세요.")
    email = os.environ.get("HY_EMAIL", "demo@hycapital.app")
    tok = sb("/auth/v1/token?grant_type=password", "POST",
             {"email": email, "password": pw})["access_token"]
    uid = sb("/auth/v1/user", token=tok)["id"]

    have = sb("/rest/v1/zones?select=id,name,stage,memo,rights_date,propel_dt",
                  token=tok)
    by = {key(z['name']): z for z in have}

    added = updated = same = 0
    for w in want:
        src = (f"서울도시공간포털 «{w['kind']} · {w['raw']}» · {w['name']} · {w['addr']} · "
               f"{w['area']:,}㎡ · 추진일 {w['dt']} · 권리산정기준일 «{w['rfenc']}» "
               f"(동기화 2026-09-02)")
        k = key(w['name'])
        z = by.get(k)
        if z is None:
            sb("/rest/v1/zones", "POST", [{
                'user_id': uid, 'name': w['name'], 'kind': w['kind'],
                'district': w['district'], 'stage': w['stage'],
                'stage_source': src, 'stage_checked_at': '2026-09-02T00:00:00Z',
                'rights_date': w['rfenc'] or None,
                'propel_dt': w['dt'] or None,
                'memo': f"지금 진행 중 — {w['doing']}",
            }], token=tok)
            added += 1
            print(f"  ＋ [{w['stage']}] {w['district']:6} {w['name'][:30]}")
        elif z['stage'] >= 8:
            # 단계·출처는 안 건드리되 «권리산정기준일»은 채운다 — 그 날짜는
            # 지정 절차에서 확정되므로 조합설립 뒤에도 그대로다.
            if w['rfenc'] and not z.get('rights_date'):
                sb(f"/rest/v1/zones?id=eq.{z['id']}", "PATCH",
                   {'rights_date': w['rfenc']}, token=tok)
            # 이 API 는 모아타운 «지정» 절차까지만 안다. 조합설립(3) 이후는
            # 정비몽땅·조합에서 따로 확인한 값이므로 «아무것도 건드리지 않는다».
            # stage 만 지키고 stage_source 를 덮으면, 카드에는 「관리지역고시」가
            # 적혀 조합설립인가가 사라진 것처럼 보인다 (2026-09-02 실제로 겪었다).
            same += 1
        elif z['stage'] != w['stage']:
            sb(f"/rest/v1/zones?id=eq.{z['id']}", "PATCH", {
                'stage': w['stage'], 'stage_source': src,
                'stage_checked_at': '2026-09-02T00:00:00Z',
                'rights_date': w['rfenc'] or None,
                'propel_dt': w['dt'] or None,
            }, token=tok)
            updated += 1
            print(f"  ↻ [{z['stage']}→{w['stage']}] {w['name'][:30]}")
        else:
            patch = {}
            if w['rfenc'] and not z.get('rights_date'):
                patch['rights_date'] = w['rfenc']
            if w['dt'] and z.get('propel_dt') != w['dt']:
                patch['propel_dt'] = w['dt']
            if patch:
                sb(f"/rest/v1/zones?id=eq.{z['id']}", "PATCH", patch, token=tok)
            same += 1

    print(f"\n추가 {added} · 단계갱신 {updated} · 그대로 {same}")


if __name__ == "__main__":
    main()
