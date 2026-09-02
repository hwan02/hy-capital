#!/usr/bin/env python3
"""서울도시공간포털에서 모아타운 구역 현황을 받아 zones 에 동기화한다.

앱에 손으로 넣은 구역은 서울 전체의 «일부»뿐이었다. 공식 목록은 107곳이다.
매수 자리(관리계획 수립 중)를 찾으려면 목록이 통째로 있어야 한다.

출처: 서울도시공간포털 > 서울플랜+ > 소규모정비사업 > 모아타운
      POST /bsns/getPageListbsnsIntegrated2.json  {"bsnsCdList":["BZ201"]}

【추진단계 → 앱 stage 매핑】 「후계공통승」 순서 그대로.
  수립범위 자문 · 대상지선정 · 사전자문 · 위원회심의  → 1 (관리계획 «수립» 중 = 매수 A)
  관리지역고시                                      → 2 (동의서 «징구» 중 = 매수 B)
조합설립(3) 이상은 이 API 에 «안 나온다». 그래서 이미 3 이상인 구역은
건드리지 않는다 — 안 그러면 조합설립인가 난 구역이 「매수 B」로 되돌아가
진입 불가 경고가 사라진다 (2026-09-02 실제로 한 번 겪었다).

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

# 추진단계 → stage. 「후계공통승」의 어디쯤인지도 같이 적는다.
STAGE = {
    '수립범위 자문': (1, '계획 수립 — 수립범위 자문'),
    '대상지선정': (1, '후보지 선정 (계획 수립 전)'),
    '사전자문': (1, '계획 수립 — 전문가 사전자문'),
    '위원회심의': (1, '통합심의 진행 중 — 고시 임박'),
    '관리지역고시': (2, '관리계획 승인 고시 완료 — 조합 동의서 징구 구간'),
}


def fetch():
    req = urllib.request.Request(
        API, method="POST",
        data=json.dumps({"bsnsCdList": ["BZ201"], "pageSize": 500}).encode(),
        headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=30) as r:
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
    rows = fetch()
    print(f'서울도시공간포털 — 모아타운 {len(rows)}곳')

    want = []
    skipped = []
    for c in rows:
        st = STAGE.get(c.get('propelCdNm'))
        if not st:
            skipped.append(c.get('propelCdNm'))
            continue
        stage, doing = st
        want.append({
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

    from collections import Counter
    print('  단계별:', dict(Counter(f"{w['stage']} {w['raw']}" for w in want)))
    if skipped:
        print('  건너뜀(모르는 단계):', dict(Counter(skipped)))

    if dry:
        for w in want:
            if w['stage'] == 1:
                print(f"  [매수A] {w['district']:6} {w['name'][:28]:30} {w['raw']}")
        return

    pw = os.environ.get("HY_PASSWORD", "")
    if not pw:
        sys.exit("HY_PASSWORD 를 설정해주세요.")
    email = os.environ.get("HY_EMAIL", "demo@hycapital.app")
    tok = sb("/auth/v1/token?grant_type=password", "POST",
             {"email": email, "password": pw})["access_token"]
    uid = sb("/auth/v1/user", token=tok)["id"]

    have = sb("/rest/v1/zones?select=id,name,stage,memo,rights_date", token=tok)
    by = {key(z['name']): z for z in have}

    added = updated = same = 0
    for w in want:
        src = (f"서울도시공간포털 «{w['raw']}» · {w['name']} · {w['addr']} · "
               f"{w['area']:,}㎡ · 추진일 {w['dt']} · 권리산정기준일 «{w['rfenc']}» "
               f"(동기화 2026-09-02)")
        k = key(w['name'])
        z = by.get(k)
        if z is None:
            sb("/rest/v1/zones", "POST", [{
                'user_id': uid, 'name': w['name'], 'kind': '모아타운',
                'district': w['district'], 'stage': w['stage'],
                'stage_source': src, 'stage_checked_at': '2026-09-02T00:00:00Z',
                'rights_date': w['rfenc'] or None,
                'memo': f"지금 진행 중 — {w['doing']}",
            }], token=tok)
            added += 1
            print(f"  ＋ [{w['stage']}] {w['district']:6} {w['name'][:30]}")
        elif z['stage'] >= 3:
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
            }, token=tok)
            updated += 1
            print(f"  ↻ [{z['stage']}→{w['stage']}] {w['name'][:30]}")
        else:
            if w['rfenc'] and not z.get('rights_date'):
                sb(f"/rest/v1/zones?id=eq.{z['id']}", "PATCH",
                   {'rights_date': w['rfenc']}, token=tok)
            same += 1

    print(f"\n추가 {added} · 단계갱신 {updated} · 그대로 {same}")


if __name__ == "__main__":
    main()
