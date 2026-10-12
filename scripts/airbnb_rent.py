#!/usr/bin/env python3
"""에어비앤비 월세를 매월 10일 «고정비»로 넣는다. 매일 아침 배치가 돌린다.

월세는 매달 10일 같은 금액이 나가는데 손으로 넣다 보니 빠지는 달이 생겼다.
호점(airbnb_units)에 적어 둔 월세(monthly_rent)로 그 달 거래를 한 줄 만든다.

  · 10일 «이후»면 언제 돌아도 된다 — 배치가 10일에 늦게 뜨거나 하루 빠져도
    다음 날 채운다.
  · 그 달에 메모에 «월세»가 들어간 거래가 이미 있으면(손으로 넣은 것 포함)
    만들지 않는다 — 두 번 빠지지 않게.
  · 만든 줄은 메모가 «월세 (자동)»이라, 자금 흐름·대시보드의 «투자한 돈»에
    「에어비앤비 월세」로 잡힌다(airbnbOutflowByMonthProvider).

    python3 scripts/airbnb_rent.py          # 넣는다
    python3 scripts/airbnb_rent.py --dry    # 무엇을 넣을지만
"""
import datetime
import os
import sys
import urllib.error

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from import_moa_pdf import login, sb  # noqa: E402

KST = datetime.timezone(datetime.timedelta(hours=9))
RENT_DAY = 10


def main():
    dry = '--dry' in sys.argv
    # 한국 날짜로 센다 — 러너는 UTC 라 새벽에 돌면 «어제»가 된다.
    today = datetime.datetime.now(KST).date()
    if today.day < RENT_DAY:
        print(f'{today} — 아직 {RENT_DAY}일 전, 월세 없음')
        return
    m0 = today.replace(day=1)
    m1 = (m0 + datetime.timedelta(days=32)).replace(day=1)
    day = m0.replace(day=RENT_DAY).isoformat()

    tok, uid = login()
    try:
        units = sb('/rest/v1/airbnb_units?select=id,name,monthly_rent'
                   '&monthly_rent=gt.0', token=tok)
    except urllib.error.HTTPError as e:
        # 0060 마이그레이션 전이면 칸이 없다 — 배치를 빨갛게 만들 일은 아니다.
        print(f'월세 칸 없음(0060 실행 전?) — 건너뜀 [HTTP {e.code}]')
        return

    for u in units:
        have = sb(f"/rest/v1/airbnb_transactions?select=id"
                  f"&unit_id=eq.{u['id']}&txn_date=gte.{m0}&txn_date=lt.{m1}"
                  f"&memo=ilike.*월세*", token=tok)
        rent = int(float(u['monthly_rent']))
        if have:
            print(f"  {u['name']} {m0:%Y-%m} 월세 이미 있음 — 건너뜀")
            continue
        line = f"{u['name']} {m0.month}월 월세 {rent:,}원 고정비 추가 ({day})"
        if dry:
            print('  [dry] ' + line)
            continue
        sb('/rest/v1/airbnb_transactions', 'POST', {
            'user_id': uid,
            'unit_id': u['id'],
            'txn_date': day,
            'fixed_cost': rent,
            'memo': '월세 (자동)',
        }, token=tok)
        print('  ' + line)


if __name__ == '__main__':
    main()
