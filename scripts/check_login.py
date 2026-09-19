#!/usr/bin/env python3
"""앱 계정 로그인이 «되는지»만 확인한다. 아무것도 바꾸지 않는다.

배치(GitHub Actions)가 invalid_credentials 로 계속 죽을 때,
«비밀번호가 틀린 건지 · 이메일이 다른 건지 · 시크릿 전달이 틀린 건지»를
가르려고 만들었다. 셋 다 같은 400 을 주기 때문에 로그만 봐선 모른다.

비밀번호는 화면에 안 보이고(getpass), 셸 기록·명령줄에도 안 남는다.
환경변수·키체인에 있으면 그걸 먼저 쓴다.

    python3 scripts/check_login.py                 # 물어본다
    python3 scripts/check_login.py --stored        # 키체인/환경변수 값으로만
"""
import getpass
import json
import os
import sys
import urllib.error
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from import_moa_pdf import ANON, SB, keychain_password  # noqa: E402


def try_login(email, password):
    req = urllib.request.Request(
        SB + "/auth/v1/token?grant_type=password", method="POST",
        data=json.dumps({"email": email, "password": password}).encode(),
        headers={"apikey": ANON, "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=30) as r:
            body = json.loads(r.read())
        return True, body.get("user", {}).get("email", email)
    except urllib.error.HTTPError as e:
        try:
            return False, json.loads(e.read()).get("msg", f"HTTP {e.code}")
        except Exception:  # noqa: BLE001
            return False, f"HTTP {e.code}"
    except Exception as ex:  # noqa: BLE001
        return False, str(ex)


def main():
    stored = '--stored' in sys.argv
    email = (os.environ.get("HY_EMAIL") or os.environ.get("AUTO_EMAIL") or "")
    pw = keychain_password() or os.environ.get("HY_PASSWORD") or \
        os.environ.get("AUTO_PASSWORD") or ""

    if stored:
        src = ("키체인" if keychain_password() else
               "HY_PASSWORD" if os.environ.get("HY_PASSWORD") else
               "AUTO_PASSWORD" if os.environ.get("AUTO_PASSWORD") else "없음")
        print(f"저장된 값으로 시도 — 이메일 «{email or '(없음)'}» · 비밀번호 출처 «{src}»")
        if not email or not pw:
            sys.exit("이메일이나 비밀번호가 없다. 그냥 돌려서 직접 입력해 보라.")
    else:
        d = email or "demo@hycapital.app"
        email = input(f"이메일 [{d}]: ").strip() or d
        pw = getpass.getpass("비밀번호 (화면에 안 보임): ")

    ok, msg = try_login(email, pw)
    print()
    if ok:
        print(f"✅ 로그인 성공 — {msg}")
        print("   이 조합은 맞다. GitHub 시크릿(AUTO_EMAIL·AUTO_PASSWORD)에")
        print("   «똑같이» 들어갔는지 보면 된다 — 앞뒤 공백·줄바꿈이 섞이기 쉽다.")
        print("     gh secret set AUTO_EMAIL")
        print("     gh secret set AUTO_PASSWORD")
    else:
        print(f"❌ 로그인 실패 — {msg}")
        print(f"   이메일 «{email}» 로 시도했다.")
        print("   · 이메일이 맞나? Supabase → Authentication → Users 에서 확인.")
        print("   · 비밀번호를 바꾼 게 «저장»됐나? 같은 화면에서 재설정할 수 있다.")


if __name__ == "__main__":
    main()
