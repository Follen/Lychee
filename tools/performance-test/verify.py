"""Offline verification at the installed-addon seam; never runs the game."""
from pathlib import Path
import json
import subprocess
import sys

root=Path(__file__).resolve().parents[2]
out=root/'analyze/performance-test-package'
subprocess.run([sys.executable,'tools/performance-test/build.py'],cwd=root,check=True)
subprocess.run(['lua','tools/performance-test/test-native-calls.lua'],cwd=root,check=True)
subprocess.run(['lua','tools/performance-test/test-coverage.lua'],cwd=root,check=True)
run=subprocess.run(['lua','tools/performance-test/test.lua'],cwd=root,check=True,capture_output=True,text=True,encoding='utf-8')
(out/'test-output.txt').write_text(run.stdout,encoding='utf-8')
for path in (out/'Lychee Performance Test').rglob('*.lua'):
    subprocess.run(['luac','-p',str(path)],cwd=root,check=True,capture_output=True)
parsed=subprocess.run(['lua','tools/performance-test/read-report.lua',str(out/'fixture-savedvariables.lua')],cwd=root,check=True,capture_output=True,text=True,encoding='utf-8')
report=json.loads(parsed.stdout)
assert report['status']=='complete' and len(report['rounds'])==4 and len(report['acquisition']['rounds'])==3
(out/'fixture-report.json').write_text(parsed.stdout,encoding='utf-8')
manifest=json.loads((out/'manifest.json').read_text(encoding='utf-8'))
assert len(manifest['files'])==61 and len(manifest['sourceFiles'])==57
assert not any('Lychee Dev' in p.read_text(encoding='utf-8') for p in (out/'Lychee Performance Test').glob('*.toc'))
print(run.stdout.splitlines()[-1])
print('60 Lua syntax checks + independent saved report JSON reader + manifest PASS')
