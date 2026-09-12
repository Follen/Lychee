"""SDK delivery contract regression: real checker, isolated mutated artifacts."""
from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.dont_write_bytecode = True
spec = importlib.util.spec_from_file_location("sdk_builder", ROOT / "tools/build_sdk.py")
builder = importlib.util.module_from_spec(spec)
spec.loader.exec_module(builder)


class DeliveryContractTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="lychee-sdk-contract-")
        self.root = Path(self.temporary.name).resolve()
        # Only this resolved, newly owned OS temporary directory is cleaned up.
        assert self.root.parent == Path(tempfile.gettempdir()).resolve()
        self.addCleanup(self.temporary.cleanup)
        shutil.copytree(ROOT / "lychee-sdk", self.root / "lychee-sdk")
        for name in ("tools/sdk_contract.json", "addon/Lychee/Bootstrap.lua", "PERFORMANCE.md"):
            target = self.root / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / name, target)

    def change(self, name, before, after):
        path = self.root / name
        text = path.read_text(encoding="utf-8")
        self.assertIn(before, text)
        path.write_text(text.replace(before, after, 1), encoding="utf-8")

    def reject(self, path):
        errors = builder.run(self.root)
        self.assertTrue(any(path in error for error in errors), errors)

    def test_repository_matches_contract(self):
        self.assertEqual(builder.run(ROOT), [])

    def test_generated_performance_drift(self):
        self.change("lychee-sdk/docs/PERFORMANCE.md", "性能硬门禁", "错误副本")
        self.reject("PERFORMANCE.md")

    def test_host_only_drift(self):
        self.change("addon/Lychee/Bootstrap.lua", "api = 2, revision = 7", "api = 2, revision = 6")
        self.reject("Bootstrap.lua")

    def test_types_only_drift(self):
        self.change("lychee-sdk/ApiStubs.lua", "---@field API_REVISION 7", "---@field API_REVISION 6")
        self.reject("ApiStubs.lua")

    def test_helper_only_drift(self):
        self.change("lychee-sdk/LycheeAPI.lua", "API_REVISION=7", "API_REVISION=6")
        self.reject("LycheeAPI.lua")

    def test_helper_floor_drift(self):
        self.change("lychee-sdk/LycheeAPI.lua", "MIN_API_REVISION=6", "MIN_API_REVISION=7")
        self.reject("LycheeAPI.lua")

    def test_helper_default_behavior_drift(self):
        self.change("lychee-sdk/LycheeAPI.lua", "minRevision=API.MIN_API_REVISION", "minRevision=API.API_REVISION")
        self.reject("LycheeAPI.lua")

    def test_helper_error_code_drift(self):
        self.change("lychee-sdk/LycheeAPI.lua", '"RESOURCE_LIMIT"', '"LOST_RESOURCE_LIMIT"')
        self.reject("LycheeAPI.lua")

    def test_missing_required_docs_and_example(self):
        for name in ("docs/MANAGED_RESOURCES.md", "examples/ManagedProvider.lua"):
            (self.root / "lychee-sdk" / name).unlink()
            self.reject(name)

    def test_manifest_omission(self):
        self.change("lychee-sdk/manifest.yaml", "  - examples/ManagedProvider.lua\n", "")
        self.reject("manifest.yaml")

    def test_unlisted_added_file(self):
        (self.root / "lychee-sdk/forgotten.md").write_text("Must be delivered", encoding="utf-8")
        self.reject("forgotten.md")

    def test_unsafe_contract_path(self):
        path = self.root / "tools/sdk_contract.json"
        data = json.loads(path.read_text(encoding="utf-8"))
        data["contents"].append("../outside.txt")
        path.write_text(json.dumps(data), encoding="utf-8")
        with self.assertRaisesRegex(ValueError, "invalid SDK delivery path"):
            builder.run(self.root)

    def test_write_repairs_declarations_without_changing_other_host_code(self):
        host = self.root / "addon/Lychee/Bootstrap.lua"
        self.change("addon/Lychee/Bootstrap.lua", "api = 2, revision = 7", "api = 2, revision = 6")
        host.write_text(host.read_text(encoding="utf-8") + "\n-- preserved fixture marker\n", encoding="utf-8")
        self.assertEqual(builder.run(self.root, write=True), [])
        self.assertEqual(builder.run(self.root), [])
        self.assertTrue(host.read_text(encoding="utf-8").endswith("-- preserved fixture marker\n"))

    def test_check_is_read_only(self):
        self.change("lychee-sdk/LycheeAPI.lua", "API_REVISION=7", "API_REVISION=6")
        before = {p.relative_to(self.root): p.read_bytes() for p in self.root.rglob("*") if p.is_file()}
        self.reject("LycheeAPI.lua")
        after = {p.relative_to(self.root): p.read_bytes() for p in self.root.rglob("*") if p.is_file()}
        self.assertEqual(before, after)

    def test_legal_floor_six_with_real_lua_helper(self):
        self.assertEqual(builder.run(self.root), [])
        helper_path = json.dumps((self.root / "lychee-sdk/LycheeAPI.lua").as_posix())
        script = f"""
local helper=dofile({helper_path})
assert(helper.API_VERSION==2 and helper.API_REVISION==7 and helper.MIN_API_REVISION==6)
local requested
local old={{Supports=function(_,version,revision) requested=revision;return version==2 and revision<=6 end}}
assert(helper.Supports(old) and requested==6)
local ok,err=helper.Supports(old,2,7)
assert(not ok and err.code=='UNSUPPORTED_API' and requested==7)
assert(helper.Supports({{Supports=function(_,version,revision) return version==2 and revision<=7 end}},2,7))
for _,code in ipairs({{'RESOURCE_CLOSED','RESOURCE_REENTRANT','RESOURCE_LIMIT','RESOURCE_UNAVAILABLE',
 'INVALID_EVENT','INVALID_SETTINGS','DATA_LIMIT','SECRET_VALUE','INACCESSIBLE_VALUE'}}) do
 assert(helper.ERROR_CODES[code]==code)
end
print('SDK helper current 7 / default floor 6 / explicit feature requirement PASS')
"""
        result = subprocess.run(["lua", "-"], input=script, text=True, encoding="utf-8", capture_output=True, cwd=self.root)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main(verbosity=2)
