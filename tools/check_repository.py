"""Read-only checks for current documentation links, layout and SDK version labels."""
from __future__ import annotations
import argparse
import json
from pathlib import Path
import re
from urllib.parse import unquote, urlsplit

ROOT = Path(__file__).resolve().parents[1]


def current_documents(root: Path) -> list[Path]:
    result = list(root.glob("*.md")) + list((root / "docs").glob("*.md"))
    for folder in ("docs/guides", "lychee-sdk"):
        result.extend((root / folder).rglob("*.md"))
    for name in ("tools/README.md", "tests/README.md", "tests/LIFECYCLE_ACCEPTANCE.md",
                 "docs/architecture/README.md", "docs/validation/README.md"):
        if (root / name).exists():
            result.append(root / name)
    return sorted(set(result))


def prose(text: str) -> str:
    # Documentation examples can intentionally contain placeholder paths.
    return re.sub(r"(?ms)^(`{3,}|~{3,})[^\n]*\n.*?^\1\s*$", "", text)


def anchors(text: str) -> set[str]:
    result = set(re.findall(r'(?:id|name)=["\']([^"\']+)["\']', text))
    seen = {}
    for heading in re.findall(r"(?m)^#{1,6}\s+(.+?)\s*#*\s*$", prose(text)):
        heading = re.sub(r"<[^>]*>", "", heading).lower()
        slug = re.sub(r"[^\w\-\s]", "", heading, flags=re.UNICODE).replace(" ", "-")
        index = seen.get(slug, 0)
        seen[slug] = index + 1
        result.add(slug + (f"-{index}" if index else ""))
    return result


def document_errors(root: Path, files: list[Path]) -> list[str]:
    errors = []
    for path in files:
        text = prose(path.read_text(encoding="utf-8-sig"))
        targets = re.findall(r"\]\(<?([^\s)>]+)>?(?:\s+\"[^\"]*\")?\)", text)
        targets += re.findall(r'(?:src|href)=["\']([^"\']+)["\']', text)
        for target in targets:
            parts = urlsplit(target)
            if parts.scheme or parts.netloc:
                continue
            dest = (path.parent / unquote(parts.path)).resolve() if parts.path else path.resolve()
            if not dest.is_relative_to(root.resolve()):
                errors.append(f"{path.relative_to(root)}: link outside repository: {target}")
            elif path.is_relative_to(root / "lychee-sdk") and not dest.is_relative_to((root / "lychee-sdk").resolve()):
                errors.append(f"{path.relative_to(root)}: SDK link requires absent outer repository: {target}")
            elif not dest.exists():
                errors.append(f"{path.relative_to(root)}: broken link: {target}")
            elif parts.fragment and dest.suffix == ".md" and unquote(parts.fragment) not in anchors(dest.read_text(encoding="utf-8-sig")):
                errors.append(f"{path.relative_to(root)}: missing anchor: {target}")
    return errors


def check(root: Path) -> list[str]:
    errors = document_errors(root, current_documents(root))
    if not (root / "addon/Lychee/Lychee.toc").is_file() or (root / "package/Lychee").exists():
        errors.append("runtime source must exist only at addon/Lychee")
    if not (root / "PERFORMANCE.md").is_file() or not (root / "DESIGN.md").is_file():
        errors.append("canonical PERFORMANCE.md and DESIGN.md must exist")
    for p in root.glob("*.md"):
        if p.name.lower() in {"perfermance.md", "pefermance.md", "perfermes.md", "desgin.md"}:
            errors.append("duplicate misspelled policy: " + p.name)
    contract = json.loads((root / "tools/sdk_contract.json").read_text(encoding="utf-8"))
    version = contract["apiVersion"]
    for p in (root / "README.md", root / "README.en.md"):
        badges = re.findall(r"API%20([0-9]+\.[0-9]+\.[0-9]+)", p.read_text(encoding="utf-8"))
        if badges != [version]:
            errors.append(p.name + ": SDK version badge differs from contract")
    protocol = root / "lychee-sdk/docs/PROTOCOLS.md"
    if f'API_VERSION="{version}"' not in protocol.read_text(encoding="utf-8"):
        errors.append("SDK protocol current version differs from contract")
    # Historical evidence and workflow state intentionally retain the original paths.
    scan = current_documents(root)
    for folder in ("tools", "tests"):
        scan += [p for p in (root / folder).rglob("*") if p.suffix in {".lua", ".py", ".ps1", ".cjs"} and "__pycache__" not in p.parts]
    for p in set(scan):
        if p == Path(__file__) or p.name == "README.md" and p.parent.name in {"architecture", "validation"}:
            continue
        if re.search(r"package[/\\]Lychee", p.read_text(encoding="utf-8-sig")):
            errors.append(str(p.relative_to(root)) + ": current documentation/tool uses old runtime path")
    return errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=ROOT)
    root = parser.parse_args().root.resolve()
    errors = check(root)
    if errors:
        print("Repository documentation FAILED:")
        for error in errors:
            print("-", error)
        return 1
    print(f"Repository documentation PASS: {len(current_documents(root))} current documents, links, anchors, SDK closure and version labels")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
