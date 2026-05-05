#!/usr/bin/env python3
import argparse
import re
from pathlib import Path


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Patch OpenWrt shadowsocks-libev package metadata for SIP003U builds."
    )
    parser.add_argument("makefile", type=Path)
    parser.add_argument("--pkg-version", required=True)
    parser.add_argument("--pkg-release", required=True)
    parser.add_argument("--source-url", required=True)
    parser.add_argument("--source-version", required=True)
    parser.add_argument("--ss-rules-ip-dep", required=True)
    args = parser.parse_args()

    text = args.makefile.read_text()

    source_block = (
        f"PKG_VERSION:={args.pkg_version}\n"
        f"PKG_RELEASE:={args.pkg_release}\n"
        "\n"
        "PKG_SOURCE_PROTO:=git\n"
        f"PKG_SOURCE_URL:={args.source_url}\n"
        "PKG_SOURCE_DATE:=2026-05-05\n"
        f"PKG_SOURCE_VERSION:={args.source_version}\n"
        "PKG_MIRROR_HASH:=skip"
    )

    text, count = re.subn(
        r"PKG_VERSION:=[^\n]*\n"
        r"PKG_RELEASE:=[^\n]*\n\n"
        r"PKG_SOURCE:=[^\n]*\n"
        r"PKG_SOURCE_URL:=[^\n]*\n"
        r"PKG_HASH:=[^\n]*",
        source_block,
        text,
        count=1,
    )
    if count != 1:
        raise SystemExit("failed to replace PKG_SOURCE block")

    text = text.replace("\t   +ip \\\n", f"\t   +{args.ss_rules_ip_dep} \\\n", 1)

    args.makefile.write_text(text)


if __name__ == "__main__":
    main()

