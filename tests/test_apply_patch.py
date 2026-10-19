# SPDX-License-Identifier: AGPL-3.0-or-later
import base64
import hashlib
import importlib.util
from pathlib import Path
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("apply_patch", ROOT / "apply_patch.py")
module = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(module)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def patch_spec(original, replacement, offset):
    removed = original[offset:offset + len(replacement[0])]
    return {
        "base_sha256": sha(original),
        "target_sha256": sha(original[:offset] + replacement[1] + original[offset + len(removed):]),
        "edits": [{
            "offset": offset,
            "delete_length": len(removed),
            "removed_sha256": sha(removed),
            "insert_base64": base64.b64encode(replacement[1]).decode("ascii"),
        }],
    }


class PatchTests(unittest.TestCase):
    def test_synthetic_patch_and_multiple_reverse_offsets(self):
        original = b"alpha-middle-omega"
        replacement = (b"middle", b"new")
        offset = original.index(replacement[0])
        doc = {"files": {"main.js": patch_spec(original, replacement, offset)}}
        self.assertEqual(module.load_and_apply(doc, "main.js", original), b"alpha-new-omega")

    def test_edits_apply_from_highest_offset_and_reject_overlap(self):
        original = b"AA-first-BB-second-CC"
        edits = []
        for old, new in ((b"first", b"one"), (b"second", b"two")):
            offset = original.index(old)
            edits.append({"offset": offset, "delete_length": len(old),
                          "removed_sha256": sha(old),
                          "insert_base64": base64.b64encode(new).decode("ascii")})
        edits.sort(key=lambda item: item["offset"], reverse=True)
        doc = {"files": {"main.js": {"base_sha256": sha(original),
              "target_sha256": sha(b"AA-one-BB-two-CC"), "edits": edits}}}
        self.assertEqual(module.load_and_apply(doc, "main.js", original), b"AA-one-BB-two-CC")
        overlapping = dict(doc["files"]["main.js"])
        overlapping["edits"] = [dict(edits[0]), dict(edits[1])]
        overlapping["edits"][1]["delete_length"] = edits[0]["offset"] - edits[1]["offset"] + 1
        with self.assertRaisesRegex(module.PatchError, "E_EDIT_OVERLAP_main.js"):
            module.load_and_apply({"files": {"main.js": overlapping}}, "main.js", original)

    def test_wrong_base_refused(self):
        original = b"safe fixture"
        doc = {"files": {"main.js": patch_spec(original, (b"fixture", b"changed"), 5)}}
        with self.assertRaisesRegex(module.PatchError, "E_BASE_HASH_main.js"):
            module.load_and_apply(doc, "main.js", b"other fixture")

    def test_removed_bytes_must_match(self):
        original = b"prefix-expected-suffix"
        doc = {"files": {"main.js": patch_spec(original, (b"expected", b"edited"), 7)}}
        edit = doc["files"]["main.js"]["edits"][0]
        edit["removed_sha256"] = sha(b"different")
        with self.assertRaisesRegex(module.PatchError, "E_REMOVED_HASH_main.js"):
            module.load_and_apply(doc, "main.js", original)

    def test_output_is_exclusive_and_both_inputs_validate_first(self):
        original = b"original"
        doc = {"files": {
            name: patch_spec(original, (b"ginal", b"patched"), 3)
            for name in ("main.js", "app.js")
        }}
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source = root / "input"
            source.mkdir()
            (source / "main.js").write_bytes(original)
            (source / "app.js").write_bytes(b"wrong base")
            output = root / "out"
            with self.assertRaisesRegex(module.PatchError, "E_BASE_HASH_app.js"):
                outputs = module.build_outputs(source, doc)
                module.write_new_output(output, outputs)
            self.assertFalse(output.exists())
            (source / "app.js").write_bytes(original)
            outputs = module.build_outputs(source, doc)
            module.write_new_output(output, outputs)
            self.assertEqual((output / "main.js").read_bytes(), b"oripatched")
            with self.assertRaisesRegex(module.PatchError, "E_OUTPUT_EXISTS"):
                module.write_new_output(output, outputs)


if __name__ == "__main__":
    unittest.main()
