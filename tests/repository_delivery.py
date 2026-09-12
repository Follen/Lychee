"""Fail closed on broken docs, leaked files and unsafe/reproducibility-breaking delivery."""
import importlib.util
import io
import json
from pathlib import Path
import shutil
import sys
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.dont_write_bytecode = True


def load(name):
    spec = importlib.util.spec_from_file_location(name, ROOT / "tools" / (name + ".py"))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


release = load("build_release")
docs = load("check_repository")


class RepositoryDelivery(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="lychee-delivery-")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name).resolve()
        assert self.root.parent == Path(tempfile.gettempdir()).resolve()
        for folder in ("addon", "lychee-sdk"):
            shutil.copytree(ROOT / folder, self.root / folder)
        (self.root / "tools").mkdir()
        for name in ("release_manifest.json", "sdk_contract.json"):
            shutil.copyfile(ROOT / "tools" / name, self.root / "tools" / name)

    def test_exact_reproducible_archives(self):
        for name, files in release.paths(self.root).items():
            first = release.archive(files)
            self.assertEqual(first, release.archive(files))
            with zipfile.ZipFile(io.BytesIO(first)) as z:
                self.assertEqual(z.namelist(), [entry for _, entry in files])
                self.assertTrue(all(n.split("/")[0] in ({"Lychee","Lychee_Player","Lychee_Encounters","Lychee_Integrations","Lychee_Inspector"} if name=="Lychee" else {name}) for n in z.namelist()))

    def test_extra_runtime_doc_rejected(self):
        (self.root / "addon/Lychee/AGENTS.md").write_text("not runtime")
        with self.assertRaisesRegex(ValueError, "unlisted"):
            release.paths(self.root)

    def test_unlisted_sixth_package_rejected(self):
        (self.root / "addon/Unexpected").mkdir()
        with self.assertRaisesRegex(ValueError, "unlisted runtime package"):
            release.paths(self.root)

    def test_missing_child_file_rejected(self):
        (self.root / "addon/Lychee_Inspector/Provider.lua").unlink()
        with self.assertRaisesRegex(ValueError, "missing"):
            release.paths(self.root)

    def test_embedded_sdk_drift_rejected(self):
        p = self.root / "addon/Lychee_Player/SDK/Storage.lua"
        p.write_bytes(p.read_bytes() + b"\n-- drift\n")
        with self.assertRaisesRegex(ValueError, "Storage drift"):
            release.paths(self.root)

    def test_cross_package_toc_rejected(self):
        p = self.root / "addon/Lychee_Inspector/Lychee_Inspector.toc"
        p.write_text(p.read_text() + "\n../Lychee_Player/Storage.lua\n")
        with self.assertRaisesRegex(ValueError, "TOC dependency"):
            release.paths(self.root)

    def test_missing_runtime_resource_rejected(self):
        (self.root / "addon/Lychee/Media/lychee-logo.tga").unlink()
        with self.assertRaisesRegex(ValueError, "missing"):
            release.paths(self.root)

    def test_declaring_a_document_does_not_make_it_runtime(self):
        (self.root / "addon/Lychee/AGENTS.md").write_text("not runtime")
        path = self.root / "tools/release_manifest.json"
        value = json.loads(path.read_text())
        value["packages"]["Lychee"].append("AGENTS.md")
        path.write_text(json.dumps(value))
        with self.assertRaisesRegex(ValueError, "non-runtime"):
            release.paths(self.root)

    def test_toc_cannot_reference_unshipped_file(self):
        path = self.root / "addon/Lychee/Lychee.toc"
        path.write_text(path.read_text() + "\nMissing.lua\n")
        with self.assertRaisesRegex(ValueError, "TOC dependency"):
            release.paths(self.root)

    def test_unlisted_sdk_file_rejected(self):
        (self.root / "lychee-sdk/accidental.txt").write_text("not listed")
        with self.assertRaisesRegex(ValueError, "unlisted"):
            release.paths(self.root)

    def test_unsafe_and_duplicate_paths_rejected(self):
        path = self.root / "tools/release_manifest.json"
        original = json.loads(path.read_text())
        for name in ("../outside", "C:/outside", "/outside", "a\\b", original["packages"]["Lychee"][0]):
            modified = json.loads(json.dumps(original))
            modified["packages"]["Lychee"].append(name)
            path.write_text(json.dumps(modified))
            with self.assertRaises(ValueError):
                release.paths(self.root)

    def test_broken_link_and_anchor_rejected(self):
        page = self.root / "page.md"
        page.write_text("# Page\n\n[bad](missing.md)\n[bad anchor](#absent)\n")
        self.assertEqual(len(docs.document_errors(self.root, [page])), 2)

    def test_sdk_cannot_depend_on_outer_docs(self):
        page = self.root / "lychee-sdk/page.md"
        (self.root / "outside.md").write_text("# Outside\n")
        page.write_text("[bad](../outside.md)\n")
        self.assertIn("outer repository", docs.document_errors(self.root, [page])[0])

    def test_valid_anchors_and_code_examples(self):
        page = self.root / "page.md"
        page.write_text('# 标题\n\n<a id="stable"></a>\n[ok](#stable)\n[ok](#标题)\n```lua\n[example](not-a-file)\n```\n', encoding="utf-8")
        self.assertEqual(docs.document_errors(self.root, [page]), [])


if __name__ == "__main__":
    unittest.main(verbosity=2)
