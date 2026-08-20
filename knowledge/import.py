#!/usr/bin/env python3
"""부동산 지식 자료실 임포터.

knowledge/*.json 을 읽어 Supabase knowledge_notes 테이블에 넣는다.
같은 (source, title) 은 건너뛰므로 여러 번 돌려도 중복되지 않는다.

사용법:
    python3 knowledge/import.py                    # knowledge/ 전체
    python3 knowledge/import.py path/to/one.json   # 특정 파일

JSON 포맷 (둘 다 지원):
  1) Q&A  : {"meta": {...}, "items": [{"question","answer","asker","tags",...}]}
  2) 일반 : {"meta": {...}, "items": [{"title","body","tags",...}]}
"""
import json, sys, glob, os, urllib.request

SB = "https://rbksmjnfaqglnzypgxqa.supabase.co"
ANON = ("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJia3Ntam5"
        "mYXFnbG56eXBneHFhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU3MzIzNTMsImV4cCI6MjEwMTMwODM1M30"
        ".v7a-ZkdHr0neEwRuZBveCROrs6J80bVeBFd2jN4LGUI")
EMAIL = os.environ.get("HY_EMAIL", "demo@hycapital.app")
PW = os.environ.get("HY_PASSWORD", "")


def api(path, method="GET", body=None, token=None):
    req = urllib.request.Request(f"{SB}{path}", method=method)
    req.add_header("apikey", ANON)
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    if body is not None:
        req.add_header("Prefer", "return=representation")
        body = json.dumps(body).encode()
    with urllib.request.urlopen(req, body) as r:
        raw = r.read()
        return json.loads(raw) if raw else None


def login():
    if not PW:
        sys.exit("환경변수 HY_PASSWORD 를 설정해주세요.  예: HY_PASSWORD=xxx python3 knowledge/import.py")
    tok = api("/auth/v1/token?grant_type=password", "POST",
              {"email": EMAIL, "password": PW})
    return tok["access_token"], api("/auth/v1/user", token=tok["access_token"])["id"]


def to_rows(doc, uid):
    meta = doc.get("meta", {})
    src = meta.get("source") or meta.get("lecture") or "출처 미상"
    date = meta.get("qa_date") or meta.get("date")
    author = meta.get("expert") or meta.get("author")
    rows = []
    for it in doc.get("items", []):
        if "question" in it:  # Q&A
            rows.append({
                "user_id": uid, "kind": "qa",
                "title": it["question"].strip(),
                "body": it["answer"].strip(),
                "tags": it.get("tags", []),
                "source": src, "author": author,
                "asker": it.get("asker"),
                "url": it.get("url") or meta.get("url"),
                "source_date": (it.get("asked_at") or date or "")[:10] or None,
            })
        else:               # 일반 글/메모
            rows.append({
                "user_id": uid, "kind": it.get("kind", "article"),
                "title": it["title"].strip(),
                "body": (it.get("body") or "").strip(),
                "tags": it.get("tags", []),
                "source": it.get("source") or src,
                "author": it.get("author") or author,
                "url": it.get("url") or meta.get("url"),
                "source_date": (it.get("date") or date or "")[:10] or None,
            })
    return rows


def main():
    files = sys.argv[1:] or sorted(glob.glob(os.path.join(os.path.dirname(__file__), "*.json")))
    if not files:
        sys.exit("가져올 json 이 없습니다.")
    token, uid = login()
    existing = {(r.get("source"), r.get("title"))
                for r in api("/rest/v1/knowledge_notes?select=source,title", token=token)}
    total = skipped = 0
    for f in files:
        doc = json.load(open(f, encoding="utf-8"))
        rows = [r for r in to_rows(doc, uid) if (r["source"], r["title"]) not in existing]
        skipped += len(doc.get("items", [])) - len(rows)
        for i in range(0, len(rows), 50):          # 50건씩 배치
            api("/rest/v1/knowledge_notes", "POST", rows[i:i + 50], token)
        for r in rows:
            existing.add((r["source"], r["title"]))
        total += len(rows)
        print(f"  {os.path.basename(f)}: {len(rows)}건 추가")
    print(f"\n완료 — 추가 {total}건 / 중복 건너뜀 {skipped}건")


if __name__ == "__main__":
    main()
