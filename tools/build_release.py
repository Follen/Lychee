"""Check or build explicit Lychee and standalone SDK archives; never install/publish."""
from __future__ import annotations
import argparse
import hashlib
import io
import json
from pathlib import Path, PurePosixPath
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def paths(root: Path) -> dict[str, list[tuple[Path, str]]]:
    spec = json.loads((root / "tools/release_manifest.json").read_text(encoding="utf-8"))
    sdk = json.loads((root / "tools/sdk_contract.json").read_text(encoding="utf-8"))
    packages = ("Lychee", "Lychee_Player", "Lychee_Encounters", "Lychee_Integrations", "Lychee_Inspector")
    if spec.get("schemaVersion") != 2 or set(spec.get("packages", {})) != set(packages):
        raise ValueError("invalid release schema")
    if {p.name for p in (root / "addon").iterdir()} != set(packages):
        raise ValueError("unlisted runtime package")
    if (root / "addon/Lychee_Player/SDK/Storage.lua").read_bytes() != (root / "lychee-sdk/Storage.lua").read_bytes():
        raise ValueError("embedded SDK Storage drift")
    plans = {"Lychee": []}
    sources = [("addon/" + name, name, spec["packages"][name]) for name in packages]
    sources.append(("lychee-sdk", "lychee-sdk", sdk["contents"] + ["manifest.yaml"]))
    for folder, prefix, declared in sources:
        runtime = prefix != "lychee-sdk"
        base = root / folder
        if base.is_symlink() or base.resolve() != base.absolute():
            raise ValueError("linked package root: " + folder)
        if len(set(declared)) != len(declared):
            raise ValueError("duplicate release path")
        for name in declared:
            p = PurePosixPath(name)
            if not name or p.is_absolute() or ".." in p.parts or ":" in name or "\\" in name or str(p) != name:
                raise ValueError("unsafe release path: " + name)
            if runtime and p.suffix.lower() not in {".lua", ".xml", ".toc", ".tga", ".blp", ".png", ".ttf", ".otf", ".ogg", ".wav", ".mp3"} and name not in {"LICENSE.txt", "NOTICE.txt", "Media/MenuIcons/LICENSE.txt"}:
                raise ValueError("non-runtime delivery file: " + name)
        actual = set()
        for p in base.rglob("*"):
            if p.is_symlink() or p.resolve() != p.absolute():
                raise ValueError("linked package member: " + str(p))
            if p.is_file():
                actual.add(p.relative_to(base).as_posix())
        if actual != set(declared):
            raise ValueError(f"{folder}: missing={sorted(set(declared)-actual)}, unlisted={sorted(actual-set(declared))}")
        if runtime:
            for name in declared:
                if not name.endswith(".toc"):
                    continue
                for line in (base / name).read_text(encoding="utf-8-sig").splitlines():
                    line = line.strip()
                    if line.startswith("## Bindings:"):
                        line = line.split(":", 1)[1].strip()
                    elif not line or line.startswith("#"):
                        continue
                    if line.replace("\\", "/") not in actual:
                        raise ValueError(f"TOC dependency absent from archive: {name}: {line}")
        plans.setdefault("Lychee" if runtime else prefix, []).extend(
            (base / name, prefix + "/" + name) for name in sorted(declared))
    return plans


def archive(files: list[tuple[Path, str]]) -> bytes:
    result = io.BytesIO()
    with zipfile.ZipFile(result, "w", compression=zipfile.ZIP_DEFLATED) as z:
        for path, name in files:
            info = zipfile.ZipInfo(name, date_time=(2020, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            z.writestr(info, path.read_bytes())
    data = result.getvalue()
    with zipfile.ZipFile(io.BytesIO(data)) as z:
        if z.testzip() is not None:
            raise ValueError("archive CRC failure")
        for path, name in files:
            if z.read(name) != path.read_bytes():
                raise ValueError("archive content mismatch: " + name)
    return data


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="validate archive bytes in memory; write nothing")
    parser.add_argument("--root", type=Path, default=ROOT)
    args = parser.parse_args()
    root = args.root.resolve()
    try:
        # Delivery must first satisfy generated contracts, including performance policy.
        import build_sdk
        errors = build_sdk.run(root)
        if errors:
            raise ValueError("; ".join(errors))
        plans = paths(root)
        record = {"schemaVersion": 1, "archives": {}}
        output = root / "dist"
        if not args.check:
            if output.is_symlink() or output.resolve() != output.absolute():
                raise ValueError("linked output directory")
            output.mkdir(exist_ok=True)
            record["sourceCommit"] = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=root, text=True).strip()
            record["dirty"] = bool(subprocess.check_output(["git", "status", "--porcelain"], cwd=root, text=True).strip())
        for name, files in plans.items():
            data = archive(files)
            if not args.check:
                target = output / (name + ".zip")
                if target.is_symlink() or target.resolve() != target.absolute():
                    raise ValueError("linked archive target")
                target.write_bytes(data)
            record["archives"][name] = {"sha256": hashlib.sha256(data).hexdigest(), "files": [
                {"path": entry, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()} for path, entry in files]}
            print(f"Release {'check' if args.check else 'build'} PASS: {name} ({len(files)} files)")
        if not args.check:
            target = output / "manifest.json"
            if target.is_symlink() or target.resolve() != target.absolute():
                raise ValueError("linked manifest target")
            target.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")
        return 0
    except (OSError, ValueError, KeyError, TypeError) as error:
        print("Release FAILED:", error)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
