# SPDX-License-Identifier: AGPL-3.0-or-later
"""Apply the pinned byte-offset patch to user-supplied original Apple TV JS."""

import argparse
import base64
import hashlib
import json
import os
from pathlib import Path


ROOT = Path(__file__).resolve().parent
PATCH_FILE = ROOT / "patches.json"


class PatchError(Exception):
    pass


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def load_and_apply(patch_doc: dict, name: str, original: bytes) -> bytes:
    spec = patch_doc["files"][name]
    if sha256(original) != spec["base_sha256"]:
        raise PatchError(f"E_BASE_HASH_{name}")
    edits = spec["edits"]
    previous_offset = len(original) + 1
    result = bytearray(original)
    for edit in edits:
        offset = edit["offset"]
        delete_length = edit["delete_length"]
        removed_sha = edit["removed_sha256"]
        inserted = base64.b64decode(edit["insert_base64"], validate=True)
        if not isinstance(offset, int) or not isinstance(delete_length, int):
            raise PatchError(f"E_EDIT_RANGE_{name}")
        if offset < 0 or delete_length < 0 or offset + delete_length > len(original):
            raise PatchError(f"E_EDIT_RANGE_{name}")
        if offset >= previous_offset:
            raise PatchError(f"E_EDIT_ORDER_{name}")
        if offset + delete_length > previous_offset:
            raise PatchError(f"E_EDIT_OVERLAP_{name}")
        removed = original[offset:offset + delete_length]
        if sha256(removed) != removed_sha:
            raise PatchError(f"E_REMOVED_HASH_{name}")
        result[offset:offset + delete_length] = inserted
        previous_offset = offset
    candidate = bytes(result)
    if sha256(candidate) != spec["target_sha256"]:
        raise PatchError(f"E_TARGET_HASH_{name}")
    return candidate


def build_outputs(source_dir: Path, patch_doc: dict) -> dict[str, bytes]:
    outputs = {}
    for name in ("main.js", "app.js"):
        source = source_dir / name
        if source.is_symlink() or not source.is_file():
            raise PatchError(f"E_SOURCE_TYPE_{name}")
        outputs[name] = load_and_apply(patch_doc, name, source.read_bytes())
    return outputs


def write_new_output(output_dir: Path, outputs: dict[str, bytes]) -> None:
    if output_dir.exists() or output_dir.is_symlink():
        raise PatchError("E_OUTPUT_EXISTS")
    created = False
    created_files = []
    try:
        output_dir.mkdir(mode=0o700)
        created = True
        for name in ("main.js", "app.js"):
            fd = os.open(output_dir / name, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            created_files.append(name)
            with os.fdopen(fd, "wb") as stream:
                stream.write(outputs[name])
                stream.flush()
                os.fsync(stream.fileno())
        fd = os.open(output_dir / "SHA256SUMS.json", os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        created_files.append("SHA256SUMS.json")
        with os.fdopen(fd, "wb") as stream:
            stream.write((json.dumps({name: sha256(outputs[name]) for name in outputs}, indent=2) + "\n").encode())
            stream.flush()
            os.fsync(stream.fileno())
    except BaseException:
        if created:
            for name in created_files:
                try:
                    (output_dir / name).unlink()
                except FileNotFoundError:
                    pass
            try:
                output_dir.rmdir()
            except OSError:
                pass
        raise


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input-dir", required=True, type=Path,
                        help="Directory containing the original main.js and app.js")
    parser.add_argument("--output-dir", required=True, type=Path,
                        help="New directory to create for the two locally generated files")
    args = parser.parse_args()
    try:
        patch_doc = json.loads(PATCH_FILE.read_text(encoding="utf-8"))
        outputs = build_outputs(args.input_dir, patch_doc)
        write_new_output(args.output_dir, outputs)
    except (OSError, ValueError, KeyError, PatchError) as exc:
        parser.exit(2, f"STOP:{exc}\n")
    print("PATCH_OUTPUT_CREATED", args.output_dir)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
