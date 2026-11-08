#!/usr/bin/env python3
"""에어비앤비 예약 메일을 읽어 에비 거래 장부에 «예약 한 줄»을 자동으로 넣는다.

예약이 잡힐 때마다 앱에 체크인일·박수·수령액을 손으로 넣고 있었다.
에어비앤비는 예약이 확정되면 호스트 메일로 알려 주므로, 그 메일함을 IMAP 으로
읽어서 대신 넣는다. 매시 배치가 돌린다.

  · 메일 계정은 코드에 두지 않는다 — 공개 저장소다.
      KAKAO_MAIL_USER          메일 주소
      KAKAO_MAIL_APP_PASSWORD  카카오 «앱 비밀번호» (계정 비밀번호 아님)
    둘 다 GitHub 시크릿 / 로컬은 env.local.json 에 둔다.
  · «예약 확정» → «체크인 날이 되면» 체크인일을 거래일로, 박수·호스트 수입
    (수수료 뗀 금액)을 한 줄로 넣는다. 청소비는 기본값(CLEANING)으로 같이.
    2026-11 체크인부터.
    메모에 확인 코드(HM…)를 남겨 같은 예약을 두 번 넣지 않는다.
    같은 날·같은 박수의 예약이 이미 있으면(손으로 넣은 것) 넣지 않는다.
  · «예약 취소» → 이 스크립트가 넣은 줄(메모에 «메일»)만 지운다.
    손으로 넣은 줄은 건드리지 않는다.
  · 로그도 공개다 — 게스트 이름·금액은 찍지 않는다. 건수만.

    python3 scripts/airbnb_mail.py              # 넣는다
    python3 scripts/airbnb_mail.py --dry        # 무엇을 할지만 (건수)
    python3 scripts/airbnb_mail.py --dump       # «로컬 전용» 메일을 어떻게 읽었는지 자세히
    python3 scripts/airbnb_mail.py --days 30    # 며칠 치 메일을 볼지 (기본 400)
"""
import datetime
import email
import email.header
import email.utils
import html
import imaplib
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from import_moa_pdf import login, sb  # noqa: E402

KST = datetime.timezone(datetime.timedelta(hours=9))
IMAP_HOST = 'imap.kakao.com'
TAG = '메일'          # 이 스크립트가 넣은 줄 표시 — 취소 때 이것만 지운다
# 자동 입력을 시작한 체크인일 — 그 전 예약은 손으로 넣어 왔다. 옛 기록은 거래일
# 기준이 들쭉날쭉해서 «같은 예약»을 못 알아보고 두 번 넣을 수 있다.
START = datetime.date(2026, 11, 1)
# 예약마다 나가는 청소비 — 늘 같은 금액이라 기본으로 넣는다. 다르면 앱에서 고친다.
CLEANING = 55000

CODE = re.compile(r'\b(HM[A-Z0-9]{8})\b')
NIGHTS = re.compile(r'(\d+)\s*박')
WON = r'₩\s?([\d,]+)'
# 호스트가 «받는» 돈. 게스트 결제액(총액)과 헷갈리지 않게 이 단어들 뒤의 금액만 본다.
PAYOUT_KEYS = ('호스트 수입', 'You earn', 'Host payout')
# 호스트 쪽 확정 메일 제목: 「예약 확정 - ○○ 님이 11월 10일에 체크인할 예정입니다」.
# «예약 확정»만 보면 내가 «게스트»로 묵은 영수증(「예약 확정: … 영수증」)까지 걸린다.
CONFIRM = ('체크인할 예정', 'Reservation confirmed')
CANCEL = ('취소', 'cancel')


def env(key):
    v = os.environ.get(key)
    if v:
        return v
    # 로컬: env.local.json (gitignore)
    p = os.path.join(os.path.dirname(__file__), '..', 'env.local.json')
    try:
        return json.load(open(p)).get(key)
    except (OSError, ValueError):
        return None


def decode(s):
    out = ''
    for part, enc in email.header.decode_header(s or ''):
        out += part.decode(enc or 'utf-8', 'replace') if isinstance(part, bytes) else part
    return out


def body_text(msg):
    """text/plain 을 먼저, 없으면 HTML 에서 태그를 걷어낸 글자."""
    plain, htm = '', ''
    for part in msg.walk():
        ct = part.get_content_type()
        if part.get_content_maintype() == 'multipart':
            continue
        try:
            raw = part.get_payload(decode=True) or b''
            txt = raw.decode(part.get_content_charset() or 'utf-8', 'replace')
        except Exception:  # noqa: BLE001
            continue
        if ct == 'text/plain':
            plain += txt
        elif ct == 'text/html':
            htm += txt
    if plain.strip():
        return plain
    htm = re.sub(r'(?is)<(script|style).*?</\1>', ' ', htm)
    htm = re.sub(r'(?i)<br\s*/?>|</(p|div|tr|td|li|h\d)>', '\n', htm)
    htm = re.sub(r'<[^>]+>', ' ', htm)
    return html.unescape(htm)


def ko_date(s, year_hint):
    """「11월 5일」「2026년 11월 5일」「2026. 11. 5.」 → date."""
    m = re.search(r'(?:(\d{4})\s*[년.]\s*)?(\d{1,2})\s*[월.]\s*(\d{1,2})\s*일?', s)
    if not m:
        return None
    y = int(m.group(1) or year_hint)
    try:
        return datetime.date(y, int(m.group(2)), int(m.group(3)))
    except ValueError:
        return None


def parse(subject, text, sent):
    """메일 한 통 → {kind, code, checkin, nights, payout, listing} (못 읽은 칸은 None)."""
    flat = re.sub(r'[ \t\r\f\v]+', ' ', text)
    lines = [ln.strip() for ln in flat.split('\n') if ln.strip()]
    kind = None
    # 취소는 «제목»으로만 본다 — 확정 메일 본문에도 «취소 정책»이 나온다.
    if any(k.lower() in subject.lower() for k in CANCEL):
        kind = 'cancel'
    elif any(k.lower() in subject.lower() for k in CONFIRM):
        kind = 'confirm'

    code = CODE.search(subject + '\n' + flat)
    out = {'kind': kind, 'code': code.group(1) if code else None,
           'checkin': None, 'checkout': None, 'nights': None,
           'payout': None, 'listing': None}

    # 체크인 / 체크아웃 — 「체크인 체크아웃」 머리 줄 «다음 줄»에 두 날짜가 나란히 온다.
    #   체크인 체크아웃
    #   2027년 1월 25일 (월) 2027년 2월 2일 (화)      ← 해가 바뀌면 연도가 붙는다
    #   12월 23일 (수) 12월 27일 (일)
    for i, ln in enumerate(lines):
        if '체크인' in ln and '체크아웃' in ln and i + 1 < len(lines):
            ds = [ko_date(m.group(0), sent.year) for m in re.finditer(
                r'(?:\d{4}\s*년\s*)?\d{1,2}\s*월\s*\d{1,2}\s*일', lines[i + 1])]
            ds = [d for d in ds if d]
            if ds:
                out['checkin'] = ds[0]
                out['checkout'] = ds[1] if len(ds) > 1 else None
            break
    # 연도가 안 붙은 날짜 — 메일보다 한참 앞이면 내년이다(12월 메일의 「1월 3일」).
    for f in ('checkin', 'checkout'):
        if out[f] and out[f] < sent - datetime.timedelta(days=60):
            out[f] = out[f].replace(year=out[f].year + 1)
    if out['checkin'] and out['checkout'] and out['checkout'] < out['checkin']:
        out['checkout'] = out['checkout'].replace(year=out['checkout'].year + 1)

    if out['checkin'] and out['checkout']:
        out['nights'] = (out['checkout'] - out['checkin']).days
    else:
        n = NIGHTS.search(flat)
        out['nights'] = int(n.group(1)) if n else None

    # 호스트가 «받는» 돈 — 「호스트 수령 대금」 표의 마지막 줄 「호스트 수입 ₩…」.
    # (그 위 「8박 숙박료」는 수수료 떼기 전이라 쓰면 안 된다)
    for key in PAYOUT_KEYS:
        for ln in lines:
            if ln.startswith(key):
                m = re.search(WON, ln)
                if m:
                    out['payout'] = int(m.group(1).replace(',', ''))
                    break
        if out['payout']:
            break
    return out


def fetch(days):
    user, pw = env('KAKAO_MAIL_USER'), env('KAKAO_MAIL_APP_PASSWORD')
    if not (user and pw):
        sys.exit('KAKAO_MAIL_USER / KAKAO_MAIL_APP_PASSWORD 없음 — 건너뜀')
    since = (datetime.date.today() - datetime.timedelta(days=days)).strftime('%d-%b-%Y')
    im = imaplib.IMAP4_SSL(IMAP_HOST, 993)
    im.login(user, pw)
    im.select('INBOX', readonly=True)    # 읽음 표시를 바꾸지 않는다
    _, data = im.search(None, 'SINCE', since, 'FROM', '"airbnb"')
    mails = []
    for num in data[0].split():
        # 제목만 먼저 본다 — 후기·홍보 메일까지 본문을 다 받으면 느리다.
        # BODY.PEEK 라 읽음 표시는 그대로. 응답 모양이 서버마다 달라서
        # (카카오는 앞에 None 이 끼어 온다) 바이트가 든 튜플을 찾아 쓴다.
        _, hd = im.fetch(num, '(BODY.PEEK[HEADER.FIELDS (SUBJECT)])')
        raw = next((x[1] for x in hd if isinstance(x, tuple)), b'')
        subj = decode(email.message_from_bytes(raw)['Subject'])
        if not any(k.lower() in subj.lower() for k in CONFIRM + CANCEL):
            continue
        _, msg_data = im.fetch(num, '(BODY.PEEK[])')
        raw = next((x[1] for x in msg_data if isinstance(x, tuple)), None)
        if not raw:
            continue
        msg = email.message_from_bytes(raw)
        sent = email.utils.parsedate_to_datetime(msg['Date']).astimezone(KST).date()
        mails.append((decode(msg['Subject']), body_text(msg), sent))
    im.logout()
    return mails


def main():
    dry = '--dry' in sys.argv
    dump = '--dump' in sys.argv
    # 예약은 몇 달 전에 잡힌다 — 체크인 날 넣으려면 그만큼 거슬러 본다.
    days = 400
    if '--days' in sys.argv:
        days = int(sys.argv[sys.argv.index('--days') + 1])

    mails = fetch(days)
    parsed = [(s, parse(s, t, d)) for s, t, d in mails]
    if dump:
        # 로컬에서만 — 메일을 어떻게 읽었는지 본다(게스트 이름은 제목에서 가린다).
        for s, p in parsed:
            print(re.sub(r'[가-힣A-Za-z]+님', '○○님', s)[:70])
            print('   ', {k: (str(v) if v is not None else None) for k, v in p.items()})
        return

    tok, uid = login()
    units = sb('/rest/v1/airbnb_units?select=id,name,status', token=tok)
    if not units:
        print('호점 없음 — 건너뜀')
        return
    default = next((u for u in units if u.get('status') == 'open'), units[0])

    today = datetime.datetime.now(KST).date()
    cancelled = {p['code'] for _, p in parsed if p['kind'] == 'cancel' and p['code']}
    added = removed = skipped = unread = waiting = 0
    # 로그에 남길 체크인 날짜 — 금액·이름은 안 찍는다(공개 로그). «왜 안 들어갔나»를 날짜로 본다.
    wait_days, early_days = [], []
    for _, p in parsed:
        if p['kind'] == 'cancel' and p['code']:
            rows = sb(f"/rest/v1/airbnb_transactions?select=id"
                      f"&memo=ilike.*{p['code']}*&memo=ilike.*{TAG}*", token=tok)
            for r in rows:
                if not dry:
                    sb(f"/rest/v1/airbnb_transactions?id=eq.{r['id']}", 'DELETE', token=tok)
                removed += 1
            continue
        if p['kind'] != 'confirm':
            continue
        if not (p['code'] and p['checkin'] and p['nights'] and p['payout']):
            unread += 1              # 확정 메일인데 칸을 다 못 읽었다 — 형식이 바뀌었나
            continue
        if p['code'] in cancelled:
            continue
        if p['checkin'] < START:
            early_days.append(p['checkin'])
            continue
        # 체크인 날 넣는다 — 손으로 넣던 방식 그대로. 미리 넣으면 아직 안 온
        # 달의 매출이 «누적»에 섞이고, 취소되면 숫자가 출렁인다.
        if p['checkin'] > today:
            waiting += 1
            wait_days.append(p['checkin'])
            continue
        unit = default
        if p['listing']:
            unit = next((u for u in units if u['name'] in p['listing']), default)
        dup = sb(f"/rest/v1/airbnb_transactions?select=id"
                 f"&memo=ilike.*{p['code']}*", token=tok)
        if not dup:
            # 손으로 먼저 넣은 같은 예약 — 같은 체크인일·같은 박수
            dup = sb(f"/rest/v1/airbnb_transactions?select=id&unit_id=eq.{unit['id']}"
                     f"&txn_date=eq.{p['checkin']}&nights=eq.{p['nights']}"
                     f"&payout=gt.0", token=tok)
        if dup:
            skipped += 1
            continue
        if not dry:
            sb('/rest/v1/airbnb_transactions', 'POST', {
                'user_id': uid,
                'unit_id': unit['id'],
                'txn_date': p['checkin'].isoformat(),
                'nights': p['nights'],
                'payout': p['payout'],
                'cleaning_cost': CLEANING,
                'memo': f"예약 {p['code']} ({TAG})",
            }, token=tok)
        added += 1

    pre = '[dry] ' if dry else ''
    print(f'{pre}에비 메일 {len(mails)}통 — 예약 추가 {added} · 이미 있음 {skipped}'
          f' · 체크인 전 {waiting} · 취소 반영 {removed} · 못 읽음 {unread}')
    md = lambda ds: ', '.join(f'{d.month}/{d.day}' for d in sorted(set(ds))) or '없음'
    print(f'  체크인 기다리는 날: {md(wait_days)}')
    print(f'  {START.month}/{START.day} 전 체크인(손으로 넣던 것, 건너뜀) 최근: {md(sorted(early_days)[-5:])}')


if __name__ == '__main__':
    main()
