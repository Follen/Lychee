"""Build the opt-in diagnostic addon. No install, clipboard or game operations."""
from pathlib import Path
import hashlib
import json
import zipfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
NAME = 'Lychee Performance Test'
OUT = ROOT / 'analyze/performance-test-package'
TARGET = OUT / NAME
TARGET.mkdir(parents=True, exist_ok=True)
(TARGET / 'Modules').mkdir(exist_ok=True)
excluded = {'Search/SearchSession.lua', 'Core/UserPreferences.lua', 'Search/Personalization.lua', 'Core/ResultActionExecutor.lua'}
paths = [s.strip() for s in (ROOT / 'package/Lychee/Lychee_Mainline.toc').read_text(encoding='utf-8').splitlines()
         if s.strip().endswith('.lua') and not s.startswith(('UI/', 'Secure/', 'Locales/')) and s.strip() not in excluded]
files = ['Bootstrap.lua']
sources = {}
(TARGET / files[0]).write_text('local _, carrier = ...\ncarrier.modules = {}\n', encoding='utf-8')
for i, path in enumerate(paths, 1):
    source = (ROOT / 'package/Lychee' / path).read_text(encoding='utf-8')
    variable = '__lychee_performance_module_namespace'
    assert variable not in source
    name = f'Modules/{i:03}.lua'
    (TARGET / name).write_text(f'local _, {variable} = ...\n{variable}.modules[#{variable}.modules+1] = {{"{path}", function(...)\n' + source + '\nend}\n', encoding='utf-8')
    files.append(name)
    sources[path] = hashlib.sha256(source.encode()).hexdigest()
for name in ['Engine.lua', 'Entry.lua']:
    (TARGET / name).write_bytes((HERE / name).read_bytes())
    files.append(name)
toc_name = NAME + '.toc'
(TARGET / toc_name).write_text('## Interface: 120100\n## Title: Lychee Performance Test\n## Notes: Explicit, bounded lifecycle diagnostics. No automatic test.\n## Version: 0.1.0\n## LoadOnDemand: 1\n## Dependencies: Lychee\n## SavedVariables: LycheePerformanceTestDB\n' + '\n'.join(files) + '\n', encoding='utf-8')
files.append(toc_name)
actual = {p.relative_to(TARGET).as_posix() for p in TARGET.rglob('*') if p.is_file()}
assert actual == set(files), 'Unexpected stale files; inspect manually before packaging'
manifest = {name: hashlib.sha256((TARGET / name).read_bytes()).hexdigest() for name in files}
(OUT / 'manifest.json').write_text(json.dumps({'addon': NAME, 'files': manifest, 'sourceFiles': sources}, indent=2), encoding='utf-8')
command = '/run local t=debugprofilestop();local ok,e=C_AddOns.LoadAddOn("Lychee Performance Test");if ok then LycheePerformanceTest.Start(debugprofilestop()-t) else print(e) end'
assert len(command.encode()) <= 200
(OUT / 'START.txt').write_text(command, encoding='utf-8')
with zipfile.ZipFile(OUT / (NAME + '.zip'), 'w', zipfile.ZIP_DEFLATED) as archive:
    for name in sorted(files):
        archive.write(TARGET / name, NAME + '/' + name)
print(f'{TARGET}: {len(files)} files, {sum((TARGET/n).stat().st_size for n in files)} bytes; entry {len(command)} ASCII bytes. NOT INSTALLED.')
