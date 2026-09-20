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

ROOT = Path(__file__).resolve().parents[2]
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
        for folder in ("addon/Lychee", "lychee-sdk"):
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
                self.assertTrue(all(n.startswith(name + "/") for n in z.namelist()))

    def test_extra_runtime_doc_rejected(self):
        (self.root / "addon/Lychee/AGENTS.md").write_text("not runtime")
        with self.assertRaisesRegex(ValueError, "unlisted"):
            release.paths(self.root)

    def test_missing_runtime_resource_rejected(self):
        (self.root / "addon/Lychee/Media/lychee-logo.tga").unlink()
        with self.assertRaisesRegex(ValueError, "missing"):
            release.paths(self.root)

    def test_declaring_a_document_does_not_make_it_runtime(self):
        (self.root / "addon/Lychee/AGENTS.md").write_text("not runtime")
        path = self.root / "tools/release_manifest.json"
        value = json.loads(path.read_text())
        value["runtimeFiles"].append("AGENTS.md")
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
        for name in ("../outside", "C:/outside", "/outside", "a\\b", original["runtimeFiles"][0]):
            modified = dict(original, runtimeFiles=original["runtimeFiles"] + [name])
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

    def test_current_code_paths_reject_deleted_tests(self):
        page = self.root / "guide.md"
        page.write_text('Use `tests/ui/deleted.lua` and `addon/Lychee/Bootstrap.lua`.\n'
                        'Example: `tests/<group>/example.lua` or `tests/*.lua`.\n'
                        '```lua\n`tests/example.lua`\n```\n')
        errors = docs.code_path_errors(self.root, [page])
        self.assertEqual(len(errors), 1)
        self.assertIn("tests/ui/deleted.lua", errors[0])

    def test_sdk_translation_missing_is_rejected(self):
        (self.root / "lychee-sdk/docs/en/INVOCATIONS.md").unlink()
        self.assertIn("SDK translation missing: docs/en/INVOCATIONS.md", docs.sdk_language_errors(self.root))

    def test_sdk_language_navigation_is_required(self):
        page = self.root / "lychee-sdk/docs/en/PROTOCOLS.md"
        page.write_text(page.read_text(encoding="utf-8").replace("../zh-CN/PROTOCOLS.md", "PROTOCOLS.md"), encoding="utf-8")
        self.assertIn("SDK language switch missing: docs/en/PROTOCOLS.md", docs.sdk_language_errors(self.root))

    def test_sdk_topic_must_be_discoverable(self):
        page = self.root / "lychee-sdk/README.en.md"
        page.write_text(page.read_text(encoding="utf-8").replace("docs/en/STORAGE.md", "docs/en/CATALOG.md"), encoding="utf-8")
        self.assertIn("SDK topic absent from README.en.md: STORAGE.md", docs.sdk_language_errors(self.root))

    def test_main_links_checked_but_historical_commit_links_preserved(self):
        page = self.root / "guide.md"
        page.write_text('[missing](https://github.com/Follen/Lychee/blob/main/tests/missing.lua)\n'
                        '[historical](https://github.com/Follen/Lychee/blob/1662562/tests/old.lua)\n')
        errors = docs.code_path_errors(self.root, [page])
        self.assertEqual(len(errors), 1)
        self.assertIn("missing main-branch link", errors[0])

    def test_plugin_version_is_independent_and_detects_stale_badge(self):
        (self.root / "tools/client_manifest.json").write_text('{"version":"0.2.2"}')
        for name in ("README.md", "README.en.md"):
            (self.root / name).write_text('![version](https://img.shields.io/badge/version-0.2.2-red)\n'
                                          '![API](https://img.shields.io/badge/API%201.0.0-blue)\n')
        self.assertEqual(docs.plugin_version_errors(self.root), [])
        (self.root / "README.md").write_text('![version](https://img.shields.io/badge/version-0.2.0-red)')
        self.assertEqual(docs.plugin_version_errors(self.root),
                         ["README.md: plugin version badge differs from client manifest"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
