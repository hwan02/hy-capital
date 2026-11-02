#!/usr/bin/env python3
"""에어비앤비 예약 메일을 읽어 에비 거래 장부에 «예약 한 줄»을 자동으로 넣는다.

예약이 잡힐 때마다 앱에 체크인일·박수·수령액을 손으로 넣고 있었다.
에어비앤비는 예약이 확정되면 호스트 메일로 알려 주므로, 그 메일함을 IMAP 으로
읽어서 대신 넣는다. 매시 배치가 돌린다.

  · 메일 계정은 코드에 두지 않는다 — 공개 저장소다.
      KAKAO_MAIL_USER          메일 주소
      KAKAO_MAIL_APP_PASSWORD  카카오 «앱 비밀번호» (계정 비밀번호 아님)
    둘 다 GitHub 시크릿 / 로컬은 env.local.json 에 둔다.
  · «예약 확정» → 체크인일을 거래일로, 박수·호스트 수령액을 한 줄로 넣는다.
    메모에 확인 코드(HM…)를 남겨 같은 예약을 두 번 넣지 않는다.
    같은 날·같은 박수의 예약이 이미 있으면(손으로 넣은 것) 넣지 않는다.
  · «예약 취소» → 이 스크립트가 넣은 줄(메모에 «메일»)만 지운다.
    손으로 넣은 줄은 건드리지 않는다.
  · 로그도 공개다 — 게스트 이름·금액은 찍지 않는다. 건수만.

    python3 scripts/airbnb_mail.py              # 넣는다
    python3 scripts/airbnb_mail.py --dry        # 무엇을 할지만 (건수)
    python3 scripts/airbnb_mail.py --dump       # «로컬 전용» 메일을 어떻게 읽었는지 자세히
    python3 scripts/airbnb_mail.py --days 30    # 며칠 치 메일을 볼지 (기본 14)
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

CODE = re.compile(r'\b(HM[A-Z0-9]{8})\b')
NIGHTS = re.compile(r'(\d+)\s*박')
WON = r'₩\s?([\d,]+)'
# 호스트가 «받는» 돈. 게스트 결제액(총액)과 헷갈리지 않게 이 단어들 뒤의 금액만 본다.
PAYOUT_KEYS = ('호스트 수입', '총 수입', '수령액', '호스트 수령', '받으실 금액',
               '예상 수입', 'You earn', 'Host payout', 'Total payout')
CONFIRM = ('예약 확정', '예약이 확정', 'Reservation confirmed', 'booking confirmed')
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
    head = subject + ' ' + ' '.join(lines[:5])
    kind = None
    # 취소는 «제목»으로만 본다 — 확정 메일 본문에도 «취소 정책»이 나온다.
    if any(k.lower() in subject.lower() for k in CANCEL):
        kind = 'cancel'
    elif any(k.lower() in head.lower() for k in CONFIRM):
        kind = 'confirm'

    code = CODE.search(subject + '\n' + flat)
    out = {'kind': kind, 'code': code.group(1) if code else None,
           'checkin': None, 'checkout': None, 'nights': None,
           'payout': None, 'listing': None}

    # 체크인 / 체크아웃 — 라벨 줄 «또는 그 다음 줄»에 날짜가 온다.
    for i, ln in enumerate(lines):
        for key, field in (('체크인', 'checkin'), ('Check-in', 'checkin'),
                           ('체크아웃', 'checkout'), ('Checkout', 'checkout')):
            if key.lower() in ln.lower() and out[field] is None:
                for cand in (ln, *lines[i + 1:i + 3]):
                    d = ko_date(cand, sent.year)
                    if d:
                        out[field] = d
                        break
    # 연말 예약 — 12월에 받은 메일의 「1월 3일」은 내년이다.
    for f in ('checkin', 'checkout'):
        if out[f] and out[f] < sent - datetime.timedelta(days=60):
            out[f] = out[f].replace(year=out[f].year + 1)

    n = NIGHTS.search(flat)
    if n:
        out['nights'] = int(n.group(1))
    elif out['checkin'] and out['checkout']:
        out['nights'] = (out['checkout'] - out['checkin']).days

    for i, ln in enumerate(lines):
        if any(k.lower() in ln.lower() for k in PAYOUT_KEYS):
            for cand in (ln, *lines[i + 1:i + 3]):
                m = re.search(WON, cand)
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
        _, msg_data = im.fetch(num, '(RFC822)')
        msg = email.message_from_bytes(msg_data[0][1])
        sent = email.utils.parsedate_to_datetime(msg['Date']).astimezone(KST).date()
        mails.append((decode(msg['Subject']), body_text(msg), sent))
    im.logout()
    return mails


def main():
    dry = '--dry' in sys.argv
    dump = '--dump' in sys.argv
    days = 14
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

    added = removed = skipped = unread = 0
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
                'memo': f"예약 {p['code']} ({TAG})",
            }, token=tok)
        added += 1

    pre = '[dry] ' if dry else ''
    print(f'{pre}에비 메일 {len(mails)}통 — 예약 추가 {added} · 이미 있음 {skipped}'
          f' · 취소 반영 {removed} · 못 읽음 {unread}')


if __name__ == '__main__':
    main()
