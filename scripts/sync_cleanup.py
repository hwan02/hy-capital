#!/usr/bin/env python3
"""정비사업 정보몽땅에서 «조합 단계»를 가져와 zones 에 반영한다.

【왜 필요했나】
앱의 세부구역(subs)에는 «자동 갱신 경로가 없었다». 손으로 넣은 값이라
한 번 적어두면 그대로 늙는다. 서울도시공간포털(sync_moa_zones.py)은
«관리지역고시»까지만 알아서 그 뒤 — 조합설립인가·사업시행인가 — 는
아예 안 준다. 하필 그 구간이 «진입 불가»가 갈리는 자리다.

정보몽땅은 조합이 «설립인가»를 받으면 사업장으로 등록되고 진행단계를
공개한다. 로그인 없이 목록을 통째로(서울 1,180건) 받을 수 있다.

    https://cleanup.seoul.go.kr/cleanup/bsnssttus/lsubBsnsSttus.do?cpage=1&pageSize=3000

【못 가져오는 것 — 기대를 미리 낮춰둔다】
· 조합설립인가 «전» 단계(추진위 통합·총회·동의서 징구)는 «등록 자체가 안 된다».
  「구역이 몇 개로 합쳐졌다」 「총회를 했다」 는 여기서 못 잡는다.
· 조합 상세(총회 자료·공고문)는 «로그인»이 필요하다.
  → 그 둘은 구청 고시·조합 공고로 직접 확인해서 손으로 넣어야 한다.

【반영 규칙】
· 단계는 «올리기만» 한다. 정보몽땅에 없다고 내리지 않는다.
· 세부구역 코드(A2-4 · 제1-1 · 3구역)가 이름에 있으면 그 subs 항목만 고친다.
  사용자가 적어둔 ★평점·메모는 «건드리지 않는다».
· 코드가 없는 단일 조합이면 구역 stage 를 올린다.

    python3 scripts/sync_cleanup.py --dry     # 화면에만
    HY_PASSWORD='...' python3 scripts/sync_cleanup.py
"""
import html
import json
import os
import re
import sys
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from import_moa_pdf import ALIAS, _parts, login, sb  # noqa: E402  같은 규칙을 쓴다

LIST = ("https://cleanup.seoul.go.kr/cleanup/bsnssttus/"
        "lsubBsnsSttus.do?cpage=1&pageSize=3000")
SRC = "정비사업 정보몽땅"

# 소규모주택정비 계열만 본다. 재건축·재개발은 모아타운 구역이 아니다.
SMALL = {'가로주택정비', '소규모재건축', '소규모재개발'}

# 정보몽땅 진행단계 → 앱 stage (0053 이후 축: 9 조합설립 … 12 관리처분 … 14 준공)
STAGE = {
    '추진위원회승인': 8,
    '조합설립인가': 9,
    '사업시행자지정': 9,      # 주민합의체·지정개발자 방식 — 조합설립에 준한다
    '건축심의': 10,
    '시공자선정': 10,
    '사업시행인가': 11,
    '관리처분인가': 12,
    '착공': 13,
    '이주': 13,
    '준공': 14,
    '이전고시': 14,
}
# 손대면 안 되는 상태 — 사업이 끝났거나 접힌 것이다.
SKIP = {'조합해산', '조합청산'}

# 「A2-4구역」 「제1-1구역」 「3구역」
CODE = re.compile(r'(?:제)?([A-Z]?\d+(?:-\d+)?)\s*구역')
# 사업장명에 박힌 번지들 — 구역 매칭 열쇠
LOT = re.compile(r'(\d+(?:-\d+)?)(?=\s*(?:번지|일대|일원|$|\s))')


def fetch():
    req = urllib.request.Request(LIST, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=180) as r:
        h = r.read().decode('utf-8', 'replace')
    out = []
    for tr in re.findall(r'<tr[^>]*>(.*?)</tr>', h, re.S):
        c = [html.unescape(re.sub(r'<[^>]+>', '', x)).strip()
             for x in re.findall(r'<td[^>]*>(.*?)</td>', tr, re.S)]
        c = [x for x in c if x]
        if len(c) >= 6:
            out.append({'gu': c[1], 'kind': c[2], 'name': c[3],
                        'lot': c[4], 'stage': c[5]})
    return out


def zone_lot(district, name):
    """구역 이름에서 매칭용 번지. import_moa_pdf 의 규칙을 그대로 쓴다."""
    d, l = _parts(name)
    d, l = ALIAS.get((district or '', d, l), (d, l))
    return l


def main():
    dry = '--dry' in sys.argv
    rows = [r for r in fetch() if r['kind'] in SMALL]
    print(f"{SRC} — 소규모주택정비 {len(rows)}건\n")

    if dry and not os.environ.get("HY_PASSWORD"):
        for r in sorted(rows, key=lambda x: (x['gu'], x['name'])):
            if r['stage'] in STAGE and STAGE[r['stage']] >= 9:
                print(f"  {r['gu']:6} {r['name'][:46]:48} {r['stage']}")
        print("\n(구역 대조는 HY_PASSWORD 를 줘야 한다.)")
        return

    tok, _ = login()

    zones = sb("/rest/v1/zones?select=id,name,kind,district,stage,subs,memo,"
               "stage_source&kind=eq.모아타운", token=tok)

    raised = subbed = added = same = 0
    for z in zones:
        lot = zone_lot(z['district'], z['name'])
        if not lot:
            continue
        mine = [r for r in rows
                if r['gu'] == z['district'] and lot in set(LOT.findall(r['name']))]
        if not mine:
            continue

        subs = list(z.get('subs') or [])
        by_code = {str(s.get('code', '')).upper(): s for s in subs}
        patch = {}
        best = z['stage'] or 0

        for r in mine:
            if r['stage'] in SKIP:
                print(f"  ⚠ {z['name'][:26]:28} «{r['stage']}» — 손대지 않는다")
                continue
            st = STAGE.get(r['stage'])
            if st is None:
                continue
            c = CODE.search(r['name'])
            if c:
                code = c.group(1).upper()
                cur = by_code.get(code)
                if cur is None:
                    subs.append({'code': code, 'status': f"{r['stage']} ({SRC})",
                                 'rating': ''})
                    print(f"  ＋세부 {z['name'][:22]:24} {code:6} {r['stage']}")
                    added += 1
                elif r['stage'] not in str(cur.get('status', '')):
                    # ★평점·메모는 그대로 두고 status 만 바꾼다.
                    cur['status'] = f"{r['stage']} ({SRC})"
                    print(f"  ↻세부 {z['name'][:22]:24} {code:6} → {r['stage']}")
                    subbed += 1
            else:
                best = max(best, st)

        if subs != (z.get('subs') or []):
            patch['subs'] = subs
        if best > (z['stage'] or 0):
            patch['stage'] = best
            patch['stage_source'] = (
                f"{SRC} — {mine[0]['name']} · {mine[0]['stage']}")
            print(f"  ↑ 단계 [{z['stage']}→{best}] {z['name'][:30]} "
                  f"({mine[0]['stage']})")
            raised += 1

        if patch:
            if not dry:
                sb(f"/rest/v1/zones?id=eq.{z['id']}", "PATCH", patch, token=tok)
        else:
            same += 1

    print(f"\n{'[--dry] ' if dry else ''}"
          f"단계 상향 {raised} · 세부구역 갱신 {subbed} · 세부구역 추가 {added} · "
          f"그대로 {same}")
    print("\n조합설립인가 «전»(추진위 통합·총회)은 여기 안 나온다 — "
          "구청 고시·조합 공고로 직접 확인해야 한다.")


if __name__ == "__main__":
    main()
