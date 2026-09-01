#!/usr/bin/env python3
"""책 트리 초기 데이터를 넣는다.

읽는 «순서»가 곧 sort_order 다. 쉬운 것부터, 앞 책이 뒤 책의 전제가 되게.
같은 (category, title) 이 이미 있으면 건너뛴다 — 여러 번 돌려도 안전하다.

    HY_PASSWORD='...' python3 scripts/seed_books.py
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

# ── 부동산 책 트리 ────────────────────────────────────────────
# (줄기, 순서, 제목, 저자, 난이도, 태그, 왜 여기 있나)
BOOKS = [
    # 뿌리 — 여기서 시작한다. 이 둘을 안 읽으면 나머지가 안 읽힌다.
    ('입문', 1, '엑시트 EXIT', '송희창(송사무장)', 1,
     ['재테크', '부자되는', '필수도서'],
     '왜 하는지부터 잡는다. 방법론이 아니라 방향을 주는 책.'),
    ('입문', 2, '부동산 계약 이렇게 쉬웠어?', '송희창(송사무장)', 1,
     ['사회초년생', '부린이', '초보'],
     '계약서를 못 읽으면 경매도 매매도 못 한다. 모든 거래의 바닥.'),
    ('입문', 3, '부동산 투자 이렇게 쉬웠어?', '신현강(부룡)', 1,
     ['부동산투자', '재테크', '기초'],
     '시장을 보는 눈. 개별 물건 전에 «판»을 먼저 본다.'),

    # 줄기 A — 경매·공매 (내 주력)
    ('경매', 1, '싱글맘 부동산 경매로 홀로서기', '이선미(쿵쿵나리)', 1,
     ['경매입문', '주부', '서민갑부'],
     '겁부터 없앤다. 소액으로 시작한 사람의 실제 기록.'),
    ('경매', 2, '권리분석 이렇게 쉬웠어?', '박희철(파이팅팔콘)', 1,
     ['권리분석', '경매', '초보'],
     '말소기준권리·대항력. 이걸 모르면 입찰하면 안 된다.'),
    ('경매', 3, '송사무장의 부동산 경매의 기술', '송희창(송사무장)', 2,
     ['경매바이블', '명도', '필수도서'],
     '경매 전 과정의 바이블. 명도까지 여기서 끝낸다.'),
    ('경매', 4, '송사무장의 부동산 공매의 기술', '송희창(송사무장)', 3,
     ['공매바이블', '직장인', '온비드'],
     '전자입찰이라 지역을 넓힐 수 있다. 경매와 원리는 같다.'),
    ('경매', 5, '송사무장의 실전경매', '송희창(송사무장)', 4,
     ['경매중수', '유치권', '특수물건'],
     '쉬운 물건이 마르면 여기로. 특수물건의 입구.'),
    ('경매', 6, '부동산 전문 변호사의 경매 유치권 이렇게 쉬웠어?', '이시훈(Law빈호)', 4,
     ['경매', '유치권공부', '실전사례'],
     '유치권 하나만 파는 책. 남들이 피하는 자리가 곧 마진.'),
    ('경매', 7, '한 권으로 끝내는 셀프소송의 기술', '송희창·이시훈', 5,
     ['경·공매소송', '서식', '소장'],
     '명도가 소송으로 갈 때. 서식이 다 들어 있어 «필요할 때» 편다.'),

    # 줄기 B — 아파트·내집마련
    ('아파트', 1, '수도권 알짜 부동산 답사기', '김학렬(빠송)', 1,
     ['내집마련', '입지', '지역분석'],
     '입지를 보는 눈. 어느 동네가 왜 비싼지.'),
    ('아파트', 2, '월급쟁이 강남 내집 마련하기', '조동식(기필코강남)', 1,
     ['재테크', '내집마련', '강남입성'],
     '월급쟁이의 현실 경로. 목표를 어디에 둘지.'),
    ('아파트', 3, '아파트 청약 이렇게 쉬웠어?', '김태훈(베니아)', 1,
     ['분양권', '청약', '내집마련'],
     '생애최초 특공 vs 대출. 경매와 같은 자리에서 비교해야 한다.'),
    ('아파트', 4, '부동산 절세의 기술', '김동우·최왕규', 3,
     ['세금', '절세실무', '쉬운절세'],
     '단타는 세금이 수익을 먹는다. 팔기 «전»에 읽어야 하는 책.'),

    # 줄기 C — 수익형
    ('수익형', 1, '공장투자 이렇게 쉬웠어?', '김덕환(긍정케이)', 1,
     ['공장투자', '초보', '직장인'],
     '주택 규제 밖의 영역. 단기 중과가 없다.'),
    ('수익형', 2, '상가투자 비밀노트', '홍성일·서선정', 3,
     ['상가투자', '수익형', '노후대비'],
     '입지·배후세대·동선. 주택과 완전히 다른 잣대.'),

    # 줄기 D — 토지
    ('토지', 1, '대한민국 땅따먹기', '서상하(풀하우스)', 3,
     ['토지', '경매', '건축'],
     '토지는 규제를 읽는 게임. 건축까지 이어진다.'),

    # 줄기 E — 법인
    ('법인', 1, '절대 실패하지 않는 법인 운영의 기술', '조기열·정초은·오너스경영', 3,
     ['법인설립', '창업', '절세'],
     '개인으로 한계가 오면 법인. 세금 구조가 통째로 바뀐다.'),
]


def req(path, method="GET", body=None, token=None):
    r = urllib.request.Request(
        SB + urllib.parse.quote(path, safe="/?&=.*,"), method=method)
    r.add_header("apikey", ANON)
    r.add_header("Content-Type", "application/json")
    r.add_header("Prefer", "return=representation")
    if token:
        r.add_header("Authorization", f"Bearer {token}")
    data = json.dumps(body).encode() if body is not None else None
    with urllib.request.urlopen(r, data) as x:
        raw = x.read()
        return json.loads(raw) if raw else None


def main():
    pw = os.environ.get("HY_PASSWORD", "")
    if not pw:
        sys.exit("HY_PASSWORD 를 설정해주세요.")
    email = os.environ.get("HY_EMAIL", "demo@hycapital.app")
    tok = req("/auth/v1/token?grant_type=password", "POST",
              {"email": email, "password": pw})["access_token"]
    uid = req("/auth/v1/user", token=tok)["id"]

    have = {b["title"] for b in
            req("/rest/v1/books?select=title&category=eq.부동산", token=tok)}

    rows = []
    for branch, order, title, author, level, tags, why in BOOKS:
        if title in have:
            continue
        rows.append({
            "user_id": uid, "category": "부동산", "branch": branch,
            "sort_order": order, "title": title, "author": author,
            "level": level, "tags": tags, "why": why, "status": "todo",
        })

    if not rows:
        print("추가할 책 없음 (전부 이미 있음)")
        return
    req("/rest/v1/books", "POST", rows, token=tok)
    print(f"{len(rows)}권 추가 · 건너뜀 {len(BOOKS) - len(rows)}권")


if __name__ == "__main__":
    main()
