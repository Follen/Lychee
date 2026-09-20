"""Generate/check SDK declarations from one build-time contract. Never package/publish."""
from __future__ import annotations

import argparse
import json
from pathlib import Path, PurePosixPath
import re
import sys
from urllib.parse import quote


def performance_document(root: Path) -> str:
    """One authoritative policy; standalone SDK links point to the source repository."""
    text = (root / "PERFORMANCE.md").read_text(encoding="utf-8")
    def link(match):
        target = match[1]
        if re.match(r"[a-zA-Z][a-zA-Z0-9+.-]*:", target) or target.startswith("#"):
            return match[0]
        path, separator, fragment = target.partition("#")
        return "](https://github.com/Follen/Lychee/blob/main/" + quote(path, safe="/") + (separator + fragment if separator else "") + ")"
    text = re.sub(r"\]\(([^\s)]+)\)", link, text)
    return "<!-- Generated from root PERFORMANCE.md by tools/build_sdk.py; do not edit. -->\n\n" + text

DEFAULT_ROOT = Path(__file__).resolve().parents[1]

# These modules implement public SDK operations. This deliberately does not
# scan Provider business errors or Blizzard's open-ended LoadAddOn reasons.
ERROR_SOURCES = (
    "addon/Lychee/Core/InvocationRuntime.lua", "addon/Lychee/Core/Catalog.lua",
    "addon/Lychee/Core/Preparation.lua", "addon/Lychee/Core/ProviderRuntime.lua",
    "addon/Lychee/PublicAPI/Invocation.lua", "lychee-sdk/Storage.lua",
    "lychee-sdk/CompactStore.lua",
)


def error_code_errors(root: Path, contract: dict) -> list[str]:
    """Catch literal public error additions omitted from the shipped helper.

    This is a drift check, not a Lua parser or proof of all possible errors.
    Dynamic Provider and native errors remain an open set.
    """
    known = set(contract["errorCodes"])
    errors = []
    pattern = r'''(?:\bcode\s*=\s*|\b(?:failure|fail)\(\s*)["']([A-Z][A-Z_]+)["']'''
    for name in ERROR_SOURCES:
        path = root / name
        if not path.is_file():
            errors.append(f"SDK error source missing: {name}")
            continue
        codes = set(re.findall(pattern, path.read_text(encoding="utf-8")))
        for code in sorted(codes - known):
            errors.append(f"{name}: SDK error code absent from contract: {code}")
    return errors


def contract_at(root: Path) -> dict:
    contract = json.loads((root / "tools/sdk_contract.json").read_text(encoding="utf-8"))
    if contract.get("schemaVersion") != 1:
        raise ValueError("unsupported SDK contract schema")
    if not re.fullmatch(r"\d+\.\d+\.\d+", str(contract.get("sdkVersion", ""))):
        raise ValueError("invalid SDK release version")
    if contract.get("apiVersion") != contract["sdkVersion"]:
        raise ValueError("SDK and API must share one semantic version")
    if "apiRevision" in contract or "helperMinimumRevision" in contract:
        raise ValueError("retired revision fields are not supported")
    contents = contract.get("contents")
    if not isinstance(contents, list) or not contents or any(not isinstance(p, str) for p in contents):
        raise ValueError("contents must be a nonempty list of relative SDK paths")
    if len(set(contents)) != len(contents):
        raise ValueError("duplicate SDK delivery file")
    for name in contents:
        path = PurePosixPath(name)
        if path.is_absolute() or ".." in path.parts or "\\" in name or ":" in name or str(path) != name:
            raise ValueError(f"invalid SDK delivery path: {name}")
        if name == "manifest.yaml":
            raise ValueError("manifest.yaml is included implicitly, not in its own contents")
    codes = contract.get("errorCodes")
    if (not isinstance(codes, list) or not codes or len(set(codes)) != len(codes)
            or any(not isinstance(code, str) or not re.fullmatch(r"[A-Z][A-Z_]+", code) for code in codes)):
        raise ValueError("invalid SDK error code list")
    return contract


def replace_one(text: str, pattern: str, value: str, path: str) -> str:
    text, count = re.subn(pattern, lambda _: value, text, flags=re.MULTILINE | re.DOTALL)
    if count != 1:
        raise ValueError(f"{path}: expected exactly one generated declaration, found {count}")
    return text


def expected_files(root: Path, contract: dict) -> dict[str, str]:
    version = contract["apiVersion"]
    host_path = "addon/Lychee/Bootstrap.lua"
    host = (root / host_path).read_text(encoding="utf-8")
    host = replace_one(host, r'^I\.VERSION = \{ api = "[\d.]+" \}$',
                       f'I.VERSION = {{ api = "{version}" }}', host_path)
    facade_path = "addon/Lychee/PublicAPI/SDK.lua"
    facade = (root / facade_path).read_text(encoding="utf-8")
    facade = replace_one(facade, r'local SDK=\{VERSION="[\d.]+",',
                         f'local SDK={{VERSION="{contract["sdkVersion"]}",', facade_path)
    types_path = "lychee-sdk/ApiStubs.lua"
    types = (root / types_path).read_text(encoding="utf-8")
    types = replace_one(types, r"^-- Editor-only API [\d.]+ declarations\.",
                        f"-- Editor-only API {version} declarations.", types_path)
    for field in ("API_VERSION", "apiVersion"):
        types = replace_one(types, rf'^---@field {field} "[\d.]+"$', f'---@field {field} "{version}"', types_path)
    types = replace_one(types, r"^---@field VERSION '[\d.]+'$",
                        f"---@field VERSION '{contract['sdkVersion']}'", types_path)
    helper_path = "lychee-sdk/LycheeAPI.lua"
    helper = (root / helper_path).read_text(encoding="utf-8")
    helper = replace_one(helper,
                         r'^local API = \{ API_VERSION="[\d.]+", ERROR_CODES=\{\} \}$',
                         f'local API = {{ API_VERSION="{version}", ERROR_CODES={{}} }}',
                         helper_path)
    code_lines = []
    for start in range(0, len(contract["errorCodes"]), 4):
        code_lines.append("    " + ", ".join(json.dumps(code) for code in contract["errorCodes"][start:start + 4]))
    helper = replace_one(helper, r"for _, code in ipairs\(\{.*?\}\) do",
                         "for _, code in ipairs({\n" + ",\n".join(code_lines) + "\n}) do", helper_path)
    helper = replace_one(helper, r"if apiVersion==nil then apiVersion=API\.[A-Z_]+ end",
                         "if apiVersion==nil then apiVersion=API.API_VERSION end", helper_path)
    manifest = ("# Generated by tools/build_sdk.py from tools/sdk_contract.json.\n"
                "name: lychee-sdk\nkind: development-package\nruntimeAddon: false\n"
                "hostAddon: Lychee\nfacade: _G.Lychee\n"
                f"sdkVersion: {contract['sdkVersion']}\n"
                f'apiVersion: "{version}"\ncontents:\n')
    manifest += "".join(f"  - {name}\n" for name in contract["contents"])
    return {host_path: host, facade_path: facade, types_path: types, helper_path: helper, "lychee-sdk/manifest.yaml": manifest,
            "lychee-sdk/docs/PERFORMANCE.md": performance_document(root),
            "addon/Lychee/SDK/CompactStore.lua": (root / "lychee-sdk/CompactStore.lua").read_text(encoding="utf-8")}


def delivery_errors(root: Path, contract: dict) -> list[str]:
    sdk = root / "lychee-sdk"
    actual = {p.relative_to(sdk).as_posix() for p in sdk.rglob("*") if p.is_file()}
    declared = set(contract["contents"]) | {"manifest.yaml"}
    return ([f"required SDK file missing: {name}" for name in sorted(declared - actual)]
            + [f"SDK file absent from delivery contract: {name}" for name in sorted(actual - declared)])


def run(root: Path, write: bool = False) -> list[str]:
    """Return actionable violations; write only generated fields when explicitly requested."""
    contract = contract_at(root)
    errors = delivery_errors(root, contract) + error_code_errors(root, contract)
    if errors:
        return errors
    generated = expected_files(root, contract)
    for name, expected in generated.items():
        path = root / name
        actual = path.read_text(encoding="utf-8")
        byte_drift = name == "addon/Lychee/SDK/CompactStore.lua" and path.read_bytes() != (root / "lychee-sdk/CompactStore.lua").read_bytes()
        if actual != expected or byte_drift:
            if write:
                if name == "addon/Lychee/SDK/CompactStore.lua":
                    path.write_bytes((root / "lychee-sdk/CompactStore.lua").read_bytes())
                else:
                    path.write_text(expected, encoding="utf-8", newline="\n")
            else:
                errors.append(f"SDK declaration drift: {name} (run python tools/build_sdk.py --write)")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--check", action="store_true", help="read-only consistency check (default)")
    mode.add_argument("--write", action="store_true", help="update generated declarations; no archive or publication")
    parser.add_argument("--root", type=Path, default=DEFAULT_ROOT)
    args = parser.parse_args()
    try:
        errors = run(args.root.resolve(), write=args.write)
    except (OSError, ValueError, KeyError, TypeError) as error:
        errors = [str(error)]
    if errors:
        print("SDK contract FAILED", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1
    print("SDK contract PASS: unified SDK/API version, Host/types/helper and complete delivery inventory")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
