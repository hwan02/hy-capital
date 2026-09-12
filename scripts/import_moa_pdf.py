#!/usr/bin/env python3
"""서울시 «모아타운 추진현황» 표(PDF)를 zones 에 반영한다.

서울도시공간포털 API(sync_moa_zones.py)는 «주민제안» 구역을 거의 안 준다.
포털 107곳 ↔ 서울시 표 133곳 — 26곳이 앱에서 통째로 빠져 있었고,
그중 19곳이 「관리계획 수립 중」 = «매수 A(저점)» 구간이다.

그리고 «권리산정기준일»이 전부 틀려 있었다. 포털의 rfencDt 를 그대로
rights_date 에 넣어 왔는데, 107곳 중 73곳이 값이 똑같이 2025-11-30 이다 —
그건 갱신일자지 권리산정기준일이 아니다. 이 표에는 구역마다 «진짜» 기준일이
적혀 있다. 그 날짜는 「사용승인일 > 기준일 → 현금청산」 판정에 쓰므로
틀리면 살 수 있는 물건을 못 산다고 하거나 그 반대가 된다.

【단계는 «올리기만» 한다】
표(2026-09-08)와 포털이 29곳에서 어긋난다. 앱이 뒤처진 쪽(대상지선정인데
표는 수립 중)은 올린다. 반대로 앱이 «관리지역고시»인데 표가 「수립 중」인
15곳은 «내리지 않는다» — 내리면 이미 오른 구역이 저점(매수 A)으로 보인다.
대신 memo 에 «표와 다름 — 확인» 을 남긴다. 어느 쪽이 맞는지는 구청 고시로.
조합설립(8) 이상은 포털에 안 나오는 값이라 손대지 않는다.

    python3 scripts/import_moa_pdf.py --dry     # 화면에만
    HY_PASSWORD='...' python3 scripts/import_moa_pdf.py
"""
import json
import os
import re
import sys
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, "data", "moa_seoul_2026-09-08.json")
SRC_LABEL = "서울시 「모아타운 추진현황」 표 (2026-09-08)"

SB = "https://rbksmjnfaqglnzypgxqa.supabase.co"
ANON = ("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6"
        "InJia3Ntam5mYXFnbG56eXBneHFhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU3MzIzNTMs"
        "ImV4cCI6MjEwMTMwODM1M30.v7a-ZkdHr0neEwRuZBveCROrs6J80bVeBFd2jN4LGUI")

# 비고 → 앱 stage (교안 「단계별 시세 그래프」 축).
#   3 신규선정 · 4 관리계획수립(=매수 A) · 6 관리계획승인고시
DOING = {
    3: '대상지 선정 — 선정 발표로 오른 구간',
    4: '관리계획 수립 중 — «매수 A»(저점)',
    6: '관리계획 승인고시 완료 — 조합 동의서 걷기 시작',
}


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


# 서울시 표와 포털/앱이 «다른 이름»으로 부르는 같은 구역. 표 기준 → 앱 기준.
ALIAS = {
    ('강남구', '일원동', '619-641'): ('일원동', ''),        # 앱: 대청마을 북측구역
    ('강북구', '번동', '454-61'):   ('번동', '454'),        # 앱: 번동2지역
    ('강서구', '화곡동', '957'):    ('화곡동', '957-1'),
    ('금천구', '시흥동', '922-61'): ('시흥동', '922-16'),   # 표와 포털의 번지가 뒤집혀 있다
}

# «동 + 번지»만 뽑는다. 이름이 제각각이라(번동2지역(번동 454번지 일대) ·
# 화곡6동 957-1 일대 · 면목본동 63-1 · 목동 644-1번지 일대 모아타운 관리계획)
# 번지는 «번지/일대/끝»이 뒤따르는 숫자만 인정한다 — 안 그러면 「번동2지역」의
# 2 를 번지로 읽는다.
_RE = re.compile(
    r'([가-힣]{1,4})(?:\d+(?:[·,]\d+)*|본)?(동|가)(\d+가)?\s*'
    r'(\d+(?:-\d+)?)\s*(?:번지|일대|일원|$)')


def _parts(name):
    m = _RE.search(name)
    if m:
        d, l = m.group(1) + m.group(2) + (m.group(3) or ''), m.group(4)
    else:
        m = re.search(r'([가-힣]{1,4})(?:\d+(?:[·,]\d+)*|본)?(동|가)', name)
        d, l = (m.group(1) + m.group(2)) if m else name.strip(), ''
    # 「면목본동」의 본은 앞 글자를 그리디하게 먹고 남는다 → 여기서 턴다.
    return re.sub(r'본(?=(동|가)$)', '', d), l


def dong(name):
    return _parts(name)[0]


def lot(name):
    return _parts(name)[1]


def key(district, name):
    d, l = _parts(name)
    d, l = ALIAS.get((district or '', d, l), (d, l))
    return (district or '', d, l)


def main():
    dry = '--dry' in sys.argv
    doc = json.load(open(DATA, encoding='utf-8'))
    rows = doc['rows']
    print(f"{doc['출처']}\n  공모 {doc['집계']['자치구 공모']} · "
          f"주민제안 {doc['집계']['주민제안']} · 행 {len(rows)}\n")

    if dry and not os.environ.get("HY_PASSWORD"):
        for r in rows:
            if r['stage'] == 4:
                print(f"  매수 A  {r['자치구']:6} {r['대표지번']:18} "
                      f"{r['면적']:>9,.0f}㎡  권리산정 "
                      f"{'·'.join(r['권리산정기준일']) or '?'}")
        print("\n(로그인 없이 표만 보여준 것이다. 대조하려면 HY_PASSWORD 를 준다.)")
        return

    pw = os.environ.get("HY_PASSWORD", "")
    if not pw:
        sys.exit("HY_PASSWORD 를 설정해주세요.")
    email = os.environ.get("HY_EMAIL", "demo@hycapital.app")
    tok = sb("/auth/v1/token?grant_type=password", "POST",
             {"email": email, "password": pw})["access_token"]
    uid = sb("/auth/v1/user", token=tok)["id"]

    have = sb("/rest/v1/zones?select=id,name,kind,district,stage,stage_source,"
              "memo,rights_date&kind=eq.모아타운", token=tok)
    by = {}
    for z in have:
        by.setdefault(key(z['district'], z['name']), []).append(z)
        by.setdefault(('', dong(z['name']), lot(z['name'])), []).append(z)

    added = rights = raised = conflict = same = 0
    for r in rows:
        k = key(r['자치구'], r['대표지번'])
        hit = by.get(k) or by.get(('', k[1], k[2]))
        z = hit[0] if hit else None
        rd = r['권리산정기준일'][0] if r['권리산정기준일'] else None
        src = (f"{SRC_LABEL} · {r['구분']} · {r['자치구']} {r['대표지번']} · "
               f"{r['면적']:,.0f}㎡ · 권리산정기준일 "
               f"«{'·'.join(r['권리산정기준일']) or r.get('참고', '?')}» · {r['비고']}")

        if z is None:
            body = {
                'user_id': uid, 'name': f"{r['대표지번']} 일대", 'kind': '모아타운',
                'district': r['자치구'], 'stage': r['stage'], 'stage_source': src,
                'rights_date': rd,
                'memo': f"지금 진행 중 — {DOING[r['stage']]}"
                        + (f"\n{r['참고']}" if r.get('참고') else ''),
            }
            print(f"  ＋ [{r['stage']}] {r['자치구']:6} {r['대표지번']:18} "
                  f"{r['비고']}  권리산정 {rd or r.get('참고', '?')}")
            if not dry:
                sb("/rest/v1/zones", "POST", [body], token=tok)
            added += 1
            continue

        patch = {}
        if rd and z.get('rights_date') != rd:
            patch['rights_date'] = rd
            print(f"  ◔ 권리산정 {z['name'][:24]:26} "
                  f"{z.get('rights_date') or '없음'} → {rd}")
            rights += 1

        if r['stage'] > (z['stage'] or 0):
            patch['stage'] = r['stage']
            patch['stage_source'] = src
            print(f"  ↑ 단계 [{z['stage']}→{r['stage']}] {z['name'][:24]}")
            raised += 1
        elif r['stage'] < (z['stage'] or 0) and (z['stage'] or 0) < 7:
            # 내리지 않는다. 표와 앱이 다르다는 «사실»만 남긴다.
            # 7(조합 동의서 징구) 이상은 이 표가 모르는 구간이라 비교하지 않는다.
            note = (f"⚠ {SRC_LABEL} 은 «{r['비고']}» 라고 한다 "
                    f"(앱 단계 {z['stage']}). 구청 고시로 확인.")
            if note not in (z.get('memo') or ''):
                patch['memo'] = ((z.get('memo') or '') + '\n' + note).strip()
                print(f"  ⚠ 불일치 {z['name'][:24]:26} "
                      f"표 «{r['비고']}» ↔ 앱 단계 {z['stage']}")
                conflict += 1

        if patch:
            if not dry:
                sb(f"/rest/v1/zones?id=eq.{z['id']}", "PATCH", patch, token=tok)
        else:
            same += 1

    print(f"\n{'[--dry] ' if dry else ''}"
          f"추가 {added} · 권리산정기준일 교정 {rights} · 단계 상향 {raised} · "
          f"표와 불일치 {conflict} · 그대로 {same}")


if __name__ == "__main__":
    main()
