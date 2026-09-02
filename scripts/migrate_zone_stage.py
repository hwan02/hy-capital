#!/usr/bin/env python3
"""구역 단계를 «교안 시세 그래프 축»으로 이관한다. 한 번만 돌린다.

전에는 축을 뭉개서 썼다 (모아 1=대상지·2=고시·3=조합설립…).
교안 그래프는 모아 8칸·신통 9칸이고, 골짜기(매수 자리)가 4·7 / 5·7 이다.
축을 잘라 쓰면 「관리계획 수립」과 「신규 선정」이 같은 칸이 되어
저점과 봉우리를 구분할 수 없다.

    python3 scripts/migrate_zone_stage.py --dry
    HY_PASSWORD='...' python3 scripts/migrate_zone_stage.py
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

# 옛 축 → 새 축
# 모아 옛: 1 대상지선정 2 관리계획고시 3 조합설립 4 건축심의 5 사업시행인가
#          6 이주·착공 7 준공
MOA = {1: 3, 2: 6, 3: 8, 4: 9, 5: 10, 6: 11, 7: 12}
# 신통 옛(어제 내가 넣은 것): 1 후보지 2 기획완료 3 열람공고 4 구역지정
SIN = {1: 3, 2: 5, 3: 6, 4: 7}


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


def main():
    dry = '--dry' in sys.argv
    pw = os.environ.get("HY_PASSWORD", "")
    if not pw and not dry:
        sys.exit("HY_PASSWORD 를 설정해주세요.")
    email = os.environ.get("HY_EMAIL", "demo@hycapital.app")
    tok = sb("/auth/v1/token?grant_type=password", "POST",
             {"email": email, "password": pw or 'x'})["access_token"]

    zs = sb("/rest/v1/zones?select=id,name,kind,stage", token=tok)
    todo = []
    for z in zs:
        old = z['stage']
        if old <= 0:
            continue
        table = SIN if z['kind'] == '신통기획' else MOA
        new = table.get(old)
        if new is None or new == old:
            continue
        todo.append((z, old, new))

    print(f'구역 {len(zs)}곳 · 옮길 것 {len(todo)}곳')
    for z, old, new in todo[:200]:
        print(f'  {z["kind"]:6} {old:2} → {new:2}  {z["name"][:34]}')
    if dry:
        return
    for z, old, new in todo:
        sb(f"/rest/v1/zones?id=eq.{z['id']}", "PATCH",
           {'stage': new}, token=tok)
    print(f'\n{len(todo)}곳 이관 완료')


if __name__ == "__main__":
    main()
