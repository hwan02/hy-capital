#!/usr/bin/env python3
"""온비드 공매 물건 → «내 매수 가능 구역 안인가» 판정.

손으로 하던 루틴을 그대로 옮긴 것이다 —
  매수 가능한 구역을 보고 → 지도에서 하나씩 찾고 → 공시가 1억 이하인지 본다.
이 중 «구역 판정»을 자동으로 한다.

【출처】
· 물건 상세: 한국자산관리공사 「온비드 부동산 물건상세 조회서비스」(SVC-API-004)
    https://apis.data.go.kr/B010003/OnbidRlstDtlSrvc2/getRlstDtlInf2
    필수 cltrMngNo(물건관리번호) · 옵션 pbctCdtnNo(공매조건번호)
    → «목록»이 아니다. 물건관리번호를 이미 알아야 한다.
· 구역: 서울도시공간포털 대상지 목록(sync_moa_zones 와 같은 것)

【아직 없는 것 — 매일 훑으려면 필요하다】
「온비드 부동산 «물건목록» 조회서비스」. 거기서 물건관리번호를 받아
여기 상세로 넘긴다. 스펙을 안 받아서 fetch_list() 를 비워뒀다 —
추측으로 짜면 또 고치게 된다.

【법원경매는 여기 없다】
공공데이터포털에 법원경매 API 가 없고, courtauction.go.kr 은 SPA+세션이라
긁을 수 없다. 공매만 자동이고 경매는 따로 봐야 한다.

    DATA_GO_KR_KEY='...' python3 scripts/onbid.py 2026-12642-001
"""
import json
import os
import sys
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from import_moa_pdf import (_parts, loose_match, open_retry,  # noqa: E402
                            parse_addr, portal_index)
import sync_cleanup  # noqa: E402  정비몽땅 — 조합설립인가 이후를 여기서만 안다

DETAIL = "https://apis.data.go.kr/B010003/OnbidRlstDtlSrvc2/getRlstDtlInf2"
PORTAL = "https://urban.seoul.go.kr/bsns/getPageListbsnsIntegrated2.json"

# 우리가 보는 건 «빌라»다. 아파트·상가·토지는 이 전략의 물건이 아니다.
WANT_USE = ('다세대', '연립', '빌라', '도시형생활주택')

# 포털 추진단계 → 매수 가능한가. sync_moa_zones 의 축과 같은 뜻이다.
#   조합설립인가가 나면 조합원 지위 양도가 막힌다(경매·공매는 법정 예외가
#   있지만 그건 «채권자»를 보고 따로 판단한다).
BUYABLE = {'대상지선정', '수립범위 자문', '사전자문', '위원회심의', '관리지역고시'}


def key():
    k = os.environ.get("DATA_GO_KR_KEY", "")
    if not k:
        sys.exit(
            "DATA_GO_KR_KEY 가 없다.\n"
            "  공공데이터포털에서 「온비드 부동산 물건상세 조회서비스」 키를 받아\n"
            "    gh secret set DATA_GO_KR_KEY      (배치용)\n"
            "    export DATA_GO_KR_KEY='...'       (이번 셸만)")
    return k


def fetch_detail(cltr_mng_no, pbct_cdtn_no=None):
    """물건관리번호로 상세를 받는다. 입찰 중·예정인 부동산만 나온다."""
    q = {
        'serviceKey': key(), 'resultType': 'json',
        'pageNo': 1, 'numOfRows': 10,
        'cltrMngNo': cltr_mng_no,
    }
    if pbct_cdtn_no:
        q['pbctCdtnNo'] = pbct_cdtn_no
    # serviceKey 는 이미 URL-encode 된 값으로 발급된다 — 다시 인코딩하면 깨진다.
    url = (DETAIL + '?serviceKey=' + q.pop('serviceKey') + '&'
           + urllib.parse.urlencode(q))
    req = urllib.request.Request(url, headers={'User-Agent': 'hy-capital/1.0'})
    raw = open_retry(req, timeout=30).decode('utf-8', 'replace')
    try:
        return json.loads(raw)
    except ValueError:
        sys.exit(f"JSON 이 아니다 — 키가 맞는지 보라:\n{raw[:300]}")


def zones():
    """포털 모아타운 대상지 목록."""
    req = urllib.request.Request(
        PORTAL, method='POST',
        data=json.dumps({"bsnsCdList": ["BZ201"], "pageSize": 1000}).encode(),
        headers={'Content-Type': 'application/json', 'User-Agent': 'Mozilla/5.0'})
    return json.loads(open_retry(req, timeout=60))['content']


def zone_of(addr, por, idx):
    """물건 주소 → 그 물건이 속한 구역. 없으면 None.

    「서울특별시 성동구 응봉동 265-34 제지하층 제02호」 → 「응봉동 265」.
    번지가 정확히 같은 구역을 먼저 찾고, 없으면 «본번»으로 한 번 더 본다
    (구역은 「응봉동 265」인데 물건은 「265-34」인 식이라 이게 필요하다).
    """
    gu, dong, lot = parse_addr(addr)
    if not lot:
        return None
    for c in por:
        if c['siteName'] == gu and _parts(c['bsnsName'])[1] == lot:
            return c
    hit = loose_match(gu, f'{dong} {lot}', idx)
    return next((c for c in por if c['bsnsName'] == hit), None) if hit else None


def unions(rows, zone):
    """그 구역 안에서 «조합설립인가 이상»인 조합들. 정비몽땅만 아는 정보다."""
    d, lot = _parts(zone['bsnsName'])
    if not lot:
        return []
    out = []
    for r in rows:
        if r['gu'] != zone['siteName'] or not sync_cleanup.matches(r, d, lot):
            continue
        if sync_cleanup.STAGE.get(r['stage'], 0) >= 9:
            out.append(r)
    return out


def judge(item, por, idx, cleanup=()):
    """물건 하나 → (구역, 살 수 있나, 이유).

    포털 단계만 보면 틀린다. 「화곡1동 354번지 일대」는 포털상 «관리지역고시»라
    매수 가능처럼 보이지만, 그 안 세부구역 A2-2·A2-4 는 이미 조합설립인가가
    나고 시공자까지 뽑았다. 정비몽땅을 같이 봐야 갈린다 —
    2026-09-19 에 이걸 빼먹고 후보 4곳을 잘못 올렸다.
    """
    addr = item.get('zadrNm') or item.get('cltrRadr') or ''
    use = item.get('cltrUsgSclsCtgrNm') or item.get('cltrUsgMclsCtgrNm') or ''
    z = zone_of(addr, por, idx)
    if z is None:
        return None, False, '구역 밖'
    if not any(w in use for w in WANT_USE):
        return z, False, f'빌라가 아니다({use})'
    if z['propelCdNm'] not in BUYABLE:
        return z, False, f"단계 «{z['propelCdNm']}» — 조합설립 이후"
    u = unions(cleanup, z)
    if u:
        names = ' · '.join(f"{r['name'][:18]}({r['stage']})" for r in u[:2])
        return z, False, f"구역 안에 조합설립인가 — {names}"
    return z, True, f"🟢 {z['propelCdNm']}"


def won(v):
    try:
        n = int(float(v))
    except (TypeError, ValueError):
        return '-'
    return f'{n // 10000:,}만' if n >= 10000 else f'{n:,}'


def line(item, z, why):
    """슬랙 한 줄."""
    return (f"{item.get('cltrMngNo', '')} {(item.get('zadrNm') or '')[:38]}\n"
            f"   구역 {z['bsnsName'][:24]} · {why}\n"
            f"   감정 {won(item.get('apslEvlAmt'))} · "
            f"최저 {won(item.get('lowstBidPrcIndctCont'))} · "
            f"입찰 {(item.get('cltrBidBgngDt') or '')[:10]}~"
            f"{(item.get('cltrBidEndDt') or '')[:10]}")


def fetch_list(**_):
    """TODO — 「온비드 부동산 «물건목록» 조회서비스」 스펙을 받으면 채운다.

    목록이 있어야 매일 서울 빌라를 훑어 물건관리번호를 뽑고 상세로 넘긴다.
    스펙 없이 파라미터를 추측해 짜면 또 틀린 걸 던지게 되므로 비워 둔다.
    """
    raise NotImplementedError(
        "물건목록 조회서비스 스펙이 필요하다 — 공공데이터포털에서 "
        "「온비드 부동산 물건목록 조회서비스」 활용가이드를 받아 달라.")


def main():
    if len(sys.argv) < 2:
        sys.exit(f"사용법: python3 {os.path.basename(sys.argv[0])} "
                 "<물건관리번호> [공매조건번호]")
    body = fetch_detail(sys.argv[1], sys.argv[2] if len(sys.argv) > 2 else None)
    items = (((body.get('response') or {}).get('body') or {})
             .get('items') or [])
    if isinstance(items, dict):
        items = items.get('item') or []
    if not items:
        print('물건을 못 찾았다(입찰 중·예정인 부동산만 조회된다).')
        print(json.dumps(body, ensure_ascii=False)[:400])
        return

    por = zones()
    idx = portal_index(por, lambda c: c['siteName'], lambda c: c['bsnsName'],
                       lambda c: c.get('bsnsAddr'))
    cleanup = [r for r in sync_cleanup.fetch() if r['kind'] in sync_cleanup.SMALL]
    for it in items:
        z, ok, why = judge(it, por, idx, cleanup)
        print()
        if z is None:
            print(f"— {it.get('cltrMngNo')} {(it.get('zadrNm') or '')[:40]}")
            print(f"   {why}")
            continue
        print(('✅ ' if ok else '✖ ') + line(it, z, why))


if __name__ == "__main__":
    main()
