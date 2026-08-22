#!/usr/bin/env python3
"""Build PadConnect ODMF SurfaceGuard + Display Guard from a user-owned stock ODMF JAR."""

from __future__ import annotations

import hashlib
import io
from pathlib import Path
import stat
import struct
import sys
import zlib
import zipfile

ORIGINAL_SHA = "628595d2cd39df8a47abc43c74a55232e3a4a0d92a02700821a02bcc1deb5e3d"
EXPECTED_PATCHED_SHA = "28f9b4cb8df1b5d2c6f7605470274e0dd356af9da622c3e819ffb96a784cc789"
DEX_FIELD_INDEX_OFFSET = 0x590F2
EXPECTED_FIELD_INDEX = bytes.fromhex("0c07")  # sharedContext field@0x070c
PATCHED_FIELD_INDEX = bytes.fromhex("1007")   # surface field@0x0710
OUTPUT_NAME = "PadConnect_ODMF_SurfaceGuard_Compatibility_TB371FC_Magisk_v1.1-test.zip"


def sha256(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def patch_dex(dex_payload: bytes) -> bytes:
    dex = bytearray(dex_payload)
    if len(dex) < DEX_FIELD_INDEX_OFFSET + 2:
        raise ValueError("classes.dex is smaller than expected")

    before = bytes(dex[DEX_FIELD_INDEX_OFFSET:DEX_FIELD_INDEX_OFFSET + 2])
    if before != EXPECTED_FIELD_INDEX:
        raise ValueError(
            f"Unexpected DEX bytes at {DEX_FIELD_INDEX_OFFSET:#x}: {before.hex()}"
        )

    dex[DEX_FIELD_INDEX_OFFSET:DEX_FIELD_INDEX_OFFSET + 2] = PATCHED_FIELD_INDEX

    # Recalculate DEX signature and Adler-32 checksum after the 2-byte patch.
    dex[12:32] = hashlib.sha1(dex[32:]).digest()
    struct.pack_into("<I", dex, 8, zlib.adler32(dex[12:]) & 0xFFFFFFFF)
    return bytes(dex)


def build_patched_jar(stock_jar: bytes) -> bytes:
    source = io.BytesIO(stock_jar)
    output = io.BytesIO()
    found_classes = False

    with zipfile.ZipFile(source, "r") as zin, zipfile.ZipFile(output, "w") as zout:
        for old_info in zin.infolist():
            payload = zin.read(old_info.filename)
            if old_info.filename == "classes.dex":
                payload = patch_dex(payload)
                found_classes = True

            info = zipfile.ZipInfo(old_info.filename, old_info.date_time)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = old_info.external_attr
            info.comment = old_info.comment
            info.extra = old_info.extra
            zout.writestr(info, payload)

    if not found_classes:
        raise ValueError("classes.dex was not found in odmf.jar")

    patched = output.getvalue()
    patched_sha = sha256(patched)
    if patched_sha != EXPECTED_PATCHED_SHA:
        raise ValueError(
            "Patched ODMF SHA mismatch. "
            f"Expected {EXPECTED_PATCHED_SHA}, found {patched_sha}"
        )
    return patched


def zip_info(name: str, executable: bool = False) -> zipfile.ZipInfo:
    info = zipfile.ZipInfo(name)
    mode = stat.S_IFREG | (0o755 if executable else 0o644)
    info.external_attr = mode << 16
    info.compress_type = zipfile.ZIP_DEFLATED
    return info


def render_template(path: Path, patched_sha: str) -> bytes:
    return path.read_bytes().replace(b"@PATCHED_SHA@", patched_sha.encode("ascii"))


def build_module(repo_dir: Path, patched_jar: bytes, output_path: Path) -> None:
    template = repo_dir / "module-template"
    patched_sha = sha256(patched_jar)

    files = {
        "module.prop": render_template(template / "module.prop", patched_sha),
        "customize.sh": render_template(template / "customize.sh", patched_sha),
        "post-fs-data.sh": render_template(template / "post-fs-data.sh", patched_sha),
        "service.sh": render_template(template / "service.sh", patched_sha),
        "uninstall.sh": render_template(template / "uninstall.sh", patched_sha),
        "README_zh-CN.txt": render_template(template / "README_zh-CN.txt", patched_sha),
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
    stock_path = Path(sys.argv[1]).expanduser().resolve()

    if not stock_path.is_file():
        print(f"ERROR: file not found: {stock_path}")
        return 1

    try:
        stock_jar = stock_path.read_bytes()
        actual_sha = sha256(stock_jar)
        if actual_sha != ORIGINAL_SHA:
            print("ERROR: Unsupported stock odmf.jar")
            print(f"Expected: {ORIGINAL_SHA}")
            print(f"Found:    {actual_sha}")
            return 1

        patched_jar = build_patched_jar(stock_jar)
        build_module(repo_dir, patched_jar, repo_dir / "dist" / OUTPUT_NAME)
    except (OSError, ValueError, zipfile.BadZipFile) as error:
        print(f"ERROR: {error}")
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
