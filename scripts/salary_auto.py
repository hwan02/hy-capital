#!/usr/bin/env python3
"""월급을 자금 흐름 «들어오는 돈 · 월급»으로 자동으로 넣는다. 매시 배치가 돌린다.

월급은 한 달에 두 번(예: 20일·25일) 같은 금액이 들어오는데, 그날이 주말·
공휴일이면 «그 전 영업일»에 들어온다. 손으로 넣다 보니 날짜가 틀리거나
빠지는 달이 생겼다(2026-10 은 통째로 비어 있었다).

  · 입금일·금액은 코드에 두지 않는다 — 공개 저장소다. 시크릿 PAYDAY_PLAN 에
    «일:금액» 을 쉼표로 적는다. 예) 20:2000000,25:2000000
  · 입금일이 «지났거나 오늘»이면 넣는다. 배치가 하루 빠져도 다음에 채운다.
    지난달 것도 같이 본다 — 25일 이후 배치가 한 번도 안 떠도 빠지지 않게.
  · 그 입금 칸(예: 20일 칸 = 13~20일)에 «월급»이 이미 있으면(손으로 넣은 것
    포함) 만들지 않는다 — 두 번 들어가지 않게.
  · 공휴일은 holidays 패키지(KR — 대체공휴일·선거일 포함)로 본다.

    python3 scripts/salary_auto.py          # 넣는다
    python3 scripts/salary_auto.py --dry    # 무엇을 넣을지만
"""
import datetime
import os
import sys

import holidays

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from import_moa_pdf import login, sb  # noqa: E402

KST = datetime.timezone(datetime.timedelta(hours=9))
LABEL = '월급'
# 자동 입력을 시작한 달 — 그 전 달은 손으로 넣던 기록이라 건드리지 않는다.
START = datetime.date(2026, 11, 1)
INCOME = '들어오는 돈'


def plan():
    """PAYDAY_PLAN «20:2000000,25:2000000» → [(20, 2000000), (25, 2000000)]."""
    raw = os.environ.get('PAYDAY_PLAN', '').strip()
    out = []
    for part in raw.split(','):
        if ':' not in part:
            continue
        d, amt = part.split(':', 1)
        out.append((int(d), int(amt)))
    return sorted(out)


def pay_date(year, month, day, kr):
    """명목 입금일 → 실제 입금일. 주말·공휴일이면 하루씩 당긴다."""
    d = datetime.date(year, month, day)
    while d.weekday() >= 5 or d in kr:
        d -= datetime.timedelta(days=1)
    return d


def slots(year, month, days, kr):
    """그 달의 입금 칸들 — (실제 입금일, 칸 시작일, 칸 끝일, 금액).

    칸 = 앞 입금일 다음 날 ~ 이번 명목 입금일. 첫 칸은 명목일 7일 전부터.
    """
    out = []
    prev = None
    for day, amt in days:
        start = (datetime.date(year, month, prev + 1) if prev
                 else datetime.date(year, month, max(1, day - 7)))
        when = pay_date(year, month, day, kr)
        out.append((when, min(start, when), datetime.date(year, month, day), amt))
        prev = day
    return out


def main():
    dry = '--dry' in sys.argv
    days = plan()
    if not days:
        print('PAYDAY_PLAN 없음 — 건너뜀')
        return
    today = datetime.datetime.now(KST).date()
    kr = holidays.KR(years=[today.year - 1, today.year])
    this_m = today.replace(day=1)
    last_m = (this_m - datetime.timedelta(days=1)).replace(day=1)

    tok, uid = login()
    added = 0
    for m in (last_m, this_m):
        for when, start, end, amt in slots(m.year, m.month, days, kr):
            if when > today or when < START:
                continue
            have = sb(f'/rest/v1/flow_entries?select=id'
                      f'&direction=eq.{INCOME}&label=eq.{LABEL}'
                      f'&entry_date=gte.{start}&entry_date=lte.{end}', token=tok)
            if have:
                continue
            # 로그도 공개다 — 금액은 찍지 않는다.
            if dry:
                print(f'  [dry] {when} 월급 추가 예정')
                continue
            sb('/rest/v1/flow_entries', 'POST', {
                'user_id': uid,
                'entry_date': when.isoformat(),
                'direction': INCOME,
                'label': LABEL,
                'amount': amt,
                'memo': '자동',
            }, token=tok)
            added += 1
            print(f'  {when} 월급 추가')
    if not added and not dry:
        print('월급 — 새로 넣을 것 없음')


if __name__ == '__main__':
    main()
