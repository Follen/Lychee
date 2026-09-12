"""Isolated, sequential regression runner. No shell commands or silent retries."""
from __future__ import annotations
import argparse
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
SUITES = {'sdk', 'search', 'providers', 'ui', 'integration', 'performance', 'delivery', 'contracts', 'benchmarks'}
EXTENSIONS = {'.lua', '.py', '.ps1'}


def inventory(root: Path, manifest: dict) -> list[dict]:
    if set(manifest) != {'schema', 'cases'} or manifest['schema'] != 1 or not isinstance(manifest['cases'], list):
        raise ValueError('invalid test manifest')
    cases = manifest['cases']
    ids, commands, files = set(), set(), set()
    for case in cases:
        if set(case) != {'id', 'suite', 'path', 'args'}:
            raise ValueError('invalid case fields')
        name, suite, path, args = (case[k] for k in ('id', 'suite', 'path', 'args'))
        if not isinstance(name, str) or not re.fullmatch(r'[a-z0-9_.-]+', name) or name in ids:
            raise ValueError(f'invalid or duplicate case id: {name}')
        if not isinstance(suite, str) or suite not in SUITES:
            raise ValueError(f'unknown suite: {suite}')
        if not isinstance(path, str) or '\\' in path or PurePosixPath(path).as_posix() != path:
            raise ValueError(f'invalid test path: {path}')
        parts = PurePosixPath(path).parts
        if not parts or parts[0] not in {'tests', 'tools'} or '..' in parts or ':' in path:
            raise ValueError(f'unsafe test path: {path}')
        target = root / path
        if not target.resolve().is_relative_to(root.resolve()) or not target.is_file() or target.suffix not in EXTENSIONS:
            raise ValueError(f'missing or invalid test: {path}')
        if parts[0] == 'tests' and (len(parts) < 3 or parts[1] != suite):
            raise ValueError(f'test directory must match suite: {path}')
        if not isinstance(args, list) or any(not isinstance(a, str) or '\x00' in a for a in args):
            raise ValueError(f'invalid arguments: {name}')
        command = (path, *args)
        if command in commands:
            raise ValueError(f'duplicate test command: {path} {args}')
        ids.add(name); commands.add(command); files.add(path)
    discovered = {p.relative_to(root).as_posix() for p in (root / 'tests').rglob('*')
                  if p.is_file() and p.suffix in EXTENSIONS and p.parent.name != '__pycache__'
                  and p.relative_to(root / 'tests').parts[0] not in {'support', 'fixtures'}
                  and p.relative_to(root / 'tests').as_posix() not in {'run.py', 'check_contract.ps1'}}
    if discovered - files:
        raise ValueError('unregistered tests: ' + ', '.join(sorted(discovered - files)))
    for path in sorted(files):
        if path.endswith('.lua'):
            for dependency in re.findall(r'(?:dofile|loadfile)\s*\(\s*[\'"](tests/[^\'"]+)[\'"]', (root / path).read_text(encoding='utf-8-sig')):
                if not dependency.startswith(('tests/support/', 'tests/fixtures/')):
                    raise ValueError(f'test executes another spec: {path} -> {dependency}')
    return cases


def select(cases: list[dict], suites: list[str], names: list[str], benchmarks: bool) -> list[dict]:
    unknown = set(names) - {c['id'] for c in cases}
    if unknown:
        raise ValueError('unknown case: ' + ', '.join(sorted(unknown)))
    chosen = [c for c in cases if (not suites or c['suite'] in suites)
              and (not names or c['id'] in names)
              and (c['suite'] != 'benchmarks' or benchmarks or 'benchmarks' in suites or c['id'] in names)]
    if not chosen:
        raise ValueError('selection contains no tests')
    return chosen


def command(case: dict) -> list[str]:
    suffix = Path(case['path']).suffix
    executable = sys.executable if suffix == '.py' else shutil.which('lua' if suffix == '.lua' else 'pwsh')
    if not executable:
        raise ValueError(f'missing runtime for {case["path"]}')
    return [executable, *(['-NoProfile', '-File'] if suffix == '.ps1' else []), case['path'], *case['args']]


def execute(argv: list[str], root: Path, timeout: float) -> dict:
    started = time.monotonic()
    env = dict(os.environ, PYTHONUTF8='1', PYTHONDONTWRITEBYTECODE='1', PYTHONOPTIMIZE='0')
    try:
        result = subprocess.run(argv, cwd=root, env=env, capture_output=True, text=True,
                                encoding='utf-8', errors='replace', timeout=timeout)
        status, code, output = ('passed' if result.returncode == 0 else 'failed'), result.returncode, result.stdout + result.stderr
    except subprocess.TimeoutExpired as exc:
        def decode(value):
            return value.decode('utf-8', errors='replace') if isinstance(value, bytes) else value or ''
        status, code, output = 'timeout', None, decode(exc.stdout) + decode(exc.stderr)
    except OSError as exc:
        status, code, output = 'failed', None, str(exc)
    return {'status': status, 'exitCode': code, 'seconds': round(time.monotonic() - started, 3), 'output': output}


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--suite', action='append', choices=sorted(SUITES), default=[])
    parser.add_argument('--case', action='append', default=[])
    parser.add_argument('--list', action='store_true')
    parser.add_argument('--include-benchmarks', action='store_true')
    parser.add_argument('--report', type=Path)
    parser.add_argument('--timeout', type=float, default=120)
    args = parser.parse_args(argv)
    try:
        if not 0 < args.timeout <= 3600:
            raise ValueError('timeout must be within (0, 3600] seconds')
        cases = inventory(ROOT, json.loads((ROOT / 'tests/suites.json').read_text(encoding='utf-8')))
        chosen = select(cases, args.suite, args.case, args.include_benchmarks)
        if args.list:
            for c in chosen:
                print(c['id'] + ': ' + c['path'] + ' ' + ' '.join(c['args']))
            print(f'{len(chosen)} commands; {len(cases)} registered (including benchmarks)')
            return 0
        commands = [command(c) for c in chosen]
    except (ValueError, OSError) as exc:
        print(f'Test configuration ERROR: {exc}', file=sys.stderr)
        return 2
    results = []
    for case, argv in zip(chosen, commands):
        print(f'[{len(results)+1}/{len(chosen)}] {case["id"]}', flush=True)
        result = dict(id=case['id'], command=argv, **execute(argv, ROOT, args.timeout))
        results.append(result)
        print(result['output'], end='' if result['output'].endswith('\n') else '\n', flush=True)
        print(f'{result["status"].upper()} ({result["seconds"]:.3f}s)', flush=True)
    failures = [r['id'] for r in results if r['status'] != 'passed']
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps({'schema': 1, 'scope': 'selected' if args.suite or args.case else 'full',
                                          'passed': not failures, 'results': results}, indent=2, ensure_ascii=False) + '\n', encoding='utf-8')
    print(f'{len(results)-len(failures)}/{len(results)} passed' + ('; failed: ' + ', '.join(failures) if failures else ''))
    return 1 if failures else 0


if __name__ == '__main__':
    raise SystemExit(main())
