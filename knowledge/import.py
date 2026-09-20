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
import json, sys, glob, os, urllib.request, urllib.error

SB = "https://rbksmjnfaqglnzypgxqa.supabase.co"
ANON = ("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJia3Ntam5"
        "mYXFnbG56eXBneHFhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODU3MzIzNTMsImV4cCI6MjEwMTMwODM1M30"
        ".v7a-ZkdHr0neEwRuZBveCROrs6J80bVeBFd2jN4LGUI")
KEYCHAIN = "hy-capital-app"


def keychain_password():
    """macOS 키체인에서 앱 비밀번호를 꺼낸다. 없으면 빈 문자열.

    scripts/import_moa_pdf.py · unlock_pdf.py 와 «같은» 방식이다 —
    한 번 넣어두면 비밀번호가 명령줄에도 셸 기록에도 남지 않는다.
    """
    try:
        import subprocess
        r = subprocess.run(
            ["security", "find-generic-password", "-s", KEYCHAIN, "-w"],
            capture_output=True, text=True, timeout=10)
        return r.stdout.strip() if r.returncode == 0 else ""
    except Exception:  # noqa: BLE001
        return ""


# 비밀번호는 «키체인 → 환경변수» 순. env.local.json 은 보지 않는다 —
# 비밀번호가 키체인으로 옮겨간 뒤에도 그 파일엔 옛 값이 남아 있어서,
# 그걸 읽으면 멀쩡한 키체인을 두고 틀린 값으로 로그인하게 된다.
EMAIL = (os.environ.get("HY_EMAIL")
         or os.environ.get("AUTO_EMAIL")
         or "demo@hycapital.app")
PW = (keychain_password()
      or os.environ.get("HY_PASSWORD")
      or os.environ.get("AUTO_PASSWORD", ""))


def api(path, method="GET", body=None, token=None):
    req = urllib.request.Request(f"{SB}{path}", method=method)
    req.add_header("apikey", ANON)
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    if body is not None:
        req.add_header("Prefer", "return=representation")
        body = json.dumps(body).encode()
    try:
        with urllib.request.urlopen(req, body) as r:
            raw = r.read()
            return json.loads(raw) if raw else None
    except urllib.error.HTTPError as ex:
        # 본문을 안 보여주면 「400」만 남아서 원인을 알 수 없다.
        detail = ex.read().decode("utf-8", "replace")[:400]
        raise SystemExit(f"{method} {path} → HTTP {ex.code}\n  {detail}") from None


def login():
    if not PW:
        sys.exit(
            "앱 비밀번호를 못 찾았다. 둘 중 하나로 준다 —\n\n"
            "  ① 키체인에 «한 번만» 넣어두기 (권장 · 기록에 안 남는다)\n"
            f'     security add-generic-password -a "$USER" -s {KEYCHAIN} -w\n'
            "     (입력한 글자는 화면에 안 보인다. 그 뒤로는 그냥 돌리면 된다)\n\n"
            "  ② 이번 한 번만 환경변수로\n"
            "     HY_PASSWORD='...' python3 knowledge/import.py")
    print(f"로그인: {EMAIL}")
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
