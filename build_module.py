#!/usr/bin/env python3
"""Build the tested SurfaceGuard Magisk module from a user-owned stock ODMF JAR."""

from __future__ import annotations

import hashlib
import io
import os
from pathlib import Path
import stat
import struct
import sys
import zlib
import zipfile


ORIGINAL_SHA = "628595d2cd39df8a47abc43c74a55232e3a4a0d92a02700821a02bcc1deb5e3d"
DEX_FIELD_INDEX_OFFSET = 0x590F2
EXPECTED_FIELD_INDEX = bytes.fromhex("0c07")  # sharedContext field@0x070c
PATCHED_FIELD_INDEX = bytes.fromhex("1007")   # surface field@0x0710
OUTPUT_NAME = "PadConnect_ODMF_SurfaceGuard_TB371FC_Magisk_v1.0.zip"


def sha256(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def patch_dex(dex_payload: bytes) -> bytes:
    dex = bytearray(dex_payload)
    before = bytes(dex[DEX_FIELD_INDEX_OFFSET:DEX_FIELD_INDEX_OFFSET + 2])
    if before != EXPECTED_FIELD_INDEX:
        raise ValueError(
            f"Unexpected DEX bytes at {DEX_FIELD_INDEX_OFFSET:#x}: {before.hex()}"
        )
    dex[DEX_FIELD_INDEX_OFFSET:DEX_FIELD_INDEX_OFFSET + 2] = PATCHED_FIELD_INDEX
    dex[12:32] = hashlib.sha1(dex[32:]).digest()
    struct.pack_into("<I", dex, 8, zlib.adler32(dex[12:]) & 0xFFFFFFFF)
    return bytes(dex)


def build_patched_jar(stock_jar: bytes) -> bytes:
    source = io.BytesIO(stock_jar)
    output = io.BytesIO()
    found = False
    with zipfile.ZipFile(source, "r") as zin, zipfile.ZipFile(output, "w") as zout:
        for old_info in zin.infolist():
            payload = zin.read(old_info.filename)
            if old_info.filename == "classes.dex":
                payload = patch_dex(payload)
                found = True
            info = zipfile.ZipInfo(old_info.filename, old_info.date_time)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = old_info.external_attr
            info.comment = old_info.comment
            info.extra = old_info.extra
            zout.writestr(info, payload)
    if not found:
        raise ValueError("classes.dex was not found in odmf.jar")
    return output.getvalue()


def zip_info(name: str, executable: bool = False) -> zipfile.ZipInfo:
    info = zipfile.ZipInfo(name)
    mode = stat.S_IFREG | (0o755 if executable else 0o644)
    info.external_attr = mode << 16
    info.compress_type = zipfile.ZIP_DEFLATED
    return info


def build_module(repo_dir: Path, patched_jar: bytes, output_path: Path) -> None:
    template_dir = repo_dir / "module-template"
    patched_sha = sha256(patched_jar)
    files = {
        "module.prop": (template_dir / "module.prop").read_bytes(),
        "customize.sh": (template_dir / "customize.sh").read_bytes().replace(
            b"@PATCHED_SHA@", patched_sha.encode("ascii")
        ),
        "post-fs-data.sh": (template_dir / "post-fs-data.sh").read_bytes(),
        "README_zh-CN.txt": (template_dir / "README_zh-CN.txt").read_bytes(),
        "system/system_ext/framework/oplusex/com.oplus.odmf/odmf.jar": patched_jar,
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output_path, "w") as archive:
        for name, payload in files.items():
            archive.writestr(
                zip_info(name, executable=name.endswith(".sh")), payload
            )
    print(f"Stock SHA-256:   {ORIGINAL_SHA}")
    print(f"Patched SHA-256: {patched_sha}")
    print(f"Output:           {output_path}")


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: python build_module.py path/to/stock_odmf.jar")
        return 2
    repo_dir = Path(__file__).resolve().parent
    stock_path = Path(sys.argv[1]).resolve()
    stock_jar = stock_path.read_bytes()
    actual_sha = sha256(stock_jar)
    if actual_sha != ORIGINAL_SHA:
        print("ERROR: Unsupported stock odmf.jar")
        print(f"Expected: {ORIGINAL_SHA}")
        print(f"Found:    {actual_sha}")
        return 1
    try:
        patched_jar = build_patched_jar(stock_jar)
        output_path = repo_dir / "dist" / OUTPUT_NAME
        build_module(repo_dir, patched_jar, output_path)
    except (OSError, ValueError, zipfile.BadZipFile) as error:
        print(f"ERROR: {error}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
