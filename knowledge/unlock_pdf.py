#!/usr/bin/env python3
# /// script
# requires-python = ">=3.9"
# dependencies = ["pypdf>=4.0"]
# ///
"""암호가 걸린 PDF를 macOS 키체인의 암호로 열어 복호화 사본을 만든다.

암호는 이 파일에도, 저장소에도, 대화에도 남지 않는다. 키체인에만 있다.

한 번만 등록 (입력한 글자는 화면에 안 보인다):
    security add-generic-password -a "$USER" -s hy-pdf-lecture -w

그 다음부터는 자동:
    python3 knowledge/unlock_pdf.py '~/Downloads/강의자료.protected.pdf'

    → 같은 폴더에 .unlocked.pdf 생성. 그 뒤 /hy-knowledge 로 자료실에 넣는다.

다른 자료에 다른 암호를 쓰면 --service 로 키체인 항목을 구분한다.
"""
import argparse
import os
import subprocess
import sys

DEFAULT_SERVICE = "hy-pdf-lecture"


def keychain_password(service: str) -> str:
    """키체인에서 암호를 읽는다. 없으면 등록 방법을 알려주고 종료."""
    r = subprocess.run(
        ["security", "find-generic-password", "-s", service, "-w"],
        capture_output=True, text=True,
    )
    if r.returncode != 0:
        sys.exit(
            f"키체인에 '{service}' 항목이 없습니다.\n"
            f"먼저 한 번 등록하세요 (입력한 글자는 화면에 안 보입니다):\n\n"
            f'  security add-generic-password -a "$USER" -s {service} -w\n'
        )
    return r.stdout.rstrip("\n")


def main() -> None:
    p = argparse.ArgumentParser(description="암호 걸린 PDF 복호화")
    p.add_argument("pdf", help="암호가 걸린 PDF 경로")
    p.add_argument("-s", "--service", default=DEFAULT_SERVICE,
                   help=f"키체인 서비스 이름 (기본 {DEFAULT_SERVICE})")
    p.add_argument("-o", "--out", help="출력 경로 (기본: 원본 옆 .unlocked.pdf)")
    args = p.parse_args()

    src = os.path.expanduser(args.pdf)
    if not os.path.isfile(src):
        sys.exit(f"파일이 없습니다: {src}")

    try:
        from pypdf import PdfReader, PdfWriter
    except ImportError:
        sys.exit("pypdf 가 필요합니다:  pip3 install pypdf")

    reader = PdfReader(src)
    if not reader.is_encrypted:
        print("암호가 걸려 있지 않습니다. 그대로 쓰면 됩니다.")
        return

    if not reader.decrypt(keychain_password(args.service)):
        sys.exit(
            f"암호가 맞지 않습니다.\n"
            f"키체인 값을 바꾸려면:\n\n"
            f'  security delete-generic-password -s {args.service}\n'
            f'  security add-generic-password -a "$USER" -s {args.service} -w\n'
        )

    base = src[:-4] if src.lower().endswith(".pdf") else src
    out = os.path.expanduser(args.out) if args.out else base + ".unlocked.pdf"

    writer = PdfWriter()
    for page in reader.pages:
        writer.add_page(page)
    with open(out, "wb") as f:
        writer.write(f)

    print(f"열었습니다 ({len(reader.pages)}쪽) → {out}")
    print("이제 /hy-knowledge 로 자료실에 넣으면 됩니다.")
    print("주의: 이 사본에는 암호가 없습니다. 공개 저장소에 커밋하지 마세요.")


if __name__ == "__main__":
    main()
