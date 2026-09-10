// Build-time only. Export original IconPark geometry from a pinned npm package.
// Usage: node tools/export_menu_icons.cjs <extracted @icon-park/svg package>
const fs = require('node:fs');
const path = require('node:path');
const root = path.resolve(__dirname, '..');
const source = path.resolve(process.argv[2]);
const assets = path.join(root, 'assets/menu-icons');
const selection = JSON.parse(fs.readFileSync(path.join(assets, 'selection.json'), 'utf8'));
const pkg = JSON.parse(fs.readFileSync(path.join(source, 'package.json'), 'utf8'));
if (pkg.name !== selection.package || pkg.version !== selection.version) {
  throw new Error('IconPark package/version does not match selection.json');
}
fs.mkdirSync(path.join(assets, 'upstream'), { recursive: true });
for (const icon of selection.icons) {
  const render = require(path.join(source, 'lib/icons', icon.source + '.js')).default;
  const svg = render({ theme: 'outline', size: 48, fill: '#000000', strokeWidth: 3,
    strokeLinecap: 'round', strokeLinejoin: 'round' });
  fs.writeFileSync(path.join(assets, 'upstream', icon.source + '.svg'), svg + '\n');
}
fs.copyFileSync(path.join(source, 'LICENSE'), path.join(assets, 'LICENSE.txt'));
console.log(`Exported ${selection.icons.length} IconPark ${pkg.version} SVGs`);
