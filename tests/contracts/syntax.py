"""Parse shipped/test Lua, XML and Python without executing modules."""
import ast
from pathlib import Path
import shutil
import subprocess
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[2]
luac = shutil.which('luac')
assert luac, 'Lua 5.1 compiler is required'
version = subprocess.run([luac, '-v'], capture_output=True, text=True, check=True)
assert 'Lua 5.1' in version.stdout + version.stderr, 'syntax and budget baseline requires Lua 5.1'
lua_version = subprocess.run(['lua', '-v'], capture_output=True, text=True, check=True)
assert 'Lua 5.1' in lua_version.stdout + lua_version.stderr, 'test execution also requires Lua 5.1'
counts = {'.lua': 0, '.xml': 0, '.py': 0}
for folder in ('addon', 'lychee-sdk', 'tests', 'tools'):
    for path in sorted((ROOT / folder).rglob('*')):
        if path.suffix not in counts or not path.is_file():
            continue
        if path.suffix == '.lua':
            subprocess.run([luac, '-p', str(path)], check=True)
        elif path.suffix == '.xml':
            ET.parse(path)
        else:
            ast.parse(path.read_text(encoding='utf-8-sig'), filename=str(path))
        counts[path.suffix] += 1
print('Static syntax PASS:', counts)
