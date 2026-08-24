#!/usr/bin/env python3
"""공모주 «예정» 건을 앱에 넣는다. 매주 월요일 배치가 쓴다.

일정을 «찾는» 일은 사람(또는 Claude)이 하고, 이 스크립트는 «넣기»만 한다.
크롤링하지 않는다 — 사이트 구조가 자주 바뀌고 차단되므로, 찾은 결과를
JSON 으로 받아 저장하는 역할만 맡는다.

    python3 scripts/ipo_week.py ipos.json
    echo '[{...}]' | python3 scripts/ipo_week.py -

JSON 한 건의 모양 (name 과 sub_end 는 필수):
    {
      "name": "○○테크",
      "broker": "한투",
      "sub_start": "2026-09-02",
      "sub_end": "2026-09-03",
      "refund_date": "2026-09-05",
      "listing_date": "2026-09-12",
      "band_low": 12000,
      "band_high": 15000,
      "source": "38커뮤니케이션"
    }

같은 (name, sub_end) 는 건너뛴다 — 여러 번 돌려도 중복이 쌓이지 않는다.
"""
import json
import os
import sys
import urllib.request as u

URL = os.environ.get('SUPABASE_URL', 'https://rbksmjnfaqglnzypgxqa.supabase.co')
ANON = os.environ.get(
    'SUPABASE_ANON_KEY',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJia3Ntam5mYXFnbG56eXBneHFhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU3MzIzNTMsImV4cCI6MjEwMTMwODM1M30.v7a-ZkdHr0neEwRuZBveCROrs6J80bVeBFd2jN4LGUI')

FIELDS = ('name', 'broker', 'sub_start', 'sub_end', 'refund_date',
          'listing_date', 'band_low', 'band_high', 'competition_rate',
          'source', 'memo')


def _req(path, data=None, token=ANON, method=None, extra=None):
    headers = {'apikey': ANON, 'Authorization': f'Bearer {token}',
               'Content-Type': 'application/json'}
    if extra:
        headers.update(extra)
    req = u.Request(URL + path, method=method,
                    data=json.dumps(data).encode() if data is not None else None,
                    headers=headers)
    try:
        with u.urlopen(req) as r:
            return r.status, r.read().decode()
    except Exception as e:  # noqa: BLE001 — 상태코드와 본문을 그대로 보여준다
        body = e.read().decode() if hasattr(e, 'read') else str(e)
        return getattr(e, 'code', 0), body


def login():
    """env.local.json 의 계정으로 로그인. 비밀번호는 파일에만 있다."""
    here = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    with open(os.path.join(here, 'env.local.json')) as f:
        env = json.load(f)
    st, body = _req('/auth/v1/token?grant_type=password',
                    {'email': env['AUTO_EMAIL'],
                     'password': env['AUTO_PASSWORD']})
    if st != 200:
        sys.exit(f'로그인 실패({st}): {body[:200]}')
    tok = json.loads(body)
    return tok['access_token'], tok['user']['id']


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    raw = sys.stdin.read() if sys.argv[1] == '-' else open(sys.argv[1]).read()
    items = json.loads(raw)
    if isinstance(items, dict):
        items = [items]

    jwt, uid = login()

    st, body = _req('/rest/v1/ipo_subscriptions?select=name,sub_end', token=jwt)
    if st != 200:
        sys.exit(f'조회 실패({st}): {body[:200]}')
    have = {(r['name'], r.get('sub_end')) for r in json.loads(body)}

    rows, skipped = [], 0
    for it in items:
        if not it.get('name') or not it.get('sub_end'):
            print(f"  건너뜀 (name/sub_end 없음): {it}")
            skipped += 1
            continue
        if (it['name'], it['sub_end']) in have:
            print(f"  이미 있음: {it['name']} ({it['sub_end']})")
            skipped += 1
            continue
        rows.append({'user_id': uid,
                     **{k: it[k] for k in FIELDS if it.get(k) is not None}})

    if not rows:
        print(f'추가할 것 없음 (건너뜀 {skipped}건)')
        return

    st, body = _req('/rest/v1/ipo_subscriptions', rows, token=jwt,
                    extra={'Prefer': 'return=minimal'})
    if st not in (200, 201, 204):
        sys.exit(f'저장 실패({st}): {body[:300]}')
    for r in rows:
        print(f"  추가: {r['name']} · 청약 {r.get('sub_start','?')}~{r['sub_end']}")
    print(f'\n완료 — 추가 {len(rows)}건 / 건너뜀 {skipped}건')


if __name__ == '__main__':
    main()
